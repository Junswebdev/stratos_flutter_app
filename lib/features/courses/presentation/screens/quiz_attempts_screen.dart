import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../data/course_repository.dart';
import '../../domain/quiz_model.dart';
import '../../../../core/theme.dart';

class QuizAttemptsScreen extends ConsumerStatefulWidget {
  const QuizAttemptsScreen({super.key, required this.quizId, required this.quizTitle});

  final String quizId;
  final String quizTitle;

  @override
  ConsumerState<QuizAttemptsScreen> createState() => _QuizAttemptsScreenState();
}

class _QuizAttemptsScreenState extends ConsumerState<QuizAttemptsScreen> {
  List<QuizAttemptModel> _attempts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttempts();
  }

  Future<void> _loadAttempts() async {
    setState(() => _isLoading = true);
    try {
      final attempts = await ref.read(courseRepositoryProvider).getAllQuizAttempts(widget.quizId);
      setState(() {
        _attempts = attempts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showGradeDialog(QuizAttemptModel attempt) {
    final scoreController = TextEditingController(text: attempt.score.toStringAsFixed(1));
    final feedbackController = TextEditingController(text: attempt.instructorFeedback);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Grade: ${attempt.studentName}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ctx.pop();
                context.pushNamed(
                  'quiz_review',
                  pathParameters: {'quizId': widget.quizId},
                  extra: attempt,
                );
              },
              icon: const Icon(Icons.remove_red_eye_outlined),
              label: const Text("Review Student Answers"),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: scoreController,
              decoration: const InputDecoration(labelText: "Final Score (%)", border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(labelText: "Feedback", border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              try {
                final score = double.tryParse(scoreController.text) ?? attempt.score;
                await ref.read(courseRepositoryProvider).gradeQuizAttempt(
                  attemptId: attempt.id,
                  score: score,
                  feedback: feedbackController.text.trim(),
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                _loadAttempts();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Grade updated successfully")));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to update: $e")));
                }
              }
            },
            child: const Text("Update Grade"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Student Submissions", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text(widget.quizTitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attempts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_ind_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.3)),
                      const SizedBox(height: 16),
                      const Text("No submissions yet", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _attempts.length,
                  itemBuilder: (context, index) {
                    final a = _attempts[index];
                    final date = DateFormat('MMM dd, yyyy • HH:mm').format(a.completedAt);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.netflixRed.withValues(alpha: 0.1),
                          child: Text(a.studentName?[0].toUpperCase() ?? 'U', 
                              style: const TextStyle(color: AppColors.netflixRed, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(a.studentName ?? "Unknown Student", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.studentEmail ?? "", style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            if (a.instructorFeedback != null && a.instructorFeedback!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                                  ),
                                  child: Text("Feedback: ${a.instructorFeedback}", 
                                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                ),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("${a.score.toStringAsFixed(0)}%", 
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.netflixRed)),
                            const Text("SCORE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                          ],
                        ),
                        onTap: () => _showGradeDialog(a),
                      ),
                    );
                  },
                ),
    );
  }
}
