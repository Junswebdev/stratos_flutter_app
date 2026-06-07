import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme.dart';
import '../../../../core/widgets/minimalist_widgets.dart';
import '../../../home/application/home_providers.dart';
import '../../../home/data/home_models.dart';
import '../../../home/presentation/widgets/async_state_view.dart';
import '../../../../core/utils/url_utils.dart';

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
    const accentColor = AppColors.primary;

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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final crossAxisCount = width > 1200 ? 4 : (width > 900 ? 3 : (width > 600 ? 2 : 1));

                    if (coursesAsync.value == null || coursesAsync.value!.isEmpty) {
                       return SingleChildScrollView(
                         physics: const AlwaysScrollableScrollPhysics(),
                         child: _buildEmptyState(
                          context,
                          ref,
                          isInstructor,
                          searchQuery.isNotEmpty || selectedCategory != null,
                        ),
                       );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: coursesAsync.value!.length,
                      itemBuilder: (context, index) {
                        final course = coursesAsync.value![index];
                        final isOwner = userData?.role == 'admin' ||
                            (userData?.role == 'instructor' && course.instructorId == userData?.id);
                        final showJoin = (course.enrollmentStatus == null || course.enrollmentStatus!.isEmpty) && !isOwner && userData?.role == 'student';

                        return _ModernCourseCard(
                          course: course,
                          isOwner: isOwner,
                          showJoin: showJoin,
                          onTap: () => context.pushNamed('course_detail', pathParameters: {'id': course.id}),
                        );
                      },
                    );
                  },
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
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : AppColors.background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
            ),
            child: TextField(
              onChanged: (val) => ref.read(courseSearchQueryProvider.notifier).update(val),
              decoration: InputDecoration(
                hintText: 'Search courses or keywords...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () => ref.read(courseSearchQueryProvider.notifier).update(''),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'All Courses',
                  isSelected: selectedCategory == null,
                  onSelected: (_) => ref.read(courseCategoryFilterProvider.notifier).update(null),
                  activeColor: accentColor,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Higher Ed',
                  isSelected: selectedCategory == 'HIGHER_ED',
                  onSelected: (_) => ref.read(courseCategoryFilterProvider.notifier).update('HIGHER_ED'),
                  activeColor: accentColor,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Secondary',
                  isSelected: selectedCategory == 'SECONDARY',
                  onSelected: (_) => ref.read(courseCategoryFilterProvider.notifier).update('SECONDARY'),
                  activeColor: accentColor,
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Primary',
                  isSelected: selectedCategory == 'PRIMARY',
                  onSelected: (_) => ref.read(courseCategoryFilterProvider.notifier).update('PRIMARY'),
                  activeColor: accentColor,
                ),
              ],
            ),
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
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFiltered ? Icons.search_off_rounded : Icons.school_outlined,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isFiltered ? 'No matches found' : 'No courses available',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Try adjusting your search query or filters.'
                  : (isInstructor
                      ? "Start by creating your first course to share your knowledge."
                      : 'Enroll in a course to start your learning journey.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (isFiltered) ...[
              const SizedBox(height: 24),
              MinimalButton(
                width: 180,
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
    final isDark = theme.brightness == Brightness.dark;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: activeColor,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      checkmarkColor: Colors.black,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : theme.colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? activeColor : (isDark ? AppColors.darkBorder : AppColors.border),
        ),
      ),
      showCheckmark: false,
    );
  }
}

class _ModernCourseCard extends ConsumerWidget {
  const _ModernCourseCard({
    required this.course,
    required this.isOwner,
    required this.showJoin,
    required this.onTap,
  });

  final CourseSummary course;
  final bool isOwner;
  final bool showJoin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formatUrl = ref.watch(urlFormatterProvider);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Area
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: (course.imageUrl?.isNotEmpty == true)
                        ? Image.network(formatUrl(course.imageUrl), fit: BoxFit.cover)
                        : Center(child: Icon(Icons.school_rounded, color: AppColors.primary.withValues(alpha: 0.3), size: 48)),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _StatusBadge(
                      label: course.level.toUpperCase(),
                      color: AppColors.textHeader.withValues(alpha: 0.8),
                      isDark: true,
                    ),
                  ),
                ],
              ),
            ),
            // Content Area
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      course.instructorName,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.layers_outlined, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text('${course.modulesCount} modules', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Spacer(),
                        if (isOwner) 
                           const _StatusBadge(label: 'OWNER', color: Colors.black)
                        else if (course.enrollmentStatus == 'approved')
                           const _StatusBadge(label: 'ENROLLED', color: AppColors.primary)
                        else if (course.enrollmentStatus == 'pending')
                           const _StatusBadge(label: 'PENDING', color: AppColors.warning),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color, this.isDark = false});
  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.black87 : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isDark ? Colors.white : color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
