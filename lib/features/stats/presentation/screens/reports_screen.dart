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

    return MinimalContainer(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COURSE REPORT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: theme.colorScheme.primary, letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(report.courseTitle, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              MinimalContainer(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                borderRadius: 12,
                color: theme.colorScheme.primary.withValues(alpha: 0.05),
                showBorder: false,
                child: Column(
                  children: [
                    Text('${report.studentCount}', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary, fontSize: 18)),
                    Text('STUDENTS', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // AI Insight Box
          MinimalContainer(
            padding: const EdgeInsets.all(16),
            borderRadius: 16,
            color: theme.colorScheme.secondary.withValues(alpha: 0.05),
            showBorder: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome_rounded, color: theme.colorScheme.secondary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI INSIGHT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.secondary)),
                      const SizedBox(height: 4),
                      Text(report.aiInsight, style: const TextStyle(fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Text('Student Progress Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 16),
          
          ...report.students.take(3).map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s.studentName, style: const TextStyle(fontSize: 13)),
                    Text('${s.progress.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: s.progress / 100,
                    minHeight: 4,
                    backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.2),
                    color: s.progress > 70 ? AppColors.success : (s.progress > 30 ? AppColors.orange : AppColors.danger),
                  ),
                ),
              ],
            ),
          )),
          
          if (report.students.length > 3)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: TextButton(
                  onPressed: () => context.pushNamed(
                    'course_report_students',
                    pathParameters: {'courseId': report.courseId},
                    extra: {
                      'title': report.courseTitle,
                      'students': report.students,
                    },
                  ),
                  child: Text('View all ${report.studentCount} students', style: const TextStyle(fontSize: 12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
