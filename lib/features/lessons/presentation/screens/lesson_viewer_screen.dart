import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../courses/domain/lesson_model.dart';
import '../../../home/presentation/widgets/async_state_view.dart';
import '../../../home/application/home_providers.dart';
import '../../../../data/dio_client.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/minimalist_widgets.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.title,
            style: theme.textTheme.headlineLarge?.copyWith(fontSize: 28),
          ),
          if (lesson.description != null && lesson.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              lesson.description!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 40),
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
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Text('No content available for this lesson.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({required this.imageUrl});

  final String imageUrl;

  String _buildFullUrl(String path, WidgetRef ref) {
    if (path.startsWith('http')) return path;
    final serverBaseUrl = ref.read(serverBaseUrlProvider);
    return '$serverBaseUrl${path.startsWith('/') ? '' : '/'}$path';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final fullUrl = _buildFullUrl(imageUrl, ref);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            fullUrl,
            width: double.infinity,
            fit: BoxFit.contain,
            errorBuilder: (ctx, err, stack) => Container(
              height: 200,
              color: AppColors.background,
              child: const Center(child: Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey)),
            ),
          ),
        );
      },
    );
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: SelectableText(
        content,
        style: theme.textTheme.bodyLarge?.copyWith(height: 1.7, color: theme.colorScheme.onSurface),
      ),
    );
  }
}

class _VideoContent extends StatefulWidget {
  const _VideoContent({required this.videoUrl});

  final String videoUrl;

  @override
  State<_VideoContent> createState() => _VideoContentState();
}

class _VideoContentState extends State<_VideoContent> {
  late YoutubePlayerController _controller;
  String? _videoId;

  @override
  void initState() {
    super.initState();
    _videoId = YoutubePlayerController.convertUrlToId(widget.videoUrl);
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        showControls: true,
        mute: false,
        showVideoAnnotations: false,
      ),
    );
    
    if (_videoId != null) {
      _controller.cueVideoById(videoId: _videoId!);
    }
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_videoId == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text('Invalid Video URL', style: theme.textTheme.titleMedium?.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(widget.videoUrl, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: YoutubePlayerScaffold(
            controller: _controller,
            aspectRatio: 16 / 9,
            builder: (context, player) => player,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Video Resource',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _FileContent extends StatelessWidget {
  const _FileContent({required this.attachmentUrl});

  final String attachmentUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fileName = attachmentUrl.split('/').last;

    return Consumer(
      builder: (context, ref, _) {
        final serverBaseUrl = ref.read(serverBaseUrlProvider);
        final fullUrl = attachmentUrl.startsWith('http')
            ? attachmentUrl
            : '$serverBaseUrl${attachmentUrl.startsWith('/') ? '' : '/'}$attachmentUrl';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.file_present_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Text('Learning Resource', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              MinimalButton(
                width: 100,
                height: 40,
                borderRadius: 8,
                onPressed: () async {
                   final uri = Uri.parse(fullUrl);
                   await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: const Text('Download', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      },
    );
  }
}
