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
          if (courseData?.isEnrolled == true && !isInstructor)
            IconButton(
              icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary),
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                  children: [
                    _buildCourseHeader(context, courseData, isInstructor),
                    const SizedBox(height: 32),
                    _buildMetaSection(context, courseData),
                    const SizedBox(height: 32),
                    if (courseData.announcementsCount > 0) ...[
                      _buildCourseAnnouncements(context, courseId),
                      const SizedBox(height: 32),
                    ],
                    _buildDescriptionSection(context, courseData),
                    const SizedBox(height: 40),
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded, size: 32, color: AppColors.primary),
          ),
          const SizedBox(height: 24),
          const Text(
            'Curriculum Locked',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Enroll and get approved by your instructor to access the course content.',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseHeader(BuildContext context, CourseDetailData course, bool isInstructor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (course.imageUrl != null && course.imageUrl!.isNotEmpty)
          Container(
            height: 240,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              image: DecorationImage(
                image: Image.network(course.imageUrl!).image,
                fit: BoxFit.cover,
              ),
            ),
          ),
        
        Row(
          children: [
            _DetailChip(label: course.level.toUpperCase(), color: AppColors.textHeader, isDark: true),
            const SizedBox(width: 8),
            if (!isInstructor && course.enrollmentStatus != null && course.enrollmentStatus!.isNotEmpty) ...[
              if (course.enrollmentStatus == 'approved')
                const _DetailChip(label: 'ENROLLED', color: AppColors.success)
              else if (course.enrollmentStatus == 'pending')
                const _DetailChip(label: 'PENDING', color: AppColors.warning),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Text(course.title, style: theme.textTheme.headlineLarge),
        const SizedBox(height: 12),
        Row(
          children: [
            SafeAvatar(
              imageUrl: null, // Replace with instructor avatar if available
              radius: 12,
              fallbackText: course.instructorName[0].toUpperCase(),
            ),
            const SizedBox(width: 10),
            Text(
              course.instructorName,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 32),
        if (!isInstructor && (course.enrollmentStatus == null || course.enrollmentStatus!.isEmpty))
          MinimalButton(
            onPressed: () async {
              final container = ProviderScope.containerOf(context);
              try {
                  await container.read(homeRepositoryProvider).joinCourse(course.id);
                  container.invalidate(courseDetailProvider(course.id));
                  container.invalidate(dashboardProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enrollment request sent!')),
                    );
                  }
              } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
              }
            },
            child: const Text('Enroll Now'),
          )
        else if (!isInstructor && course.enrollmentStatus == 'pending')
          _JoinCodeInput(courseId: course.id)
        else if (course.enrollmentStatus == 'approved' || isInstructor)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isInstructor) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Course Progress', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      '${course.progressPercent.toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: course.progressPercent / 100,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white10 : AppColors.border,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 32),
              ],
              Row(
                children: [
                  Expanded(
                    child: MinimalButton(
                      onPressed: () => context.pushNamed(
                        'course_chat',
                        pathParameters: {'courseId': course.id},
                        extra: course.title,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Course Discussions'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMetaSection(BuildContext context, CourseDetailData course) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _MetaBox(label: 'Modules', value: '${course.modulesCount}', icon: Icons.view_module_outlined),
          const SizedBox(width: 12),
          _MetaBox(label: 'Lessons', value: '${course.lessonsCount}', icon: Icons.play_lesson_outlined),
          const SizedBox(width: 12),
          _MetaBox(label: 'Updates', value: '${course.announcementsCount}', icon: Icons.campaign_outlined),
        ],
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context, CourseDetailData course) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About Course', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(
          course.description.isNotEmpty ? course.description : 'No description provided.',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
                Text('Recent Updates', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ...courseAnnouncements.take(2).map(
                      (a) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 20),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text(a.body, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                          ],
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Verification Required', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            'Enter the code from your instructor to unlock this course.',
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isSubmitting,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Code',
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Unlock'),
                ),
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Course unlocked!')));
      setState(() => _isSubmitting = false);
      container.invalidate(courseDetailProvider(widget.courseId));
      container.invalidate(dashboardProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid code: $e')));
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 110,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.label, required this.color, this.isDark = false});
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? AppColors.textHeader : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: isDark ? Colors.white : color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
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
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Curriculum', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        if (course.modules.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(
                'No content available yet.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          )
        else
          ...course.modules.map(
            (module) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
              ),
              child: Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  title: Text(module.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  subtitle: Text('${module.lessons.length} sections', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  children: [
                    const Divider(height: 1),
                    ...module.lessons.map(
                      (lesson) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                        leading: Icon(
                          lesson.isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          color: lesson.isCompleted ? AppColors.success : AppColors.primary,
                          size: 20,
                        ),
                        title: Text(
                          lesson.title,
                          style: TextStyle(
                            fontSize: 14, 
                            fontWeight: lesson.isCompleted ? FontWeight.w400 : FontWeight.w600,
                            color: lesson.isCompleted ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurface,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                        onTap: () {
                          if (lesson.contentType == 'quiz') {
                            context.pushNamed('quiz_taking', pathParameters: {'lessonId': lesson.id}, extra: lesson.title);
                          } else {
                            context.pushNamed('lesson_viewer', pathParameters: {'courseId': course.id, 'lessonId': lesson.id}, extra: lesson.title);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
