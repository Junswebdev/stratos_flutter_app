import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/course_model.dart';
import '../../data/course_repository.dart';

// Provider to fetch the list of courses
final coursesProvider = FutureProvider.autoDispose<List<CourseModel>>((ref) async {
  final repository = ref.watch(courseRepositoryProvider);
  return await repository.getCourses();
});

// Provider family to fetch a specific course by ID
final courseDetailProvider = FutureProvider.family.autoDispose<CourseModel?, String>((ref, id) async {
  final repository = ref.watch(courseRepositoryProvider);
  return await repository.getCourseById(id);
});
