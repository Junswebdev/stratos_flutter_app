import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui'; // Required for ImageFilter

import '../../../../features/home/application/home_providers.dart';
import '../../../../features/home/data/home_models.dart';
import '../../../../core/widgets/minimalist_widgets.dart';
import '../../data/course_repository.dart';
import '../../domain/course_model.dart';
import '../../domain/lesson_model.dart';
import '../../../../core/theme.dart';

class ManageCourseScreen extends ConsumerStatefulWidget {
  const ManageCourseScreen({super.key, required this.courseId});

  final String courseId;

  @override
  ConsumerState<ManageCourseScreen> createState() => ManageCourseScreenState();
}

class ManageCourseScreenState extends ConsumerState<ManageCourseScreen> {
  CourseModel? _course;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    setState(() => _isLoading = true);
    try {
      final data = await ref.read(courseRepositoryProvider).getCourseById(widget.courseId);
      if (mounted) setState(() => _course = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _setImageUrl() async {
    final controller = TextEditingController(
        text: (_course!.imageUrl != null && _course!.imageUrl!.startsWith('http'))
            ? _course!.imageUrl!
            : '');
    final theme = Theme.of(context);

    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Set Course Thumbnail'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Image URL',
                  hintText: 'https://example.com/image.jpg',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                keyboardType: TextInputType.url,
                autofocus: true,
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 16),
              if (controller.text.trim().startsWith('http'))
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    controller.text.trim(),
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Invalid image URL'),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => ctx.pop(null), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => ctx.pop(controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      try {
        await ref.read(courseRepositoryProvider).updateCourse(
          widget.courseId,
          imageUrl: result.isNotEmpty ? result : null,
        );
        if (!mounted) return;
        ref.invalidate(courseDetailProvider(widget.courseId));
        _loadCourse();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thumbnail updated!')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update thumbnail: $e')));
      }
    }
  }

  Future<void> _addModule() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add new module'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Module Title', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => ctx.pop(controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await ref.read(courseRepositoryProvider).createModule(
          courseId: widget.courseId,
          title: result,
          order: _course?.modules.length ?? 0,
        );
        ref.invalidate(courseDetailProvider(widget.courseId));
        _loadCourse();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _addLesson(String moduleId) async {
    final titleController = TextEditingController();
    final typeController = TextEditingController(text: 'text');
    final contentController = TextEditingController();
    Uint8List? fileBytes;
    String? fileName;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add lesson'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Lesson Title', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: typeController.text,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('Text/Article')),
                    DropdownMenuItem(value: 'video', child: Text('Video')),
                    DropdownMenuItem(value: 'quiz', child: Text('Quiz')),
                    DropdownMenuItem(value: 'file', child: Text('File/Document')),
                  ],
                  onChanged: (v) => setDialogState(() => typeController.text = v!),
                ),
                const SizedBox(height: 12),
                if (typeController.text == 'video')
                   TextField(
                      controller: contentController,
                      decoration: const InputDecoration(
                        labelText: 'Video URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                if (typeController.text == 'text')
                  TextField(
                    controller: contentController,
                    decoration: const InputDecoration(labelText: 'Content Markdown', border: OutlineInputBorder()),
                    maxLines: 5,
                  ),
                if (typeController.text == 'file') ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await FilePicker.platform.pickFiles(withData: true);
                      if (picked != null) {
                        setDialogState(() {
                          fileBytes = picked.files.single.bytes;
                          fileName = picked.files.single.name;
                        });
                      }
                    },
                    icon: const Icon(Icons.upload_file),
                    label: Text(fileName ?? 'Select File'),
                  ),
                  if (fileName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(fileName!, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => ctx.pop(true), child: const Text('Create')),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await ref.read(courseRepositoryProvider).createLesson(
          moduleId: moduleId,
          title: titleController.text.trim(),
          contentType: typeController.text,
          content: typeController.text == 'text' ? contentController.text : null,
          videoUrl: typeController.text == 'video' ? contentController.text : null,
          fileBytes: fileBytes,
          fileName: fileName,
        );
        if (!mounted) return;
        ref.invalidate(courseDetailProvider(widget.courseId));
        _loadCourse();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_course == null) return const Scaffold(body: Center(child: Text('Course not found')));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Academy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded),
            onPressed: () => _showEditCourseDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            tooltip: 'Delete Academy',
            onPressed: () => _deleteCourse(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPendingRequestsBanner(ref),
            const SizedBox(height: 16),
            // Academy Header Card
            Card(
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      image: (_course!.imageUrl != null && _course!.imageUrl!.startsWith('http'))
                          ? DecorationImage(
                              image: NetworkImage(_course!.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
                  InkWell(
                    onTap: _setImageUrl,
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.link_rounded, color: Colors.white, size: 36),
                            SizedBox(height: 8),
                            Text("Set Image URL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.vpn_key_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text("Join Code: ${_course!.joinCode}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary)),
                                  const Spacer(),
                                  Text("Level: ${_course!.eduLevel.name.toUpperCase()}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(_course!.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Curriculum", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                FilledButton.icon(
                  onPressed: _addModule,
                  icon: const Icon(Icons.add_box_rounded, size: 18),
                  label: const Text("Add Module"),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            if (_course!.modules.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(48),
                  child: Column(
                    children: [
                      Icon(Icons.layers_clear_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      const Text("Your academy has no modules yet.", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ReorderableListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final modules = _course!.modules.toList();
                  final item = modules.removeAt(oldIndex);
                  modules.insert(newIndex, item);
                  try {
                    await ref.read(courseRepositoryProvider).updateModule(item.id, order: newIndex + 1);
                    _loadCourse();
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reorder failed: $e')));
                  }
                },
                children: _course!.modules.map((module) => Card(
                  key: ValueKey(module.id),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                  child: ExpansionTile(
                    title: Text(module.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: Text("${module.lessons.length} lessons"),
                    leading: const Icon(Icons.drag_indicator_rounded, color: Colors.grey),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.blue), onPressed: () => _addLesson(module.id)),
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showEditModuleDialog(module)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteModule(module.id)),
                      ],
                    ),
                    children: module.lessons.map((lesson) => ListTile(
                      dense: true,
                      leading: Icon(_getLessonIcon(lesson.contentType), size: 20),
                      title: Text(lesson.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (lesson.contentType == 'quiz')
                            IconButton(
                              icon: const Icon(Icons.insights_rounded, color: Colors.orange, size: 18),
                              onPressed: () async {
                                final quiz = await ref.read(courseRepositoryProvider).getQuizForLesson(lesson.id);
                                if (quiz != null && context.mounted) {
                                  context.pushNamed('quiz_attempts', pathParameters: {'quizId': quiz.id}, extra: lesson.title);
                                }
                              },
                            ),
                          IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: () => _showEditLessonDialog(lesson)),
                          IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: () => _deleteLesson(lesson.id)),
                        ],
                      ),
                    )).toList(),
                  ),
                )).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestsBanner(WidgetRef ref) {
    final requestsAsync = ref.watch(enrollmentRequestsProvider);
    return requestsAsync.when(
      data: (requests) {
        final courseRequests = requests.where((r) => r.courseId == widget.courseId).toList();
        if (courseRequests.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MinimalContainer(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            borderRadius: 16,
            color: AppColors.orange.withValues(alpha: 0.1),
            child: Row(
              children: [
                const Icon(Icons.person_add_rounded, color: AppColors.orange),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    "${courseRequests.length} students waiting for approval",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.orange),
                  ),
                ),
                TextButton(
                  onPressed: () => _showRequestsDialog(courseRequests),
                  child: const Text("View All"),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  void _showRequestsDialog(List<EnrollmentSummary> requests) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Enrollment Requests"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final r = requests[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(r.studentName[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ),
                title: Text(r.studentName), 
                subtitle: const Text("Waiting for join code"),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  tooltip: "Share Join Code",
                  onPressed: () {
                    final code = _course?.joinCode;
                    if (code != null) {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Join code copied for ${r.studentName}: $code")),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text("Close")),
        ],
      ),
    );
  }

  IconData _getLessonIcon(String? type) {
    switch (type) {
      case 'video': return Icons.play_circle_outline_rounded;
      case 'quiz': return Icons.quiz_outlined;
      default: return Icons.article_outlined;
    }
  }

  // --- Helper Methods (Edit/Delete Dialogs) ---

  Future<void> _showEditCourseDialog() async {
    final titleController = TextEditingController(text: _course!.title);
    final descController = TextEditingController(text: _course!.description);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit academy details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Academy Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => ctx.pop(true), child: const Text('Update')),
        ],
      ),
    );

    if (result == true) {
      try {
        await ref.read(courseRepositoryProvider).updateCourse(
          widget.courseId,
          title: titleController.text.trim(),
          description: descController.text.trim(),
        );

        ref.invalidate(courseDetailProvider(widget.courseId));
        _loadCourse();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showEditModuleDialog(ModuleModel module) async {
    final titleController = TextEditingController(text: module.title);
    final descController = TextEditingController(text: module.description ?? '');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit module'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => ctx.pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      try {
        await ref.read(courseRepositoryProvider).updateModule(
          module.id,
          title: titleController.text.trim(),
          description: descController.text.trim(),
        );
        ref.invalidate(courseDetailProvider(widget.courseId));
        _loadCourse();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showEditLessonDialog(LessonModel lesson) async {
    final titleController = TextEditingController(text: lesson.title);
    final contentController = TextEditingController(text: lesson.content ?? lesson.videoUrl ?? '');
    Uint8List? fileBytes;
    String? fileName;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit lesson'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              if (lesson.contentType != 'file')
                TextField(
                  controller: contentController,
                  decoration: InputDecoration(
                    labelText: lesson.contentType == 'video' ? 'Video URL' : 'Content',
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: lesson.contentType == 'video' ? 1 : 4,
                ),
              if (lesson.contentType == 'file') ...[
                if (lesson.attachmentUrl != null)
                   Padding(
                     padding: const EdgeInsets.only(bottom: 12.0),
                     child: Text("Current: ${lesson.attachmentUrl!.split('/').last}", style: const TextStyle(fontSize: 12, color: Colors.blue)),
                   ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await FilePicker.platform.pickFiles(withData: true);
                    if (picked != null) {
                      setDialogState(() {
                        fileBytes = picked.files.single.bytes;
                        fileName = picked.files.single.name;
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file),
                  label: Text(fileName ?? 'Replace File'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
            FilledButton(onPressed: () => ctx.pop(true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (result == true) {
      try {
        await ref.read(courseRepositoryProvider).updateLesson(
          lesson.id,
          title: titleController.text.trim(),
          contentData: (lesson.contentType == 'video' || lesson.contentType == 'file') ? null : contentController.text.trim(),
          videoUrl: lesson.contentType == 'video' ? contentController.text.trim() : null,
          fileBytes: fileBytes,
          fileName: fileName,
        );
        if (!mounted) return;
        ref.invalidate(courseDetailProvider(widget.courseId));
        _loadCourse();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteCourse() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Academy?'),
        content: const Text('This will permanently remove the academy and all its content. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => ctx.pop(true), 
            child: const Text('Delete Everything', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final repo = ref.read(courseRepositoryProvider);
        await repo.deleteCourse(widget.courseId);
        
        if (!mounted) return;
        
        ref.invalidate(dashboardProvider);
        context.goNamed('home');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Academy deleted successfully')));
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
        }
      }
    }
  }

  Future<void> _deleteModule(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete module?'),
        content: const Text('This will permanently remove the module and all its lessons.'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => ctx.pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(courseRepositoryProvider).deleteModule(id);
        ref.invalidate(courseDetailProvider(widget.courseId));
        _loadCourse();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteLesson(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete lesson?'),
        content: const Text('Are you sure you want to remove this lesson?'),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => ctx.pop(true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(courseRepositoryProvider).deleteLesson(id);
        ref.invalidate(courseDetailProvider(widget.courseId));
        _loadCourse();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
