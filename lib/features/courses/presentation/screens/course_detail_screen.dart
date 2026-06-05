import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/widgets/minimalist_widgets.dart';
import '../../../home/application/home_providers.dart';
import '../../../home/data/home_models.dart';
import '../../../home/presentation/widgets/async_state_view.dart';
import '../../../home/presentation/widgets/section_header.dart';

class CourseDetailScreen extends ConsumerWidget {
  const CourseDetailScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseDetailProvider(courseId));
    final profileAsync = ref.watch(profileProvider);
    final courseData = courseAsync.asData?.value;
    final userData = profileAsync.asData?.value;

    final isInstructor = courseData != null &&
        userData != null &&
        (userData.role == 'admin' ||
            (userData.role == 'instructor' && courseData.instructorId == userData.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(courseData?.title ?? 'Course'),
        actions: [
          IconButton(
            icon: Icon(_themeIcon(ref.watch(themeModeProvider))),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
          if (courseData?.isEnrolled == true && !isInstructor)
            IconButton(
              icon: const Icon(Icons.psychology_outlined, color: AppColors.primary),
              onPressed: () => context.pushNamed(
                'course_ai',
                pathParameters: {'id': courseId},
                extra: courseData?.title,
              ),
            ),
          if (isInstructor)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.pushNamed('manage_course', pathParameters: {'id': courseId}),
            ),
        ],
      ),
      body: AsyncStateView(
        isLoading: courseAsync.isLoading,
        hasError: courseAsync.hasError,
        errorMessage: courseAsync.error?.toString(),
        onRetry: () => ref.invalidate(courseDetailProvider(courseId)),
        loadingLabel: 'Fetching course details...',
        child: courseData == null
            ? const SizedBox.shrink()
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(courseDetailProvider(courseId)),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  children: [
                    _buildCourseHeader(context, courseData, isInstructor, ref),
                    const SizedBox(height: 24),
                    _buildMetaSection(context, courseData),
                    const SizedBox(height: 24),
                    if (courseData.announcementsCount > 0) ...[
                      _buildCourseAnnouncements(context, courseId),
                      const SizedBox(height: 24),
                    ],
                    _buildDescriptionSection(context, courseData),
                    const SizedBox(height: 24),
                    if (courseData.enrollmentStatus == 'approved' || isInstructor)
                       _ModulesSection(course: courseData, isInstructor: isInstructor)
                    else
                       _buildCurriculumLocked(context),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCurriculumLocked(BuildContext context) {
    final theme = Theme.of(context);
    return MinimalContainer(
      padding: const EdgeInsets.all(32),
      borderRadius: 24,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          Icon(Icons.lock_outline_rounded, size: 48, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text(
            'Curriculum Locked',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'The course content is private. Please enroll and get approved by your instructor to access the full curriculum.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseHeader(BuildContext context, CourseDetailData course, bool isInstructor, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = getGradientColor(course.title + course.id);

    return MinimalContainer(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (course.imageUrl != null && course.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: SizedBox(
                height: 180,
                width: double.infinity,
                child: Image.network(
                  course.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: accent.withValues(alpha: 0.08),
                    child: Icon(Icons.auto_stories_rounded, color: accent, size: 48),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _DetailChip(label: course.level.toUpperCase(), color: accent),
                    if (!isInstructor && course.enrollmentStatus != null && course.enrollmentStatus!.isNotEmpty) ...[
                      if (course.enrollmentStatus == 'approved')
                        const _DetailChip(label: 'ENROLLED', color: AppColors.success)
                      else if (course.enrollmentStatus == 'pending')
                        const _DetailChip(label: 'PENDING APPROVAL', color: AppColors.orange),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                Text(course.title, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: accent.withValues(alpha: 0.1),
                      child: Text(
                        course.instructorName[0].toUpperCase(),
                        style: TextStyle(color: accent, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        course.instructorName,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!isInstructor && (course.enrollmentStatus == null || course.enrollmentStatus!.isEmpty))
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final container = ProviderScope.containerOf(context);
                        try {
                           await container.read(homeRepositoryProvider).joinCourse(course.id);
                           container.invalidate(courseDetailProvider(course.id));
                           container.invalidate(dashboardProvider);
                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                               const SnackBar(content: Text('Enrollment request sent! Please ask your teacher for the join code.')),
                             );
                           }
                        } catch (e) {
                           if (context.mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                           }
                        }
                      },
                      icon: const Icon(Icons.send_rounded),
                      label: const Text('Request to Enroll'),
                    ),
                  )
                else if (!isInstructor && course.enrollmentStatus == 'pending')
                  _JoinCodeInput(courseId: course.id)
                else if (course.progressPercent > 0 || course.enrollmentStatus == 'approved' || isInstructor)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!isInstructor) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Course Progress',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              '${course.progressPercent.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: course.progressPercent / 100,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.surfaceContainer,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: accent),
                            foregroundColor: accent,
                          ),
                          onPressed: () => context.pushNamed(
                            'course_chat',
                            pathParameters: {'courseId': course.id},
                            extra: course.title,
                          ),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                          label: const Text('Course Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaSection(BuildContext context, CourseDetailData course) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _MetaBox(label: 'Modules', value: '${course.modulesCount}', icon: Icons.view_module_rounded),
        _MetaBox(label: 'Lessons', value: '${course.lessonsCount}', icon: Icons.play_lesson_rounded),
        _MetaBox(label: 'Updates', value: '${course.announcementsCount}', icon: Icons.campaign_rounded),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context, CourseDetailData course) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('About this course', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Text(
          course.description.isNotEmpty ? course.description : 'No description provided.',
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildCourseAnnouncements(BuildContext context, String courseId) {
    return Consumer(
      builder: (context, ref, _) {
        final announcementsAsync = ref.watch(announcementsProvider);
        return announcementsAsync.when(
          data: (announcements) {
            final courseAnnouncements = announcements.where((a) => a.courseId == courseId).toList();
            if (courseAnnouncements.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Course Updates', subtitle: 'News from your instructor'),
                const SizedBox(height: 12),
                ...courseAnnouncements.take(2).map(
                      (a) => MinimalContainer(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(16),
                        borderRadius: 20,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.campaign_rounded, color: AppColors.primary),
                          title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(a.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _JoinCodeInput extends ConsumerStatefulWidget {
  const _JoinCodeInput({required this.courseId});
  final String courseId;

  @override
  ConsumerState<_JoinCodeInput> createState() => _JoinCodeInputState();
}

class _JoinCodeInputState extends ConsumerState<_JoinCodeInput> {
  final _controller = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MinimalContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      color: theme.colorScheme.primary.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Finalize Enrollment', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Your request is pending. Enter the 6-digit code provided by your instructor to join.',
            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isSubmitting,
                  autofocus: true,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Enter Code',
                    filled: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Join'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.isEmpty) return;
    
    setState(() => _isSubmitting = true);
    final container = ProviderScope.containerOf(context);
    try {
      await container.read(homeRepositoryProvider).joinCourseByCode(code);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome to the course!')),
      );
      
      // We set to false just in case the parent doesn't rebuild immediately
      setState(() => _isSubmitting = false);
      
      // Invalidate to trigger a rebuild of the parent
      container.invalidate(courseDetailProvider(widget.courseId));
      container.invalidate(dashboardProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid code: $e')),
      );
      setState(() => _isSubmitting = false);
    }
  }
}

class _MetaBox extends StatelessWidget {
  const _MetaBox({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 140,
      child: MinimalContainer(
        padding: const EdgeInsets.all(16),
        borderRadius: 18,
        color: theme.colorScheme.surfaceContainerHighest,
        child: Column(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}

class _ModulesSection extends StatelessWidget {
  const _ModulesSection({required this.course, required this.isInstructor});

  final CourseDetailData course;
  final bool isInstructor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Curriculum', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        if (course.modules.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                isInstructor ? 'Add modules to start building the curriculum.' : 'No content available yet.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          ...course.modules.map(
            (module) => MinimalContainer(
              margin: const EdgeInsets.only(bottom: 12),
              borderRadius: 20,
              child: ExpansionTile(
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                title: Text(module.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${module.lessons.length} Lessons', style: const TextStyle(fontSize: 12)),
                children: module.lessons
                    .map(
                      (lesson) => ListTile(
                        leading: Icon(
                          lesson.isCompleted
                              ? Icons.check_circle_rounded
                              : Icons.play_circle_filled_rounded,
                          color: lesson.isCompleted ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          lesson.title,
                          style: TextStyle(fontWeight: lesson.isCompleted ? FontWeight.normal : FontWeight.bold),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () {
                          if (lesson.contentType == 'quiz') {
                            context.pushNamed(
                              'quiz_taking',
                              pathParameters: {'lessonId': lesson.id},
                              extra: lesson.title,
                            );
                          } else {
                            context.pushNamed(
                              'lesson_viewer',
                              pathParameters: {'courseId': course.id, 'lessonId': lesson.id},
                              extra: lesson.title,
                            );
                          }
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

IconData _themeIcon(ThemeMode mode) {
  return switch (mode) {
    ThemeMode.system => Icons.brightness_auto,
    ThemeMode.dark => Icons.dark_mode,
    ThemeMode.light => Icons.light_mode,
  };
}
