import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme.dart';
import '../../../../core/widgets/minimalist_widgets.dart';
import '../../../../core/widgets/netflix_content_row.dart';
import '../../application/home_providers.dart';
import '../../data/home_models.dart';
import '../widgets/async_state_view.dart';
import '../widgets/dashboard_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _refresh() async {
    ref.invalidate(dashboardProvider);
    await ref.read(dashboardProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final theme = Theme.of(context);

    return AsyncStateView(
      isLoading: dashboardAsync.isLoading,
      hasError: dashboardAsync.hasError,
      errorMessage: dashboardAsync.error?.toString(),
      onRetry: _refresh,
      loadingLabel: 'Setting up your dashboard...',
      child: dashboardAsync.value == null
          ? const SizedBox.shrink()
          : Container(
              color: theme.scaffoldBackgroundColor,
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: _DashboardLayout(data: dashboardAsync.value!),
              ),
            ),
    );
  }
}

class _DashboardLayout extends StatelessWidget {
  const _DashboardLayout({required this.data});

  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final isInstructor = data.user?.role == 'instructor' || data.user?.role == 'admin';

    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 100),
      children: [
        _buildHeader(context, isInstructor),
        const SizedBox(height: 32),
        _StatsGrid(stats: data.stats, isInstructor: isInstructor),
        const SizedBox(height: 40),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1000;
            return isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: _buildMainArea(context, isInstructor)),
                      const SizedBox(width: 40),
                      Expanded(flex: 1, child: _buildSidebarArea(context, isInstructor)),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMainArea(context, isInstructor),
                      const SizedBox(height: 40),
                      _buildSidebarArea(context, isInstructor),
                    ],
                  );
          },
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool isInstructor) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 700;
        final title = Text(
          isInstructor ? 'Instructor Console' : 'Student Lounge',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -1.2,
            color: isDark ? Colors.white : Colors.black,
          ),
          overflow: TextOverflow.ellipsis,
        );

        final subtitle = Text(
          isInstructor
              ? 'Manage your academy and track student progress'
              : 'Welcome back, ${data.user?.displayName ?? 'Student'}! Ready to learn?',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          maxLines: compact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
        );

        final action = isInstructor
            ? MinimalButton(
                width: compact ? double.infinity : 180,
                onPressed: () => context.pushNamed('create_course'),
                color: theme.colorScheme.primary,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: Colors.black),
                    SizedBox(width: 8),
                    Flexible(child: FittedBox(child: Text('Create Course', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)))),
                  ],
                ),
              )
            : MinimalButton(
                width: compact ? double.infinity : 180,
                color: theme.colorScheme.primary,
                onPressed: () => context.goNamed('courses'),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.explore_outlined, size: 20, color: Colors.black),
                    SizedBox(width: 4),
                    Flexible(child: FittedBox(child: Text('Explore Academy', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900)))),
                  ],
                ),
              );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 4),
              subtitle,
              const SizedBox(height: 16),
              action,
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title,
                  const SizedBox(height: 4),
                  subtitle,
                ],
              ),
            ),
            const SizedBox(width: 16),
            action,
          ],
        );
      },
    );
  }

  Widget _buildMainArea(BuildContext context, bool isInstructor) {
    if (isInstructor) {
      final myCourses = data.courses.where((c) => c.instructorId == data.user?.id).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          NetflixContentRow<CourseSummary>(
            title: 'Your Managed Courses',
            subtitle: 'Quick access to curriculum and students',
            items: myCourses,
            cardWidth: 220,
            height: 280,
            onSeeAll: () => context.goNamed('courses'),
            itemBuilder: (context, course, index) {
              return NetflixPosterCard(
                title: course.title,
                subtitle: '${course.lessonsCount} lessons • ${course.announcementsCount} updates',
                imageUrl: course.imageUrl,
                gradientColors: getCardGradient(course.title + course.id),
                showPlayButton: false,
                onTap: () => context.pushNamed('manage_course', pathParameters: {'id': course.id}),
              );
            },
          ),
          const SizedBox(height: 48),
          _AnnouncementsSection(announcements: data.announcements),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.enrollments.isNotEmpty) ...[
          NetflixContentRow<EnrollmentSummary>(
            title: 'Continue Learning',
            subtitle: 'Pick up exactly where you left off',
            items: data.enrollments,
            cardWidth: 260,
            height: 240,
            itemBuilder: (context, enrollment, index) {
              return NetflixPosterCard(
                title: enrollment.courseTitle,
                subtitle: 'Progress: ${enrollment.progressPercent.toStringAsFixed(0)}%',
                imageUrl: enrollment.imageUrl,
                gradientColors: getCardGradient(enrollment.courseTitle + enrollment.courseId),
                showPlayButton: true,
                bottomWidget: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(
                    value: enrollment.progressPercent / 100,
                    backgroundColor: Colors.white10,
                    color: AppColors.secondary,
                    minHeight: 2,
                  ),
                ),
                onTap: enrollment.courseId.isEmpty
                    ? null
                    : () => context.pushNamed(
                        'course_detail',
                        pathParameters: {'id': enrollment.courseId},
                      ),
              );
            },
          ),
          const SizedBox(height: 48),
        ],
        NetflixContentRow<CourseSummary>(
          title: 'Recommended for You',
          subtitle: 'New courses based on your education level',
          items: data.courses,
          cardWidth: 200,
          height: 260,
          onSeeAll: () => context.goNamed('courses'),
          itemBuilder: (context, course, index) {
            return NetflixPosterCard(
              title: course.title,
              subtitle: course.instructorName,
              imageUrl: course.imageUrl,
              gradientColors: getCardGradient(course.title + course.id),
              showPlayButton: !course.isEnrolled,
              onTap: () => context.pushNamed(
                'course_detail',
                pathParameters: {'id': course.id},
              ),
            );
          },
        ),
        const SizedBox(height: 48),
        _AnnouncementsSection(announcements: data.announcements),
      ],
    );
  }

  Widget _buildSidebarArea(BuildContext context, bool isInstructor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AIWidget(isInstructor: isInstructor, courses: data.courses, enrollments: data.enrollments),
        const SizedBox(height: 32),
        _DistributionWidget(stats: data.stats),
        if (isInstructor) ...[
          const SizedBox(height: 32),
          _InstructorActionsWidget(),
        ],
        const SizedBox(height: 32),
        _ScheduleWidget(schedule: data.schedule, isInstructor: isInstructor),
      ],
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats, required this.isInstructor});

  final DashboardStats? stats;
  final bool isInstructor;

  @override
  Widget build(BuildContext context) {
    if (stats == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 700 ? 2 : 1);

        final List<_StatCard> cards = isInstructor
            ? [
                _StatCard(
                  label: 'Courses Created',
                  value: '${stats!.coursesCreated}',
                  icon: Icons.auto_stories_rounded,
                  color: AppColors.cardLavender,
                ),
                _StatCard(
                  label: 'Active Students',
                  value: '${stats!.totalStudents}',
                  icon: Icons.people_alt_rounded,
                  color: AppColors.cardBlue,
                ),
                _StatCard(
                  label: 'Avg. Progress',
                  value: '${stats!.averageProgress.toStringAsFixed(0)}%',
                  icon: Icons.insights_rounded,
                  color: AppColors.cardPeach,
                ),
                _StatCard(
                  label: 'Unread Msgs',
                  value: '${stats!.unreadMessages}',
                  icon: Icons.forum_rounded,
                  color: AppColors.cardMint,
                ),
              ]
            : [
                _StatCard(
                  label: 'Enrolled',
                  value: '${stats!.enrolledCourses}',
                  icon: Icons.school_rounded,
                  color: AppColors.cardBlue,
                ),
                _StatCard(
                  label: 'Completed',
                  value: '${stats!.completedLessons}',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.cardMint,
                ),
                _StatCard(
                  label: 'Total Progress',
                  value: '${stats!.averageProgress.toStringAsFixed(0)}%',
                  icon: Icons.analytics_rounded,
                  color: AppColors.cardLavender,
                ),
                _StatCard(
                  label: 'Announcements',
                  value: '${stats!.totalAnnouncements}',
                  icon: Icons.campaign_rounded,
                  color: AppColors.cardAmber,
                ),
              ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isInstructor ? 'Academy Overview' : 'My Learning Path',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                MinimalContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  borderRadius: 10,
                  color: isDark ? theme.colorScheme.surfaceContainerHighest : AppColors.border,
                  child: Text(
                    '${cards.length}',
                    style: TextStyle(
                      fontSize: 12, 
                      fontWeight: FontWeight.w900,
                      color: isDark ? theme.colorScheme.onSurface : Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: cards.length,
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 320,
                mainAxisExtent: 190, 
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
              ),
              itemBuilder: (context, index) => cards[index],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MinimalContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 32,
      color: isDark ? theme.colorScheme.surfaceContainerHighest : color,
      showBorder: isDark, 
      showHighlighter: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: isDark ? theme.colorScheme.primary : Colors.black87, size: 20),
              ),
              Icon(Icons.more_horiz, color: isDark ? Colors.white24 : Colors.black26, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? theme.colorScheme.onSurfaceVariant : Colors.black54,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: isDark ? theme.colorScheme.onSurface : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AIWidget extends StatelessWidget {
  const _AIWidget({required this.isInstructor, required this.courses, required this.enrollments});

  final bool isInstructor;
  final List<CourseSummary> courses;
  final List<EnrollmentSummary> enrollments;

  void _launchAI(BuildContext context) {
    final List<Map<String, String>> selectableCourses = isInstructor
        ? courses.map((c) => {'id': c.id, 'title': c.title}).toList()
        : enrollments.map((e) => {'id': e.courseId, 'title': e.courseTitle}).toList();

    if (selectableCourses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isInstructor
                ? "You haven't created any courses yet."
                : 'Enroll in a course first to use the AI Study Buddy!',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isInstructor ? 'Select Course for Insights' : 'Select Course to Study'),
        content: SizedBox(
          width: 400,
          height: 300, 
          child: ListView.builder(
            itemCount: selectableCourses.length,
            itemBuilder: (context, index) {
              final c = selectableCourses[index];
              return ListTile(
                leading: const Icon(Icons.psychology_outlined, color: AppColors.primary),
                title: Text(c['title']!),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () {
                  ctx.pop();
                  context.pushNamed(
                    'course_ai',
                    pathParameters: {'id': c['id']!},
                    extra: c['title'],
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = isInstructor ? AppColors.primary : AppColors.secondary;

    return DashboardWidgetContainer(
      title: isInstructor ? 'AI Teaching Assistant' : 'AI Study Buddy',
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded, color: accentColor, size: 40),
          const SizedBox(height: 16),
          Text(
            isInstructor ? 'Academy Insights' : 'Personal Tutor',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            isInstructor
                ? 'Identify at-risk students or generate quiz ideas.'
                : 'Ask questions about your courses or get instant summaries.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          MinimalButton(
            onPressed: () => _launchAI(context),
            color: accentColor,
            child: Text(isInstructor ? 'Open Assistant' : 'Ask Buddy'),
          ),
        ],
      ),
    );
  }
}

class _DistributionWidget extends StatelessWidget {
  const _DistributionWidget({required this.stats});

  final DashboardStats? stats;

  @override
  Widget build(BuildContext context) {
    if (stats == null || stats!.coursesByLevel.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return MinimalContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Distribution', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Courses by education level', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ...stats!.coursesByLevel.entries.map((e) {
            final double percentage = stats!.enrolledCourses > 0 ? (e.value / stats!.enrolledCourses) : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          e.key.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${e.value}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 6,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InstructorActionsWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(enrollmentRequestsProvider);
    
    return DashboardWidgetContainer(
      title: 'Action Items',
      child: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('You are all caught up!', style: TextStyle(color: Colors.grey)),
            );
          }
          return Column(
            children: requests.take(3).map((r) => _ActionItem(
              title: '${r.studentName} wants to join ${r.courseTitle}',
              subtitle: 'Pending approval',
              icon: Icons.person_add_rounded,
            )).toList(),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: CircularProgressIndicator(),
        ),
        error: (_, __) => const Text('Failed to load action items'),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  const _ActionItem({required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.orange, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleWidget extends ConsumerWidget {
  const _ScheduleWidget({required this.schedule, required this.isInstructor});

  final List<ScheduleItemModel> schedule;
  final bool isInstructor;

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    final timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Schedule Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Live Q&A Session'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(labelText: 'Time', hintText: 'e.g. 10:00 AM'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty || timeController.text.trim().isEmpty) return;
              try {
                await ref.read(homeRepositoryProvider).createScheduleItem(
                  titleController.text.trim(),
                  timeController.text.trim(),
                );
                ref.invalidate(dashboardProvider);
                if (ctx.mounted) ctx.pop();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DashboardWidgetContainer(
      title: 'Upcoming Schedule',
      trailing: isInstructor
          ? IconButton(
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: () => _showAddDialog(context, ref),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          : null,
      child: schedule.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('No upcoming schedule', style: TextStyle(color: Colors.grey))),
            )
          : Column(
              children: schedule.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 2,
                      height: 32,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.timeStr, style: const TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold)),
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                    if (isInstructor)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey),
                        onPressed: () async {
                           try {
                             await ref.read(homeRepositoryProvider).deleteScheduleItem(item.id);
                             ref.invalidate(dashboardProvider);
                           } catch (e) {
                             if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                           }
                        },
                      ),
                  ],
                ),
              )).toList(),
            ),
    );
  }
}

class _AnnouncementsSection extends StatelessWidget {
  const _AnnouncementsSection({required this.announcements});

  final List<AnnouncementItem> announcements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MinimalContainer(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Latest Updates', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              const Icon(Icons.campaign_outlined, color: AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 24),
          if (announcements.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No updates yet', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < announcements.take(3).length; i++) ...[
                  _AnnouncementItem(announcement: announcements[i]),
                  if (i < announcements.take(3).length - 1)
                    const Divider(height: 32, color: AppColors.border),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AnnouncementItem extends StatelessWidget {
  const _AnnouncementItem({required this.announcement});
  final AnnouncementItem announcement;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                announcement.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                '${announcement.courseTitle} • ${announcement.authorName}',
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
        Text(
          announcement.createdAt != null ? '${announcement.createdAt!.day}/${announcement.createdAt!.month}' : '',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
