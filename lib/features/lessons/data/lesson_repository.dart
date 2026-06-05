import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/dio_client.dart';
import '../../../data/json_parsing.dart';
import '../../courses/domain/lesson_model.dart';

final lessonRepositoryProvider = Provider<LessonRepository>((ref) {
  return LessonRepository(ref.watch(dioClientProvider));
});

class LessonRepository {
  final Dio _dio;

  const LessonRepository(this._dio);

  Future<LessonModel> getLesson(String id) async {
    final response = await _dio.get<dynamic>('lessons/$id');
    return LessonModel.fromJson(response.data);
  }

  Future<bool> completeLesson(String lessonId) async {
    final response = await _dio.post<dynamic>('lessons/$lessonId/complete');
    return response.data['is_completed'] == true;
  }

  Future<bool> uncompleteLesson(String lessonId) async {
    final response = await _dio.delete<dynamic>('lessons/$lessonId/complete');
    return response.data['is_completed'] == false;
  }

  Future<Map<String, bool>> getCourseProgress(String courseId) async {
    final response = await _dio.get<dynamic>('lessons/course/$courseId/progress');
    final list = asJsonMapList(response.data);
    return {
      for (final item in list)
        readString(item, const ['lesson_id', 'lessonId']) ?? '':
          readBool(item, const ['is_completed', 'isCompleted']) ?? false,
    };
  }

  Future<Map<String, dynamic>> getQuizContent(String lessonId) async {
    final response = await _dio.get<dynamic>('lessons/$lessonId/questions');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitQuiz(String lessonId, List<int> answers) async {
    final response = await _dio.post<dynamic>(
      'lessons/$lessonId/submit',
      data: {'answers': answers},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> uploadFile(String lessonId, String filePath, String fileName) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    await _dio.post<dynamic>('lessons/$lessonId/upload-file', data: formData);
  }

  String handleError(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map) {
      final detail = responseData['detail'];
      if (detail != null) return detail.toString();
      final message = responseData['message'];
      if (message != null) return message.toString();
      return responseData.toString();
    }
    return error.message ?? 'An unknown error occurred';
  }
}
