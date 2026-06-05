import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme.dart';
import '../../../../core/widgets/minimalist_widgets.dart';
import '../../../home/application/home_providers.dart';
import '../../../home/data/home_models.dart';
import '../../../home/presentation/widgets/async_state_view.dart';

class CourseListScreen extends ConsumerWidget {
  const CourseListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(browseCoursesProvider);
    final searchQuery = ref.watch(courseSearchQueryProvider);
    final selectedCategory = ref.watch(courseCategoryFilterProvider);
    final profileAsync = ref.watch(profileProvider);
    final userData = profileAsync.asData?.value;
    final isInstructor = userData?.role == 'instructor' || userData?.role == 'admin';
    final theme = Theme.of(context);
    final accentColor = isInstructor ? theme.colorScheme.primary : theme.colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(isInstructor ? 'Academy Management' : 'Explore Academy'),
        actions: [
          if (!isInstructor)
            IconButton(
              icon: const Icon(Icons.add_link_rounded),
              tooltip: 'Join course by code',
              onPressed: () => _showJoinCourseDialog(context, ref),
            ),
        ],
      ),
      floatingActionButton: isInstructor
          ? FloatingActionButton.extended(
              onPressed: () => context.pushNamed('create_course'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create New Course'),
            )
          : null,
      body: Column(
        children: [
          _buildSearchAndFilter(context, ref, searchQuery, selectedCategory, accentColor),
          Expanded(
            child: AsyncStateView(
              isLoading: coursesAsync.isLoading,
              hasError: coursesAsync.hasError,
              errorMessage: coursesAsync.error?.toString(),
              onRetry: () => ref.invalidate(browseCoursesProvider),
              loadingLabel: 'Loading academy data...',
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(browseCoursesProvider),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    if (coursesAsync.value == null || coursesAsync.value!.isEmpty)
                      _buildEmptyState(
                        context,
                        ref,
                        isInstructor,
                        searchQuery.isNotEmpty || selectedCategory != null,
                      )
                    else
                      ...coursesAsync.value!.map((course) {
                        final isOwner = userData?.role == 'admin' ||
                            (userData?.role == 'instructor' && course.instructorId == userData?.id);
                        final showJoin = (course.enrollmentStatus == null || course.enrollmentStatus!.isEmpty) && !isOwner && userData?.role == 'student';

                        return _CourseCard(
                          course: course,
                          isOwner: isOwner,
                          showJoin: showJoin,
                          accentColor: accentColor,
                          onTap: () => context.pushNamed('course_detail', pathParameters: {'id': course.id}),
                          onJoin: () async {
                            final container = ProviderScope.containerOf(context);
                            try {
                              await container.read(homeRepositoryProvider).joinCourse(course.id);
                              container.invalidate(browseCoursesProvider);
                              container.invalidate(dashboardProvider);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Enrollment request sent!')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(
    BuildContext context,
    WidgetRef ref,
    String query,
    String? selectedCategory,
    Color accentColor,
  ) {
    final theme = Theme.of(context);

    return MinimalContainer(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MinimalTextField(
            labelText: 'Search courses or descriptions...',
            prefixIcon: const Icon(Icons.search_rounded),
            onSubmitted: (val) => ref.read(courseSearchQueryProvider.notifier).update(val),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () => ref.read(courseSearchQueryProvider.notifier).update(''),
                  )
                : null,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'All Categories',
                isSelected: selectedCategory == null,
                onSelected: (_) => ref.read(courseCategoryFilterProvider.notifier).update(null),
                activeColor: accentColor,
              ),
              _FilterChip(
                label: 'Primary',
                isSelected: selectedCategory == 'PRIMARY',
                onSelected: (_) => ref.read(courseCategoryFilterProvider.notifier).update('PRIMARY'),
                activeColor: accentColor,
              ),
              _FilterChip(
                label: 'Secondary',
                isSelected: selectedCategory == 'SECONDARY',
                onSelected: (_) => ref.read(courseCategoryFilterProvider.notifier).update('SECONDARY'),
                activeColor: accentColor,
              ),
              _FilterChip(
                label: 'Higher Ed',
                isSelected: selectedCategory == 'HIGHER_ED',
                onSelected: (_) => ref.read(courseCategoryFilterProvider.notifier).update('HIGHER_ED'),
                activeColor: accentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showJoinCourseDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Course'),
        content: MinimalTextField(
          controller: controller,
          labelText: 'Enter Join Code',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) return;

              try {
                await ref.read(homeRepositoryProvider).joinCourseByCode(code);
                if (context.mounted) {
                  Navigator.pop(context);
                  ref.invalidate(browseCoursesProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Successfully joined course!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to join: $e')),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref, bool isInstructor, bool isFiltered) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: MinimalContainer(
          padding: const EdgeInsets.all(28),
          borderRadius: 24,
          color: theme.colorScheme.surfaceContainerHighest,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFiltered ? Icons.search_off_rounded : Icons.school_outlined,
                size: 64,
                color: theme.colorScheme.primary.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 16),
              Text(
                isFiltered
                    ? 'No courses match your search or filter.'
                    : (isInstructor
                        ? "You haven't created any courses yet."
                        : 'No courses available at the moment.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (isFiltered) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    ref.read(courseSearchQueryProvider.notifier).update('');
                    ref.read(courseCategoryFilterProvider.notifier).update(null);
                  },
                  child: const Text('Clear Filters'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
    required this.activeColor,
  });

  final String label;
  final bool isSelected;
  final ValueChanged<bool> onSelected;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: activeColor.withValues(alpha: 0.2),
      checkmarkColor: activeColor,
      labelStyle: TextStyle(
        color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? activeColor : theme.colorScheme.outlineVariant),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.isOwner,
    required this.showJoin,
    required this.onTap,
    required this.onJoin,
    required this.accentColor,
  });

  final CourseSummary course;
  final bool isOwner;
  final bool showJoin;
  final VoidCallback onTap;
  final VoidCallback onJoin;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courseAccent = getGradientColor(course.title + course.id);

    return MinimalContainer(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      color: theme.colorScheme.surfaceContainerHighest,
      showHighlighter: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark ? Colors.white10 : courseAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (course.imageUrl != null && course.imageUrl!.isNotEmpty && course.imageUrl!.startsWith('http'))
                      ? Image.network(
                          course.imageUrl!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(Icons.auto_stories_rounded, color: theme.brightness == Brightness.dark ? Colors.white70 : courseAccent, size: 32),
                          ),
                        )
                      : Icon(Icons.auto_stories_rounded, color: theme.brightness == Brightness.dark ? Colors.white70 : courseAccent, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Tag(label: course.level.toUpperCase(), color: theme.brightness == Brightness.dark ? Colors.white70 : courseAccent),
                          if (course.enrollmentStatus == 'approved') const _Tag(label: 'ENROLLED', color: AppColors.success),
                          if (course.enrollmentStatus == 'pending') const _Tag(label: 'PENDING APPROVAL', color: AppColors.orange),
                          if (isOwner) const _Tag(label: 'OWNER', color: Colors.black87),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        course.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        course.instructorName, 
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              course.description.isNotEmpty
                  ? course.description
                  : 'Dive into this course to master new skills and expand your horizons.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _Stat(icon: Icons.view_module_rounded, label: '${course.modulesCount} Modules'),
                const SizedBox(width: 24),
                _Stat(icon: Icons.play_lesson_rounded, label: '${course.lessonsCount} Lessons'),
                const Spacer(),
                if (course.progressPercent > 0)
                  MinimalContainer(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    borderRadius: 8,
                    color: AppColors.success.withValues(alpha: 0.1),
                    child: Text(
                      '${course.progressPercent.toStringAsFixed(0)}% Done',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.success),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
