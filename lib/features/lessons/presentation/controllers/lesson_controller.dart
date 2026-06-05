import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/lesson_repository.dart';
import '../../../courses/domain/lesson_model.dart';

final lessonDetailProvider = FutureProvider.family<LessonModel, String>((ref, lessonId) {
  return ref.watch(lessonRepositoryProvider).getLesson(lessonId);
});

final courseProgressProvider = FutureProvider.family<Map<String, bool>, String>((ref, courseId) {
  return ref.watch(lessonRepositoryProvider).getCourseProgress(courseId);
});
