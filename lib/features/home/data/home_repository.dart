import 'package:dio/dio.dart';

import 'home_api_client.dart';
import 'home_models.dart';

class HomeRepository {
  HomeRepository(this._dio);

  final Dio _dio;

  Future<dynamic> _getFirst(
    List<String> paths, {
    Map<String, dynamic>? queryParameters,
  }) async {
    Object? lastError;
    for (final path in paths) {
      try {
        final response = await _dio.get<dynamic>(
          path, 
          queryParameters: queryParameters,
        );
        if (response.statusCode == 200 && response.data != null) {
          return response.data;
        }
      } on DioException catch (error) {
        lastError = error;
        // If not found or method not allowed, try the next path.
        if (error.response?.statusCode == 404 ||
            error.response?.statusCode == 405) {
          continue;
        }
        rethrow;
      }
    }
    if (lastError is Exception) {
      throw lastError;
    }
    throw Exception(
      'Unable to load data for any endpoint: ${paths.join(', ')}',
    );
  }

  Future<List<CourseSummary>> fetchCourses({String? search, String? eduLevel}) async {
    final queryParameters = <String, dynamic>{};
    if (search != null && search.isNotEmpty) queryParameters['search'] = search;
    if (eduLevel != null && eduLevel.isNotEmpty) queryParameters['edu_level'] = eduLevel;

    final data = await _getFirst(const <String>['courses'], queryParameters: queryParameters);
    return asJsonList(data).map(CourseSummary.fromJson).toList();
  }

  Future<List<EnrollmentSummary>> fetchPendingRequests() async {
    final data = await _getFirst(const <String>['enrollments/requests/pending']);
    return asJsonList(data).map(EnrollmentSummary.fromJson).toList();
  }

  Future<CourseDetailData> fetchCourseDetail(String courseId) async {
    final id = courseId.trim();
    if (id.isEmpty || id == 'create' || id == 'null' || id == 'undefined') {
      throw Exception('Invalid course ID: "$courseId"');
    }

    try {
      final data = await _getFirst(<String>['courses/$id']);
      final course = asJsonMap(data);
      return CourseDetailData.fromJson(course);
    } catch (e) {
      throw Exception('Failed to load course details: $e');
    }
  }

  Future<List<AnnouncementItem>> fetchAnnouncements() async {
    final data = await _getFirst(const <String>['announcements']);
    return asJsonList(data).map(AnnouncementItem.fromJson).toList();
  }

  Future<List<EnrollmentSummary>> fetchEnrollments() async {
    // Backend only has GET /api/v1/enrollments/me and GET /api/v1/enrollments/{id}
    final data = await _getFirst(const <String>['enrollments/me']);
    return asJsonList(data).map(EnrollmentSummary.fromJson).toList();
  }

  Future<AppUser?> fetchProfile() async {
    final data = await _getFirst(const <String>['users/me']);

    final json = asJsonMap(data);
    return AppUser.fromJson(json);
  }

  Future<DashboardStats?> fetchStats() async {
    // Backend only has GET /api/v1/stats/me
    final data = await _getFirst(const <String>['stats/me']);
    final json = asJsonMap(data);
    return DashboardStats.fromJson(json);
  }

  Future<void> joinCourse(String courseId) async {
    try {
      await _dio.post(
        'enrollments/',
        data: <String, dynamic>{'course_id': courseId},
      );
    } on DioException catch (e) {
      throw Exception(e.response?.data?['detail'] ?? 'Failed to request enrollment');
    }
  }

  Future<void> joinCourseByCode(String joinCode) async {
    final formData = FormData.fromMap({'join_code': joinCode});
    try {
      await _dio.post('enrollments/join', data: formData);
    } on DioException catch (e) {
       throw Exception(e.response?.data?['detail'] ?? 'Invalid join code or session expired');
    }
  }

  Future<DashboardData> fetchDashboard() async {
    final data = await _getFirst(const <String>['stats/dashboard']);
    final json = asJsonMap(data);
    
    final userJson = asJsonMap(json['user'] ?? {});
    final statsJson = asJsonMap(json['stats'] ?? {});
    final coursesJson = asJsonList(json['courses'] ?? []);
    final announcementsJson = asJsonList(json['announcements'] ?? []);
    final enrollmentsJson = asJsonList(json['enrollments'] ?? []);
    final scheduleJson = asJsonList(json['schedule'] ?? []);

    return DashboardData(
      user: AppUser.fromJson(userJson),
      stats: DashboardStats.fromJson(statsJson),
      courses: coursesJson.map(CourseSummary.fromJson).toList(),
      announcements: announcementsJson.map(AnnouncementItem.fromJson).toList(),
      enrollments: enrollmentsJson.map(EnrollmentSummary.fromJson).toList(),
      schedule: scheduleJson.map(ScheduleItemModel.fromJson).toList(),
    );
  }

  Future<void> createScheduleItem(String title, String timeStr) async {
    final response = await _dio.post(
      'schedule/',
      data: <String, dynamic>{'title': title, 'time_str': timeStr},
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(response.data?['detail'] ?? 'Failed to create schedule item');
    }
  }

  Future<void> deleteScheduleItem(String id) async {
    final response = await _dio.delete('schedule/$id');
    if (response.statusCode != 200) {
      throw Exception(response.data?['detail'] ?? 'Failed to delete schedule item');
    }
  }

  Future<CourseDetailData> fetchJoinedCourseOrDetail(String courseId) {
    return fetchCourseDetail(courseId);
  }
}
