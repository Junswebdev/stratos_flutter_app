import 'package:flutter/material.dart';
import 'package:stratos_app/core/theme.dart';
import 'reports_screen.dart';

class StudentListScreen extends StatelessWidget {
  const StudentListScreen({
    super.key,
    required this.courseTitle,
    required this.students,
  });

  final String courseTitle;
  final List<StudentProgress> students;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Students: $courseTitle"),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final s = students[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                        child: Text(s.studentName[0].toUpperCase(), style: const TextStyle(color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(s.email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                      Text(
                        "${s.progress.toStringAsFixed(0)}%",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Course Completion", style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.progress / 100,
                      minHeight: 8,
                      backgroundColor: AppColors.border,
                      color: s.progress > 70 ? AppColors.success : (s.progress > 30 ? AppColors.orange : AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
