import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/course_repository.dart';
import '../../domain/quiz_model.dart';
import '../../../../core/theme.dart';

class QuizTakingScreen extends ConsumerStatefulWidget {
  const QuizTakingScreen({super.key, required this.lessonId, required this.lessonTitle});

  final String lessonId;
  final String lessonTitle;

  @override
  ConsumerState<QuizTakingScreen> createState() => _QuizTakingScreenState();
}

class _QuizTakingScreenState extends ConsumerState<QuizTakingScreen> {
  QuizModel? _quiz;
  bool _isLoading = true;
  final Map<String, dynamic> _userAnswers = {};
  QuizAttemptModel? _result;

  @override
  void initState() {
    super.initState();
    _fetchQuiz();
  }

  Future<void> _fetchQuiz() async {
    setState(() => _isLoading = true);
    try {
      final quiz = await ref.read(courseRepositoryProvider).getQuizForLesson(widget.lessonId);
      if (quiz != null) {
        final attempts = await ref.read(courseRepositoryProvider).getMyAttempts(quiz.id);
        if (attempts.isNotEmpty) {
          _result = attempts.first;
        }
      }
      setState(() {
        _quiz = quiz;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitQuiz() async {
    if (_quiz == null) return;
    
    // Validate all answered
    if (_userAnswers.length < _quiz!.questions.length) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Incomplete"),
          content: const Text("You haven't answered all questions. Submit anyway?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Submit")),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> answers = _userAnswers.entries.map((e) => {
        'question_id': e.key,
        'answer': e.value,
      }).toList();

      final result = await ref.read(courseRepositoryProvider).submitQuizAttempt(
        quizId: _quiz!.id,
        answers: answers,
      );
      
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Submission failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_quiz == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text("No quiz available for this lesson.")));
    if (_result != null) return _buildResultView();

    return Scaffold(
      appBar: AppBar(title: Text(widget.lessonTitle)),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _quiz!.questions.length + 1,
        itemBuilder: (context, index) {
          if (index == _quiz!.questions.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: FilledButton.icon(
                onPressed: _submitQuiz,
                icon: const Icon(Icons.check),
                label: const Text("Submit Quiz"),
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              ),
            );
          }

          final q = _quiz!.questions[index];
          return _buildQuestionCard(q, index + 1);
        },
      ),
    );
  }

  Widget _buildQuestionCard(QuizQuestionModel q, int number) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Question $number", style: const TextStyle(color: AppColors.netflixRed, fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 8),
            Text(q.questionText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            
            if (q.type == QuestionType.multipleChoice) ...[
              ... (q.data['options'] as List<dynamic>).asMap().entries.map((entry) {
                final idx = entry.key;
                final text = entry.value.toString();
                return RadioListTile<int>(
                  title: Text(text),
                  value: idx,
                  // ignore: deprecated_member_use
                  groupValue: _userAnswers[q.id] as int?,
                  // ignore: deprecated_member_use
                  onChanged: (val) => setState(() => _userAnswers[q.id] = val),
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ] else if (q.type == QuestionType.essay) ...[
              TextField(
                onChanged: (val) => _userAnswers[q.id] = val,
                maxLines: 5,
                decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "Type your reflective answer here..."),
              ),
            ] else ...[
              TextField(
                onChanged: (val) => _userAnswers[q.id] = val,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: q.type == QuestionType.fillInTheBlanks ? "Type the missing word" : "Short answer",
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    return Scaffold(
      appBar: AppBar(title: const Text("Quiz Results")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.netflixRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Icon(Icons.stars, color: AppColors.netflixRed, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    "${_result!.score.toStringAsFixed(0)}%",
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppColors.netflixRed),
                  ),
                  Text(
                    "Score: ${_result!.score.toStringAsFixed(1)} / 100",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  if (_result!.instructorFeedback != null && _result!.instructorFeedback!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),
                    const Text("Instructor Feedback", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      _result!.instructorFeedback!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.blueGrey),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Review Answers", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            ..._quiz!.questions.asMap().entries.map((entry) {
              final q = entry.value;
              final attemptAns = _result!.answers.firstWhere((a) => a['question_id'] == q.id, orElse: () => null);
              final isCorrect = attemptAns?['is_correct'] == true;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? Colors.green : Colors.red),
                  title: Text(q.questionText),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Your answer: ${attemptAns?['user_answer'] ?? 'Not answered'}", 
                          style: TextStyle(color: isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                      if (q.explanation != null && q.explanation!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text("Explanation: ${q.explanation}", style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                        ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(onPressed: () => context.pop(), child: const Text("Finish")),
            ),
          ],
        ),
      ),
    );
  }
}
