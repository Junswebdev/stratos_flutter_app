import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/course_repository.dart';
import '../../domain/quiz_model.dart';
import '../../../../core/theme.dart';

class QuizReviewScreen extends ConsumerStatefulWidget {
  const QuizReviewScreen({
    super.key,
    required this.quizId,
    required this.attempt,
  });

  final String quizId;
  final QuizAttemptModel attempt;

  @override
  ConsumerState<QuizReviewScreen> createState() => _QuizReviewScreenState();
}

class _QuizReviewScreenState extends ConsumerState<QuizReviewScreen> {
  QuizModel? _quiz;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchQuiz();
  }

  Future<void> _fetchQuiz() async {
    setState(() => _isLoading = true);
    try {
      // We need the full quiz to get question text and options
      final quiz = await ref.read(courseRepositoryProvider).getQuizById(widget.quizId);
      if (mounted) {
        setState(() {
          _quiz = quiz;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading quiz details: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Submission Review"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _quiz == null
              ? const Center(child: Text("Could not load quiz details."))
              : Column(
                  children: [
                    _buildHeader(isDark),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _quiz!.questions.length,
                        itemBuilder: (context, index) {
                          final question = _quiz!.questions[index];
                          final studentAnswer = widget.attempt.answers.firstWhere(
                            (a) => a['question_id'] == question.id,
                            orElse: () => null,
                          );

                          return _buildQuestionReview(question, studentAnswer, isDark);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              widget.attempt.studentName?[0].toUpperCase() ?? 'U',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.attempt.studentName ?? "Unknown Student",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.attempt.studentEmail ?? "",
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${widget.attempt.score.toStringAsFixed(0)}%",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary),
              ),
              const Text("FINAL SCORE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionReview(QuizQuestionModel question, dynamic answerData, bool isDark) {
    final isCorrect = answerData?['is_correct'] ?? false;
    final studentAnswer = answerData?['user_answer'];

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isCorrect ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isCorrect ? "CORRECT" : "INCORRECT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  question.type.name.toUpperCase(),
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              question.questionText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            // Answer display based on type
            if (question.type == QuestionType.multipleChoice)
              ..._buildMultipleChoiceReview(question, studentAnswer)
            else
              _buildTextAnswerReview(question, studentAnswer, isCorrect),

            if (question.explanation != null && question.explanation!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Explanation: ${question.explanation}",
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMultipleChoiceReview(QuizQuestionModel question, dynamic studentAnswer) {
    final options = question.data['options'] as List<dynamic>;
    final correctIndex = question.data['correct_index'] as int;
    final studentIndex = studentAnswer as int?;

    return List.generate(options.length, (i) {
      final isCorrectOption = i == correctIndex;
      final isStudentOption = i == studentIndex;
      
      Color? bgColor;
      Color? borderColor;
      IconData? icon;

      if (isCorrectOption) {
        bgColor = AppColors.success.withValues(alpha: 0.1);
        borderColor = AppColors.success;
        icon = Icons.check_circle;
      } else if (isStudentOption && !isCorrectOption) {
        bgColor = AppColors.danger.withValues(alpha: 0.1);
        borderColor = AppColors.danger;
        icon = Icons.cancel;
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor ?? Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(options[i].toString())),
            if (icon != null) Icon(icon, size: 18, color: borderColor),
          ],
        ),
      );
    });
  }

  Widget _buildTextAnswerReview(QuizQuestionModel question, dynamic studentAnswer, bool isCorrect) {
    final correctAnswer = question.data['answer']?.toString() ?? "N/A";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Student Answer:", style: TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          studentAnswer?.toString() ?? "(No answer)",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isCorrect ? AppColors.success : AppColors.danger,
          ),
        ),
        if (!isCorrect) ...[
          const SizedBox(height: 12),
          const Text("Correct Answer:", style: TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            correctAnswer,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success),
          ),
        ],
      ],
    );
  }
}
