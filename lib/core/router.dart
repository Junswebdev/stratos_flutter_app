import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/register_screen.dart';
import '../features/courses/presentation/screens/course_detail_screen.dart';
import '../features/courses/presentation/screens/course_list_screen.dart';
import '../features/courses/presentation/screens/create_course_screen.dart';
import '../features/courses/presentation/screens/manage_course_screen.dart';
import '../features/courses/presentation/screens/manage_quiz_screen.dart';
import '../features/courses/presentation/screens/quiz_taking_screen.dart';
import '../features/courses/presentation/screens/quiz_attempts_screen.dart';
import '../features/courses/presentation/screens/quiz_review_screen.dart';
import '../features/courses/domain/quiz_model.dart';
import '../features/courses/presentation/screens/ai_assistant_screen.dart';
import '../features/admin/presentation/screens/admin_screen.dart';
import '../features/chat/presentation/screens/chat_screen.dart';
import '../features/chat/presentation/screens/conversations_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/home/presentation/screens/announcements_screen.dart';
import '../features/home/presentation/screens/settings_screen.dart';
import '../features/home/presentation/widgets/main_shell.dart';
import '../features/stats/presentation/screens/reports_screen.dart';
import '../features/stats/presentation/screens/student_list_screen.dart';
import '../features/lessons/presentation/screens/lesson_viewer_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Use a ValueNotifier to notify GoRouter when auth state changes
  // without recreating the entire GoRouter instance.
  final authStateNotifier = ValueNotifier<AsyncValue<AuthState>>(ref.read(authControllerProvider));
  
  // Update the notifier when the auth state changes
  ref.listen<AsyncValue<AuthState>>(authControllerProvider, (previous, next) {
    authStateNotifier.value = next;
  });

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authStateNotifier,
    redirect: (context, state) {
      final authState = authStateNotifier.value;
      final isAuthenticated = authState.value?.isAuthenticated ?? false;
      final isGoingToLogin = state.matchedLocation == '/login';
      final isGoingToRegister = state.matchedLocation == '/register';
      final role = authState.value?.role;

      if (!isAuthenticated && !isGoingToLogin && !isGoingToRegister) {
        return '/login';
      }

      if (isAuthenticated && (isGoingToLogin || isGoingToRegister)) {
        return '/';
      }

      // Role-based route guards
      final isGoingToCreateCourse = state.matchedLocation == '/courses/create';
      final isGoingToManageCourse = state.matchedLocation.endsWith('/manage');
      final isGoingToManageQuiz = state.matchedLocation.endsWith('/manage-quiz');
      final isGoingToAdmin = state.matchedLocation.startsWith('/admin');
      final isGoingToReports = state.matchedLocation == '/reports';

      if ((isGoingToCreateCourse || isGoingToManageCourse || isGoingToManageQuiz || isGoingToReports) && 
          role != 'instructor' && role != 'admin') {
        return '/'; 
      }

      if (isGoingToAdmin && role != 'admin') {
        return '/'; 
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      
      // Main Shell routes
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            name: 'home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/courses',
            name: 'courses',
            builder: (context, state) => const CourseListScreen(),
          ),
          GoRoute(
            path: '/messages',
            name: 'messages',
            builder: (context, state) => const ConversationsScreen(),
          ),
          GoRoute(
            path: '/announcements',
            name: 'announcements',
            builder: (context, state) => const AnnouncementsScreen(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/reports/:courseId/students',
            name: 'course_report_students',
            builder: (context, state) {
              final extra = state.extra as Map<String, dynamic>;
              return StudentListScreen(
                courseTitle: extra['title'] as String,
                students: extra['students'] as List<StudentProgress>,
              );
            },
          ),
          GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/admin',
            name: 'admin',
            builder: (context, state) => const AdminScreen(),
          ),
        ],
      ),

      // Non-shell routes (fullscreen experiences)
      GoRoute(
        path: '/courses/create',
        name: 'create_course',
        builder: (context, state) => const CreateCourseScreen(),
      ),
      GoRoute(
        path: '/courses/:id',
        name: 'course_detail',
        builder: (context, state) {
          final courseId = state.pathParameters['id'] ?? '';
          return CourseDetailScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: '/courses/:id/ai',
        name: 'course_ai',
        builder: (context, state) {
          final courseId = state.pathParameters['id'] ?? '';
          final courseTitle = state.extra as String? ?? 'Course';
          return AIAssistantScreen(courseId: courseId, courseTitle: courseTitle);
        },
      ),
      GoRoute(
        path: '/chat/course/:courseId',
        name: 'course_chat',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId'] ?? '';
          final courseName = state.extra as String?;
          return ChatScreen(courseId: courseId, courseName: courseName);
        },
      ),
      GoRoute(
        path: '/chat/direct/:userId',
        name: 'direct_chat',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          final userName = state.extra as String?;
          return ChatScreen(recipientId: userId, recipientName: userName);
        },
      ),
      GoRoute(
        path: '/courses/:id/manage',
        name: 'manage_course',
        builder: (context, state) {
          final courseId = state.pathParameters['id'] ?? '';
          return ManageCourseScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: '/lessons/:lessonId/manage-quiz',
        name: 'manage_quiz',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId'] ?? '';
          final lessonTitle = state.extra as String? ?? 'Lesson';
          return ManageQuizScreen(lessonId: lessonId, lessonTitle: lessonTitle);
        },
      ),
      GoRoute(
        path: '/quizzes/:quizId/attempts',
        name: 'quiz_attempts',
        builder: (context, state) {
          final quizId = state.pathParameters['quizId'] ?? '';
          final quizTitle = state.extra as String? ?? 'Quiz';
          return QuizAttemptsScreen(quizId: quizId, quizTitle: quizTitle);
        },
      ),
      GoRoute(
        path: '/quizzes/:quizId/attempts/review',
        name: 'quiz_review',
        builder: (context, state) {
          final quizId = state.pathParameters['quizId'] ?? '';
          final attempt = state.extra as QuizAttemptModel;
          return QuizReviewScreen(quizId: quizId, attempt: attempt);
        },
      ),
      GoRoute(
        path: '/lessons/:lessonId/quiz',
        name: 'quiz_taking',
        builder: (context, state) {
          final lessonId = state.pathParameters['lessonId'] ?? '';
          final lessonTitle = state.extra as String? ?? 'Quiz';
          return QuizTakingScreen(lessonId: lessonId, lessonTitle: lessonTitle);
        },
      ),
      GoRoute(
        path: '/courses/:courseId/lessons/:lessonId',
        name: 'lesson_viewer',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId'] ?? '';
          final lessonId = state.pathParameters['lessonId'] ?? '';
          final lessonTitle = state.extra as String?;
          return LessonViewerScreen(
            lessonId: lessonId,
            courseId: courseId,
            lessonTitle: lessonTitle,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Class IQ')),
      body: Center(
        child: Text(state.error?.toString() ?? 'Page not found'),
      ),
    ),
  );
});
