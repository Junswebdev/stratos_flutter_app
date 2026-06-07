import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stratos_app/data/dio_client.dart';
import 'package:stratos_app/core/theme.dart';
import 'package:stratos_app/core/widgets/minimalist_widgets.dart';

class CourseReport {
  final String courseId;
  final String courseTitle;
  final int studentCount;
  final double averageProgress;
  final String aiInsight;
  final List<StudentProgress> students;

  CourseReport({
    required this.courseId,
    required this.courseTitle,
    required this.studentCount,
    required this.averageProgress,
    required this.aiInsight,
    required this.students,
  });

  factory CourseReport.fromJson(Map<String, dynamic> json) {
    return CourseReport(
      courseId: json['course_id'],
      courseTitle: json['course_title'],
      studentCount: json['student_count'],
      averageProgress: (json['average_progress'] as num).toDouble(),
      aiInsight: json['ai_insight'],
      students: (json['students'] as List).map((s) => StudentProgress.fromJson(s as Map<String, dynamic>)).toList(),
    );
  }
}

class StudentProgress {
  final String studentName;
  final String email;
  final double progress;

  StudentProgress({required this.studentName, required this.email, required this.progress});

  factory StudentProgress.fromJson(Map<String, dynamic> json) {
    return StudentProgress(
      studentName: json['student_name'],
      email: json['email'],
      progress: (json['progress'] as num).toDouble(),
    );
  }
}

final instructorReportsProvider = FutureProvider<List<CourseReport>>((ref) async {
  final dio = ref.watch(dioClientProvider);
  final response = await dio.get<dynamic>('stats/instructor/reports');
  return (response.data as List).map((r) => CourseReport.fromJson(r as Map<String, dynamic>)).toList();
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(instructorReportsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Academic Reports'),
      ),
      body: reportsAsync.when(
        data: (reports) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(instructorReportsProvider),
          child: reports.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    return _CourseReportCard(report: report, isDark: isDark);
                  },
                ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text("No reports available for your courses", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _CourseReportCard extends StatelessWidget {
  const _CourseReportCard({required this.report, required this.isDark});
  final CourseReport report;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACADEMIC REPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(report.courseTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('${report.studentCount}', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 18)),
                    const Text('STUDENTS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // AI Insight Box - Minimalist Gold
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 16),
                    SizedBox(width: 8),
                    Text('AI Performance Insights', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  report.aiInsight, 
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6, 
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurface,
                  )
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          const Text('Student Progress', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 20),
          
          ...report.students.take(3).map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s.studentName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${s.progress.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.primary)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: s.progress / 100,
                    minHeight: 4,
                    backgroundColor: isDark ? Colors.white10 : AppColors.border,
                    color: s.progress > 80 ? AppColors.success : (s.progress > 40 ? AppColors.primary : AppColors.danger),
                  ),
                ),
              ],
            ),
          )),
          
          if (report.students.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: MinimalButton(
                height: 40,
                onPressed: () => context.pushNamed(
                  'course_report_students',
                  pathParameters: {'courseId': report.courseId},
                  extra: {
                    'title': report.courseTitle,
                    'students': report.students,
                  },
                ),
                child: Text('View All Students (${report.studentCount})', style: const TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}
