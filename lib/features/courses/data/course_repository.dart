import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http_parser/http_parser.dart';

import '../../../data/dio_client.dart';
import '../../../data/json_parsing.dart';
import '../domain/course_model.dart';
import '../domain/lesson_model.dart';
import '../domain/quiz_model.dart';
import '../../auth/domain/user_model.dart';

final courseRepositoryProvider = Provider<CourseRepository>((ref) {
  return CourseRepository(
    ref.watch(dioClientProvider),
    ref.watch(secureStorageProvider),
  );
});

class CourseRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  const CourseRepository(this._dio, this._storage);

  Future<List<CourseModel>> getCourses({
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get<dynamic>(
      'courses',
      queryParameters: <String, dynamic>{
        'skip': skip,
        'limit': limit,
      },
    );

    return asJsonMapList(response.data).map(CourseModel.fromJson).toList(growable: false);
  }

  Future<CourseModel?> getCourseById(String id) async {
    final response = await _dio.get<dynamic>('courses/$id');
    if (response.data == null) {
      return null;
    }
    return CourseModel.fromJson(response.data);
  }

  Future<List<LessonModel>> getLessonsByCourseId(
    String courseId, {
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get<dynamic>(
      'lessons',
      queryParameters: <String, dynamic>{
        'course_id': courseId,
        'skip': skip,
        'limit': limit,
      },
    );

    final parsed = asJsonMapList(response.data);
    if (parsed.isNotEmpty) {
      return parsed.map(LessonModel.fromJson).toList(growable: false);
    }

    final fallback = await _dio.get<dynamic>(
      'courses/$courseId/lessons',
      queryParameters: <String, dynamic>{
        'skip': skip,
        'limit': limit,
      },
    );

    return asJsonMapList(fallback.data).map(LessonModel.fromJson).toList(growable: false);
  }

  Future<LessonModel?> getLessonById(String id) async {
    final response = await _dio.get<dynamic>('lessons/$id');
    if (response.data == null) {
      return null;
    }
    return LessonModel.fromJson(response.data);
  }

  Future<CourseModel> createCourse({
    required String title,
    String? description,
    EduLevel eduLevel = EduLevel.higherEd,
    required String instructorId,
    String? imageUrl,
  }) async {
    final Map<String, dynamic> data = {
      'title': title,
      'description': description ?? '',
      'edu_level': eduLevel.toJson(),
      'instructor_id': instructorId,
    };

    if (imageUrl != null && imageUrl.isNotEmpty) {
      data['image_url_input'] = imageUrl;
    }

    final formData = FormData.fromMap(data);

    final response = await _dio.post<dynamic>(
      'courses',
      data: formData,
    );
    return CourseModel.fromJson(response.data);
  }

  Future<CourseModel> updateCourse(
    String courseId, {
    String? title,
    String? description,
    EduLevel? eduLevel,
    String? imageUrl,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (eduLevel != null) data['edu_level'] = eduLevel.toJson();
    if (imageUrl != null && imageUrl.isNotEmpty) data['image_url_input'] = imageUrl;

    final formData = FormData.fromMap(data);

    final response = await _dio.patch<dynamic>('courses/$courseId', data: formData);
    return CourseModel.fromJson(response.data);
  }

  Future<void> deleteCourse(String courseId) async {
    await _dio.delete<dynamic>('courses/$courseId');
  }

  Future<ModuleModel> createModule({
    required String courseId,
    required String title,
    String? description,
    int order = 0,
  }) async {
    final response = await _dio.post<dynamic>(
      'courses/$courseId/modules',
      data: {
        'course_id': courseId,
        'title': title,
        'description': description ?? '',
        'order': order,
      },
    );
    return ModuleModel.fromJson(response.data);
  }

  Future<ModuleModel> updateModule(
    String moduleId, {
    String? title,
    String? description,
    int? order,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (order != null) data['order'] = order;
    final response = await _dio.patch<dynamic>('courses/modules/$moduleId', data: data);
    return ModuleModel.fromJson(response.data);
  }

  Future<void> deleteModule(String moduleId) async {
    await _dio.delete<dynamic>('courses/modules/$moduleId');
  }

  Future<LessonModel> createLesson({
    required String moduleId,
    required String title,
    String? content,
    String? videoUrl,
    String? attachmentUrl,
    String? contentType,
    int order = 0,
    bool isPreview = false,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final Map<String, dynamic> data = {
      'module_id': moduleId,
      'title': title,
      'content_type': contentType ?? 'text',
      'order': order.toString(),
      'is_preview': isPreview.toString(),
    };
    
    if (content != null && content.isNotEmpty) data['content_data'] = content;
    if (videoUrl != null && videoUrl.isNotEmpty) data['content_data'] = videoUrl;

    if (fileBytes != null && fileName != null) {
      data['file'] = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: _getMediaType(fileName),
      );
    }

    final formData = FormData.fromMap(data);

    try {
      final token = await _storage.read(key: accessTokenStorageKey);
      final options = Options(
        headers: {
          if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        },
      );

      final response = await _dio.post<dynamic>(
        'lessons', 
        data: formData,
        options: options,
      );
      return LessonModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<LessonModel> updateLesson(
    String lessonId, {
    String? title,
    String? contentData,
    String? videoUrl,
    int? order,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    final Map<String, dynamic> data = {};
    if (title != null) data['title'] = title;
    if (contentData != null) data['content_data'] = contentData;
    if (videoUrl != null) data['content_data'] = videoUrl;
    if (order != null) data['order'] = order.toString();

    if (fileBytes != null && fileName != null) {
      data['file'] = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: _getMediaType(fileName),
      );
    }

    final formData = FormData.fromMap(data);

    final response = await _dio.patch<dynamic>('lessons/$lessonId', data: formData);
    return LessonModel.fromJson(response.data);
  }

  Future<void> deleteLesson(String lessonId) async {
    await _dio.delete<dynamic>('lessons/$lessonId');
  }

  Future<void> createAnnouncement({
    required String courseId,
    required String title,
    required String content,
    DateTime? expiresAt,
  }) async {
    await _dio.post<dynamic>(
      'announcements',
      data: {
        'course_id': courseId,
        'title': title,
        'content': content,
        if (expiresAt != null) 'expires_at': expiresAt.toUtc().toIso8601String(),
      },
    );
  }

  Future<String> askAI({
    required String courseId,
    required String question,
  }) async {
    final response = await _dio.post<dynamic>(
      'ai/ask',
      data: {
        'course_id': courseId,
        'question': question,
      },
    );
    return response.data['answer'] as String;
  }

  // --- Quiz Methods ---

  Future<QuizModel?> getQuizById(String quizId) async {
    final response = await _dio.get<dynamic>('quiz/$quizId');
    if (response.data == null) return null;
    return QuizModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<QuizModel?> getQuizForLesson(String lessonId) async {
    try {
      final response = await _dio.get<dynamic>('quiz/lesson/$lessonId');
      if (response.data == null) return null;
      return QuizModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  Future<QuizModel> generateAIQuiz(String lessonId, {int numQuestions = 5}) async {
    final response = await _dio.post<dynamic>(
      'quiz/generate',
      data: {'lesson_id': lessonId, 'num_questions': numQuestions},
    );
    return QuizModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<QuizModel> createManualQuiz({
    required String lessonId,
    required String title,
    String? description,
    required List<QuizQuestionModel> questions,
  }) async {
    final response = await _dio.post<dynamic>(
      'quiz',
      data: {
        'lesson_id': lessonId,
        'title': title,
        'description': description,
        'questions': questions.map((q) => q.toJson()).toList(),
      },
    );
    return QuizModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<QuizAttemptModel> submitQuizAttempt({
    required String quizId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final response = await _dio.post<dynamic>(
      'quiz/submit',
      data: {'quiz_id': quizId, 'answers': answers},
    );
    return QuizAttemptModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<QuizAttemptModel>> getMyAttempts(String quizId) async {
    final response = await _dio.get<dynamic>('quiz/attempts/$quizId/me');
    return asJsonMapList(response.data).map(QuizAttemptModel.fromJson).toList();
  }

  Future<List<QuizAttemptModel>> getAllQuizAttempts(String quizId) async {
    final response = await _dio.get<dynamic>('quiz/$quizId/attempts');
    return asJsonMapList(response.data).map(QuizAttemptModel.fromJson).toList();
  }

  Future<void> gradeQuizAttempt({
    required String attemptId,
    required double score,
    String? feedback,
  }) async {
    await _dio.patch<dynamic>(
      'quiz/attempts/$attemptId/grade',
      data: {
        'score': score,
        'instructor_feedback': feedback,
      },
    );
  }

  MediaType _getMediaType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return MediaType('application', 'pdf');
      case 'png':
        return MediaType('image', 'png');
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'mp4':
        return MediaType('video', 'mp4');
      case 'doc':
      case 'docx':
        return MediaType('application', 'msword');
      default:
        return MediaType('application', 'octet-stream');
    }
  }

  String handleError(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map) {
      final detail = responseData['detail'];
      if (detail != null) {
        return detail.toString();
      }
      final message = responseData['message'];
      if (message != null) {
        return message.toString();
      }
      return responseData.toString();
    }
    return error.message ?? 'An unknown error occurred';
  }
}
