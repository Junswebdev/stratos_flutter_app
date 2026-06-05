import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lesson_repository.dart';
import '../controllers/lesson_controller.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key, required this.lessonId, required this.courseId});

  final String lessonId;
  final String courseId;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  Map<String, dynamic>? _quizData;
  List<int> _answers = [];
  int _currentIndex = 0;
  bool _isSubmitting = false;
  Map<String, dynamic>? _result;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(lessonRepositoryProvider).getQuizContent(widget.lessonId);
      if (mounted) {
        setState(() {
          _quizData = data;
          final questions = _getQuestions(data);
          _answers = List.filled(questions.length, -1);
          final attempt = data['attempt'] as Map<String, dynamic>?;
          if (attempt != null) {
            _result = attempt;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getQuestions(Map<String, dynamic> data) {
    final qs = data['questions'];
    if (qs is List) return qs;
    return [];
  }

  Future<void> _submit() async {
    if (_answers.any((a) => a == -1)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions before submitting.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      final result = await ref.read(lessonRepositoryProvider).submitQuiz(
        widget.lessonId,
        _answers,
      );
      ref.invalidate(courseProgressProvider(widget.courseId));
      if (mounted) setState(() {
        _result = result;
        _isSubmitting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_result != null) {
      return _buildResult();
    }
    return _buildQuiz();
  }

  Widget _buildQuiz() {
    final questions = _getQuestions(_quizData!);
    if (questions.isEmpty) {
      return const Center(child: Text('No questions available.'));
    }
    final q = questions[_currentIndex] as Map<String, dynamic>;
    final options = q['options'] as List? ?? [];
    final questionText = q['question_text'] as String? ?? '';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / questions.length,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('Question ${_currentIndex + 1} of ${questions.length}',
            style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(questionText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.4)),
                ),
              ),
              const SizedBox(height: 16),
              ...List.generate(options.length, (i) {
                final option = options[i] as String? ?? '';
                final isSelected = _answers[_currentIndex] == i;
                return Card(
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(String.fromCharCode(65 + i)),
                    ),
                    title: Text(option),
                    trailing: isSelected ? const Icon(Icons.check_circle) : null,
                    onTap: () {
                      setState(() {
                        _answers[_currentIndex] = i;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_currentIndex > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _currentIndex--),
                      child: const Text('Previous'),
                    ),
                  ),
                if (_currentIndex > 0) const SizedBox(width: 12),
                Expanded(
                  child: _currentIndex < questions.length - 1
                      ? FilledButton(
                          onPressed: _answers[_currentIndex] == -1
                              ? null
                              : () => setState(() => _currentIndex++),
                          child: const Text('Next'),
                        )
                      : FilledButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Submit'),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final score = (_result!['score'] as num?)?.toDouble() ?? 0;
    final total = (_result!['total'] as num?)?.toInt() ?? 0;
    final answers = _result!['answers'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Text('Quiz Complete!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  )),
                const SizedBox(height: 16),
                Text('${score.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: score >= 70 ? Colors.green : Colors.orange,
                  )),
                const SizedBox(height: 8),
                Text('$correctCount of $total correct',
                  style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(answers.length, (i) {
          final a = answers[i] as Map<String, dynamic>;
          final isCorrect = a['is_correct'] == true;
          final questionText = _getQuestions(_quizData!).length > i
              ? (_getQuestions(_quizData!)[i] as Map<String, dynamic>)['question_text'] as String? ?? ''
              : '';
          return Card(
            color: isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect ? Colors.green : Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(questionText, style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                  if (!isCorrect) ...[
                    const SizedBox(height: 8),
                    Text('Correct answer: ${a['correct']}'),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loadQuiz,
          child: const Text('Retry'),
        ),
      ],
    );
  }

  int get correctCount {
    final answers = _result!['answers'] as List? ?? [];
    return answers.where((a) {
      if (a is Map) return a['is_correct'] == true;
      return false;
    }).length;
  }
}
