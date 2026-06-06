import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../courses/domain/lesson_model.dart';
import '../../../home/presentation/widgets/async_state_view.dart';
import '../../data/lesson_repository.dart';
import '../controllers/lesson_controller.dart';
import 'quiz_screen.dart';

class LessonViewerScreen extends ConsumerWidget {
  const LessonViewerScreen({
    super.key,
    required this.lessonId,
    required this.courseId,
    this.lessonTitle,
  });

  final String lessonId;
  final String courseId;
  final String? lessonTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonAsync = ref.watch(lessonDetailProvider(lessonId));

    return Scaffold(
      appBar: AppBar(
        title: Text(lessonTitle ?? 'Lesson'),
        actions: [
          lessonAsync.whenOrNull(
            data: (lesson) => _CompletionButton(lesson: lesson, courseId: courseId),
          ) ?? const SizedBox.shrink(),
        ],
      ),
      body: AsyncStateView(
        isLoading: lessonAsync.isLoading,
        hasError: lessonAsync.hasError,
        errorMessage: lessonAsync.error?.toString(),
        onRetry: () => ref.invalidate(lessonDetailProvider(lessonId)),
        loadingLabel: 'Loading lesson',
        child: lessonAsync.value == null
            ? const SizedBox.shrink()
            : lessonAsync.value!.contentType == 'quiz'
                ? QuizScreen(lessonId: lessonId, courseId: courseId)
                : _LessonContent(lesson: lessonAsync.value!, courseId: courseId),
      ),
    );
  }
}

class _CompletionButton extends ConsumerWidget {
  const _CompletionButton({required this.lesson, required this.courseId});

  final LessonModel lesson;
  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(courseProgressProvider(courseId));
    final isCompleted = progressAsync.asData?.value[lesson.id] ?? lesson.isCompleted;

    return IconButton(
      icon: Icon(
        isCompleted ? Icons.check_circle : Icons.check_circle_outline,
        color: isCompleted ? Colors.green : null,
      ),
      tooltip: isCompleted ? 'Mark incomplete' : 'Mark complete',
      onPressed: () async {
        final repo = ref.read(lessonRepositoryProvider);
        try {
          if (isCompleted) {
            await repo.uncompleteLesson(lesson.id);
          } else {
            await repo.completeLesson(lesson.id);
          }
          ref.invalidate(courseProgressProvider(courseId));
          ref.invalidate(lessonDetailProvider(lesson.id));
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to update: $e')),
            );
          }
        }
      },
    );
  }
}

class _LessonContent extends StatelessWidget {
  const _LessonContent({required this.lesson, required this.courseId});

  final LessonModel lesson;
  final String courseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.title,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (lesson.description != null && lesson.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              lesson.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          _ContentBody(lesson: lesson),
        ],
      ),
    );
  }
}

class _ContentBody extends StatelessWidget {
  const _ContentBody({required this.lesson});

  final LessonModel lesson;

  @override
  Widget build(BuildContext context) {
    if (lesson.contentType == 'video' || (lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty)) {
      return _VideoContent(videoUrl: lesson.videoUrl ?? lesson.content ?? '');
    }
    
    // Check attachmentUrl (which maps to file_url from the DB)
    if (lesson.attachmentUrl != null && lesson.attachmentUrl!.isNotEmpty) {
      final ext = lesson.attachmentUrl!.split('.').last.toLowerCase();
      final isImage = ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext);
      
      if (isImage || lesson.contentType == 'image') {
        return _ImageContent(imageUrl: lesson.attachmentUrl!);
      }
      return _FileContent(attachmentUrl: lesson.attachmentUrl!);
    }
    
    if (lesson.content != null && lesson.content!.isNotEmpty) {
      return _TextContent(content: lesson.content!);
    }
    
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text('No content available for this lesson.'),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.imageUrl});

  final String imageUrl;

  String _buildFullUrl(String path) {
    if (path.startsWith('http')) return path;
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api/v1/');
    // Clean up the URL construction
    final base = baseUrl.replaceAll('/api/v1/', '');
    return '$base$path';
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = _buildFullUrl(imageUrl);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            fullUrl,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => Container(
              height: 200,
              color: Colors.grey.shade300,
              child: const Center(child: Icon(Icons.broken_image, size: 64, color: Colors.grey)),
            ),
          ),
        ),
      ],
    );
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        content,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
      ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  const _VideoContent({required this.videoUrl});

  final String videoUrl;

  String _buildFullUrl(String path) {
    if (path.startsWith('http')) return path;
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api/v1/');
    final base = baseUrl.replaceAll('/api/v1/', '');
    return '$base$path';
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = _buildFullUrl(videoUrl);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  'Video Player',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SelectableText(
          fullUrl,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _FileContent extends StatelessWidget {
  const _FileContent({required this.attachmentUrl});

  final String attachmentUrl;

  String _buildFullUrl(String path) {
    if (path.startsWith('http')) return path;
    const baseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:8000/api/v1/');
    final base = baseUrl.replaceAll('/api/v1/', '');
    return '$base$path';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = attachmentUrl.split('/').last;
    final fullUrl = _buildFullUrl(attachmentUrl);

    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf, color: Colors.red),
        ),
        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: const Text('Document attached'),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          tooltip: 'Open document',
          onPressed: () async {
             final uri = Uri.parse(fullUrl);
             if (await canLaunchUrl(uri)) {
               await launchUrl(uri, mode: LaunchMode.externalApplication);
             } else {
               if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Could not open document')),
                 );
               }
             }
          },
        ),
      ),
    );
  }
}
