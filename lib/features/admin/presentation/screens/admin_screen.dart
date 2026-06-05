import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/dio_client.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../courses/data/course_repository.dart';
import '../../../courses/domain/course_model.dart';

final _adminUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.watch(dioClientProvider);
  final response = await dio.get<dynamic>('users', queryParameters: {'skip': 0, 'limit': 100});
  final data = response.data;
  if (data is List) {
    return data.cast<Map<String, dynamic>>();
  }
  if (data is Map && data['items'] is List) {
    return (data['items'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final _adminCoursesProvider = FutureProvider<List<CourseModel>>((ref) async {
  final repo = ref.read(courseRepositoryProvider);
  return repo.getCourses(skip: 0, limit: 100);
});

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_adminUsersProvider);
    final coursesAsync = ref.watch(_adminCoursesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Users', icon: Icon(Icons.people)),
              Tab(text: 'Courses', icon: Icon(Icons.menu_book)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUsersList(context, ref, usersAsync),
            _buildCoursesList(context, ref, coursesAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildUsersList(BuildContext context, WidgetRef ref, AsyncValue<List<Map<String, dynamic>>> usersAsync) {
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (users) => users.isEmpty
          ? const Center(child: Text('No users found'))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(_adminUsersProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: users.length,
                itemBuilder: (ctx, i) {
                  final user = users[i];
                  final email = user['email']?.toString() ?? '';
                  final name = user['full_name']?.toString() ?? 'Unnamed';
                  final role = user['role']?.toString() ?? '';
                  final isActive = user['is_active'] == true;
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(name[0].toUpperCase())),
                      title: Text(name),
                      subtitle: Text('$email • $role'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isActive ? Icons.check_circle : Icons.cancel,
                            color: isActive ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                      onTap: () => _showUserDetails(context, ref, user),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildCoursesList(BuildContext context, WidgetRef ref, AsyncValue<List<CourseModel>> coursesAsync) {
    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (courses) => courses.isEmpty
          ? const Center(child: Text('No courses found'))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(_adminCoursesProvider),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: courses.length,
                itemBuilder: (ctx, i) {
                  final course = courses[i];
                  return Card(
                    child: ListTile(
                      title: Text(course.title),
                      subtitle: Text('${course.allLessons.length} lessons • ${course.joinCode}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.pushNamed(
                        'course_detail',
                        pathParameters: {'id': course.id},
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _showUserDetails(BuildContext context, WidgetRef ref, Map<String, dynamic> user) {
    final id = user['id']?.toString() ?? '';
    final isActive = user['is_active'] == true;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user['full_name']?.toString() ?? 'User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${user['email']}'),
            Text('Role: ${user['role']}'),
            Text('Active: $isActive'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: isActive
                ? null
                : () async {
                    try {
                      final dio = ref.read(dioClientProvider);
                      await dio.patch<dynamic>('users/$id', data: {'is_active': true});
                      ref.invalidate(_adminUsersProvider);
                      if (ctx.mounted) ctx.pop();
                    } catch (_) {}
                  },
            child: const Text('Activate'),
          ),
          TextButton(
            onPressed: isActive
                ? () async {
                    try {
                      final dio = ref.read(dioClientProvider);
                      await dio.patch<dynamic>('users/$id', data: {'is_active': false});
                      ref.invalidate(_adminUsersProvider);
                      if (ctx.mounted) ctx.pop();
                    } catch (_) {}
                  }
                : null,
            child: Text('Deactivate', style: TextStyle(color: isActive ? Colors.orange : null)),
          ),
          TextButton(
            onPressed: () async {
              try {
                final dio = ref.read(dioClientProvider);
                await dio.delete<dynamic>('users/$id');
                ref.invalidate(_adminUsersProvider);
                if (ctx.mounted) ctx.pop();
              } catch (_) {}
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
          TextButton(onPressed: () => ctx.pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
