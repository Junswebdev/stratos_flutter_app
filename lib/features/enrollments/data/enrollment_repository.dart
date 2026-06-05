import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/dio_client.dart';
import '../../../data/json_parsing.dart';
import '../domain/enrollment_model.dart';

import 'package:stratos_app/features/auth/presentation/controllers/auth_controller.dart';

final enrollmentRepositoryProvider = Provider<EnrollmentRepository>((ref) {
  // Watch auth state to ensure repository is recreated on logout/login
  ref.watch(authControllerProvider);
  return EnrollmentRepository(ref.watch(dioClientProvider));
});

class EnrollmentRepository {
  final Dio _dio;

  const EnrollmentRepository(this._dio);

  Future<List<EnrollmentModel>> getMyEnrollments({
    int skip = 0,
    int limit = 100,
  }) async {
    final response = await _dio.get<dynamic>(
      'enrollments/me',
      queryParameters: <String, dynamic>{
        'skip': skip,
        'limit': limit,
      },
    );
    return asJsonMapList(response.data).map(EnrollmentModel.fromJson).toList();
  }

  Future<EnrollmentModel?> getEnrollmentById(String id) async {
    final response = await _dio.get<dynamic>('enrollments/$id');
    if (response.data == null) {
      return null;
    }
    return EnrollmentModel.fromJson(response.data);
  }

  Future<EnrollmentJoinResult> joinCourse(String joinCode) async {
    final response = await _dio.post<dynamic>(
      'enrollments/join/$joinCode',
      data: <String, dynamic>{},
    );
    return EnrollmentJoinResult.fromJson(response.data);
  }

  Future<EnrollmentModel?> enrollInCourse(String courseId) async {
    final response = await _dio.post<dynamic>(
      'enrollments/',
      data: <String, dynamic>{
        'course_id': courseId,
      },
    );
    if (response.data == null) {
      return null;
    }
    return EnrollmentModel.fromJson(response.data);
  }
}
