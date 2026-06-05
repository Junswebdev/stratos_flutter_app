import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/course_repository.dart';
import '../../domain/quiz_model.dart';
import '../../../../core/theme.dart';

class ManageQuizScreen extends ConsumerStatefulWidget {
  const ManageQuizScreen({super.key, required this.lessonId, required this.lessonTitle});

  final String lessonId;
  final String lessonTitle;

  @override
  ConsumerState<ManageQuizScreen> createState() => _ManageQuizScreenState();
}

class _ManageQuizScreenState extends ConsumerState<ManageQuizScreen> {
  bool _isLoading = true;
  final List<QuizQuestionModel> _pendingQuestions = [];

  @override
  void initState() {
    super.initState();
    _fetchQuiz();
  }

  Future<void> _fetchQuiz() async {
    setState(() => _isLoading = true);
    try {
      final quiz = await ref.read(courseRepositoryProvider).getQuizForLesson(widget.lessonId);
      setState(() {
        if (quiz != null) {
          _pendingQuestions.clear();
          _pendingQuestions.addAll(quiz.questions);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAIQuiz() async {
    setState(() => _isLoading = true);
    try {
      final quiz = await ref.read(courseRepositoryProvider).generateAIQuiz(widget.lessonId);
      setState(() {
        _pendingQuestions.clear();
        _pendingQuestions.addAll(quiz.questions);
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI Quiz generated! Review and Save.")));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String message = "AI Generation failed: $e";
        if (e.toString().contains("400")) {
          message = "Cannot generate quiz: This lesson has no text content for the AI to analyze. Please add text content first.";
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _addManualQuestion() {
    _showQuestionDialog();
  }

  void _editQuestion(int index) {
    _showQuestionDialog(index: index, question: _pendingQuestions[index]);
  }

  void _removeQuestion(int index) {
    setState(() {
      _pendingQuestions.removeAt(index);
    });
  }

  Future<void> _saveQuiz() async {
    if (_pendingQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please add at least one question.")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(courseRepositoryProvider).createManualQuiz(
        lessonId: widget.lessonId,
        title: "Quiz: ${widget.lessonTitle}",
        questions: _pendingQuestions,
      );
      await _fetchQuiz();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Quiz saved successfully!")));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
      }
    }
  }

  void _showQuestionDialog({int? index, QuizQuestionModel? question}) {
    final textController = TextEditingController(text: question?.questionText);
    final explanationController = TextEditingController(text: question?.explanation);
    QuestionType selectedType = question?.type ?? QuestionType.multipleChoice;
    
    // Type-specific controllers
    List<TextEditingController> optionControllers = [];
    int correctIndex = 0;
    final answerController = TextEditingController();

    if (selectedType == QuestionType.multipleChoice) {
      final options = (question?.data['options'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? ["", "", "", ""];
      optionControllers = options.map((o) => TextEditingController(text: o)).toList();
      correctIndex = question?.data['correct_index'] as int? ?? 0;
    } else {
      answerController.text = question?.data['answer']?.toString() ?? "";
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(index == null ? "Add Question" : "Edit Question"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<QuestionType>(
                  initialValue: selectedType,
                  items: QuestionType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedType = val;
                        if (selectedType == QuestionType.multipleChoice && optionControllers.isEmpty) {
                          optionControllers = List.generate(4, (_) => TextEditingController());
                        }
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: "Type"),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  decoration: const InputDecoration(labelText: "Question Text", border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                
                if (selectedType == QuestionType.multipleChoice) ...[
                  ...List.generate(optionControllers.length, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Radio<int>(
                          value: i,
                          groupValue: correctIndex,
                          onChanged: (val) => setDialogState(() => correctIndex = val!),
                        ),
                        Expanded(child: TextField(controller: optionControllers[i], decoration: InputDecoration(labelText: "Option ${i+1}"))),
                      ],
                    ),
                  )),
                ] else if (selectedType == QuestionType.essay) ...[
                   TextField(controller: answerController, decoration: const InputDecoration(labelText: "Rubric / Expected Points (Optional)")),
                ] else ...[
                   TextField(controller: answerController, decoration: const InputDecoration(labelText: "Correct Answer")),
                ],
                
                const SizedBox(height: 12),
                TextField(
                  controller: explanationController,
                  decoration: const InputDecoration(labelText: "Explanation (Optional)", border: OutlineInputBorder()),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => ctx.pop(), child: const Text("Cancel")),
            FilledButton(
              onPressed: () {
                final Map<String, dynamic> data = {};
                if (selectedType == QuestionType.multipleChoice) {
                  data['options'] = optionControllers.map((c) => c.text.trim()).toList();
                  data['correct_index'] = correctIndex;
                } else {
                  data['answer'] = answerController.text.trim();
                }

                final newQ = QuizQuestionModel(
                  id: question?.id ?? "",
                  questionText: textController.text.trim(),
                  type: selectedType,
                  data: data,
                  explanation: explanationController.text.trim(),
                  order: index ?? _pendingQuestions.length,
                );

                setState(() {
                  if (index == null) {
                    _pendingQuestions.add(newQ);
                  } else {
                    _pendingQuestions[index] = newQ;
                  }
                });
                ctx.pop();
              },
              child: const Text("Done"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Quiz Designer", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text(widget.lessonTitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black54)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.icon(
              onPressed: _saveQuiz, 
              icon: const Icon(Icons.cloud_upload_outlined, size: 18), 
              label: const Text("Save Quiz"),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              // Header Quick Actions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Build your assessment",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Choose to generate automatically with Mistral AI or add questions manually.",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _generateAIQuiz,
                            icon: const Icon(Icons.auto_awesome, size: 18, color: Colors.purple),
                            label: const Text("AI Auto-Gen"),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.purple),
                              foregroundColor: Colors.purple,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _addManualQuestion,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text("Add Question"),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: AppColors.netflixRed,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Question List
              Expanded(
                child: _pendingQuestions.isEmpty
                  ? _buildEmptyState()
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _pendingQuestions.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex -= 1;
                          final item = _pendingQuestions.removeAt(oldIndex);
                          _pendingQuestions.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final q = _pendingQuestions[index];
                        return _buildQuestionCard(q, index);
                      },
                    ),
              ),
            ],
          ),
    );
  }

  Widget _buildQuestionCard(QuizQuestionModel q, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      key: ValueKey(q.id + index.toString()),
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.netflixRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      color: AppColors.netflixRed,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              title: Text(
                q.questionText,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    _TypeChip(type: q.type),
                  ],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _editQuestion(index), 
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: "Edit",
                  ),
                  IconButton(
                    onPressed: () => _removeQuestion(index), 
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                    tooltip: "Remove",
                  ),
                  const Icon(Icons.drag_indicator_rounded, color: Colors.grey, size: 20),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            if (q.type == QuestionType.multipleChoice)
              _buildOptionsPreview(q.data['options'] as List, q.data['correct_index'] as int),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionsPreview(List options, int correctIdx) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      width: double.infinity,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(options.length, (i) {
          final isCorrect = i == correctIdx;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isCorrect ? Colors.green.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isCorrect ? Colors.green.withValues(alpha: 0.3) : Colors.transparent),
            ),
            child: Text(
              options[i].toString(),
              style: TextStyle(
                fontSize: 12, 
                fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                color: isCorrect ? Colors.green : Colors.grey[600],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            "Your Quiz is Empty",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add questions manually or use AI to start.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final QuestionType type;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    
    switch (type) {
      case QuestionType.multipleChoice:
        color = Colors.blue;
        label = "MULTI-CHOICE";
        break;
      case QuestionType.fillInTheBlanks:
        color = Colors.orange;
        label = "FILL BLANK";
        break;
      case QuestionType.objective:
        color = Colors.teal;
        label = "OBJECTIVE";
        break;
      case QuestionType.essay:
        color = Colors.deepPurple;
        label = "ESSAY";
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}
