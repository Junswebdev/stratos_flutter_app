import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:stratos_app/features/auth/presentation/controllers/auth_controller.dart';

import '../data/home_api_client.dart';
import '../data/home_models.dart';
import '../data/home_repository.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  // Watch auth state to ensure repository (and its dependents) are recreated on logout/login
  ref.watch(authControllerProvider);
  final dio = ref.watch(apiDioProvider);
  return HomeRepository(dio);
});

final dashboardProvider = FutureProvider<DashboardData>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading || authState.value?.isAuthenticated != true) {
    return const DashboardData(
      user: null,
      stats: null,
      courses: [],
      announcements: [],
      enrollments: [],
      schedule: [],
    );
  }

  final repository = ref.watch(homeRepositoryProvider);
  return repository.fetchDashboard();
});

final profileProvider = FutureProvider<AppUser?>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading || authState.value?.isAuthenticated != true) return null;

  final repository = ref.watch(homeRepositoryProvider);
  return repository.fetchProfile();
});

class StatsNotifier extends AsyncNotifier<DashboardStats?> {
  @override
  Future<DashboardStats?> build() async {
    final authState = ref.watch(authControllerProvider);
    if (authState.isLoading || authState.value?.isAuthenticated != true) return null;

    final repository = ref.watch(homeRepositoryProvider);
    return repository.fetchStats();
  }

  void updateStats(DashboardStats stats) {
    state = AsyncData(stats);
  }
}

final statsProvider = AsyncNotifierProvider<StatsNotifier, DashboardStats?>(() {
  return StatsNotifier();
});

final coursesProvider = FutureProvider<List<CourseSummary>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading || authState.value?.isAuthenticated != true) return const [];

  final repository = ref.watch(homeRepositoryProvider);
  return repository.fetchCourses();
});

// Providers for the Browse page
class CourseSearchQuery extends Notifier<String> {
  @override
  String build() => "";
  void update(String value) => state = value;
}

class CourseCategoryFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? value) => state = value;
}

final courseSearchQueryProvider = NotifierProvider<CourseSearchQuery, String>(() {
  return CourseSearchQuery();
});

final courseCategoryFilterProvider = NotifierProvider<CourseCategoryFilter, String?>(() {
  return CourseCategoryFilter();
});

final browseCoursesProvider = FutureProvider<List<CourseSummary>>((ref) async {
  final search = ref.watch(courseSearchQueryProvider);
  final category = ref.watch(courseCategoryFilterProvider);
  
  final repository = ref.watch(homeRepositoryProvider);
  return repository.fetchCourses(search: search, eduLevel: category);
});

final enrollmentRequestsProvider = FutureProvider<List<EnrollmentSummary>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading || authState.value?.isAuthenticated != true) return const [];
  
  final repository = ref.watch(homeRepositoryProvider);
  return repository.fetchPendingRequests();
});

final announcementsProvider = FutureProvider<List<AnnouncementItem>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading || authState.value?.isAuthenticated != true) return const [];

  final repository = ref.watch(homeRepositoryProvider);
  return repository.fetchAnnouncements();
});

final enrollmentsProvider = FutureProvider<List<EnrollmentSummary>>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.isLoading || authState.value?.isAuthenticated != true) return const [];

  final repository = ref.watch(homeRepositoryProvider);
  return repository.fetchEnrollments();
});

final courseDetailProvider =
    FutureProvider.family<CourseDetailData, String>((ref, courseId) async {
  if (courseId == 'create') {
    throw Exception('Reserved keyword "create" cannot be used as a course ID');
  }
  final repository = ref.watch(homeRepositoryProvider);
  return repository.fetchJoinedCourseOrDetail(courseId);
});

class SystemStatus {
  const SystemStatus({
    required this.isHealthy,
    required this.message,
  });

  final bool isHealthy;
  final String message;
}

final systemStatusProvider = FutureProvider<SystemStatus>((ref) async {
  final dio = ref.watch(apiDioProvider);

  try {
    final response = await dio.get<dynamic>('health');
    if (response.statusCode == 200) {
      final data = response.data;
      final message = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Backend is healthy';
      return SystemStatus(isHealthy: true, message: message);
    }
    return const SystemStatus(
      isHealthy: false,
      message: 'Backend returned an unexpected response',
    );
  } on DioException catch (error) {
    final detail = error.response?.data;
    if (detail is Map && detail['detail'] != null) {
      return SystemStatus(
        isHealthy: false,
        message: detail['detail'].toString(),
      );
    }
    return SystemStatus(
      isHealthy: false,
      message: error.message ?? 'Backend unavailable',
    );
  } catch (error) {
    return SystemStatus(
      isHealthy: false,
      message: error.toString(),
    );
  }
});
