import 'package:flutter/foundation.dart';
import '../../../../core/utils/url_utils.dart';

String _stringFromJson(
  Map<String, dynamic> json,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

int _intFromJson(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return fallback;
}

double _doubleFromJson(
  Map<String, dynamic> json,
  List<String> keys, {
  double fallback = 0,
}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return fallback;
}

bool _boolFromJson(Map<String, dynamic> json, List<String> keys, {bool fallback = false}) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is bool) return value;
    final normalized = value.toString().toLowerCase().trim();
    if (['true', '1', 'yes', 'y'].contains(normalized)) return true;
    if (['false', '0', 'no', 'n'].contains(normalized)) return false;
  }
  return fallback;
}

DateTime? _dateTimeFromJson(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) return parsed;
  }
  return null;
}

List<Map<String, dynamic>> _mapListFromJson(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final value = json[key];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }
  }
  return const [];
}

Map<String, dynamic>? _mapFromJson(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
  }
  return null;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    required this.eduLevel,
    required this.isActive,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String email;
  final String role;
  final String? eduLevel;
  final bool isActive;
  final String? avatarUrl;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: _stringFromJson(json, const ['id', 'uuid', 'user_id']),
      displayName: _stringFromJson(
        json,
        const ['full_name', 'display_name', 'name', 'username'],
        fallback: 'User',
      ),
      email: _stringFromJson(json, const ['email', 'email_address']),
      role: _stringFromJson(json, const ['role', 'user_role'], fallback: 'student').toLowerCase(),
      eduLevel: _stringFromJson(json, const ['edu_level', 'education_level'], fallback: ''),
      isActive: _boolFromJson(json, const ['is_active', 'active', 'enabled'], fallback: true),
      avatarUrl: formatFullUrl(_stringFromJson(
        json,
        const ['avatar_url', 'avatarUrl', 'profile_image', 'profileImage'],
        fallback: '',
      )),
    );
  }
}

class CourseLesson {
  const CourseLesson({
    required this.id,
    required this.title,
    required this.order,
    required this.isCompleted,
    required this.description,
    required this.durationMinutes,
    required this.videoUrl,
    required this.contentType,
  });

  final String id;
  final String title;
  final int order;
  final bool isCompleted;
  final String description;
  final int durationMinutes;
  final String? videoUrl;
  final String? contentType;

  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    return CourseLesson(
      id: _stringFromJson(json, const ['id', 'uuid', 'lesson_id']),
      title: _stringFromJson(json, const ['title', 'name'], fallback: 'Lesson'),
      order: _intFromJson(json, const ['order', 'position', 'sort_order']),
      isCompleted: _boolFromJson(json, const ['is_completed', 'completed', 'done']),
      description: _stringFromJson(json, const ['description', 'summary']),
      durationMinutes: _intFromJson(json, const ['duration_minutes', 'duration', 'length_minutes']),
      videoUrl: _stringFromJson(json, const ['video_url', 'video', 'stream_url'], fallback: ''),
      contentType: _stringFromJson(json, const ['content_type', 'type'], fallback: 'text'),
    );
  }
}

class CourseModule {
  const CourseModule({
    required this.id,
    required this.title,
    required this.order,
    required this.description,
    required this.lessons,
  });

  final String id;
  final String title;
  final int order;
  final String description;
  final List<CourseLesson> lessons;

  factory CourseModule.fromJson(Map<String, dynamic> json) {
    final lessons = _mapListFromJson(json, const ['lessons', 'items', 'children'])
        .map(CourseLesson.fromJson)
        .toList(growable: false);

    return CourseModule(
      id: _stringFromJson(json, const ['id', 'uuid', 'module_id']),
      title: _stringFromJson(json, const ['title', 'name'], fallback: 'Module'),
      order: _intFromJson(json, const ['order', 'position', 'sort_order']),
      description: _stringFromJson(json, const ['description', 'summary']),
      lessons: lessons,
    );
  }
}

class CourseSummary {
  const CourseSummary({
    required this.id,
    required this.title,
    required this.description,
    required this.instructorId,
    required this.instructorName,
    required this.level,
    this.imageUrl,
    required this.isEnrolled,
    this.enrollmentStatus,
    required this.progressPercent,
    required this.modulesCount,
    required this.lessonsCount,
    required this.announcementsCount,
  });

  final String id;
  final String title;
  final String description;
  final String instructorId;
  final String instructorName;
  final String level;
  final String? imageUrl;
  final bool isEnrolled;
  final String? enrollmentStatus; // 'pending' or 'approved'
  final double progressPercent;
  final int modulesCount;
  final int lessonsCount;
  final int announcementsCount;

  factory CourseSummary.fromJson(Map<String, dynamic> json) {
    final instructor = _mapFromJson(json, const ['instructor', 'teacher', 'owner']);
    return CourseSummary(
      id: _stringFromJson(json, const ['id', 'uuid', 'course_id']),
      title: _stringFromJson(json, const ['title', 'name'], fallback: 'Untitled course'),
      description: _stringFromJson(json, const ['description', 'summary']),
      instructorId: _stringFromJson(
        instructor ?? const {},
        const ['id', 'uuid', 'instructor_id'],
        fallback: _stringFromJson(json, const ['instructor_id'], fallback: ''),
      ),
      instructorName: _stringFromJson(
        instructor ?? const {},
        const ['full_name', 'display_name', 'name'],
        fallback: _stringFromJson(json, const ['instructor_name', 'teacher_name'], fallback: 'Instructor'),
      ),
      level: _stringFromJson(json, const ['level', 'edu_level', 'education_level']),
      imageUrl: formatFullUrl(_stringFromJson(json, const ['image_url', 'imageUrl', 'poster_url'])),
      isEnrolled: _boolFromJson(json, const ['is_enrolled', 'enrolled']),
      enrollmentStatus: _stringFromJson(json, const ['enrollment_status', 'status']),
      progressPercent: _doubleFromJson(json, const ['progress_percent', 'progress', 'completion_percent']),
      modulesCount: _intFromJson(json, const ['modules_count', 'module_count']),
      lessonsCount: _intFromJson(json, const ['lessons_count', 'lesson_count']),
      announcementsCount: _intFromJson(json, const ['announcements_count']),
    );
  }
}

class CourseDetailData extends CourseSummary {
  const CourseDetailData({
    required super.id,
    required super.title,
    required super.description,
    required super.instructorId,
    required super.instructorName,
    required super.level,
    super.imageUrl,
    required super.isEnrolled,
    super.enrollmentStatus,
    required super.progressPercent,
    required super.modulesCount,
    required super.lessonsCount,
    required super.announcementsCount,
    required this.modules,
    required this.extra,
  });

  final List<CourseModule> modules;
  final Map<String, dynamic> extra;

  factory CourseDetailData.fromJson(Map<String, dynamic> json) {
    final course = _mapFromJson(json, const ['course', 'data']) ?? json;
    final modules = _mapListFromJson(json, const ['modules', 'sections', 'curriculum']).isNotEmpty
        ? _mapListFromJson(json, const ['modules', 'sections', 'curriculum'])
            .map(CourseModule.fromJson)
            .toList()
        : _mapListFromJson(course, const ['modules', 'sections', 'curriculum'])
            .map(CourseModule.fromJson)
            .toList();

    final lessonsCount = _intFromJson(course, const ['lessons_count', 'lesson_count']);
    final derivedLessonsCount = lessonsCount > 0
        ? lessonsCount
        : modules.fold<int>(0, (total, module) => total + module.lessons.length);

    final instructor = _mapFromJson(course, const ['instructor', 'teacher', 'owner']);

    return CourseDetailData(
      id: _stringFromJson(course, const ['id', 'uuid', 'course_id']),
      title: _stringFromJson(course, const ['title', 'name'], fallback: 'Untitled course'),
      description: _stringFromJson(course, const ['description', 'summary']),
      instructorId: _stringFromJson(
        instructor ?? const {},
        const ['id', 'uuid', 'instructor_id'],
        fallback: _stringFromJson(course, const ['instructor_id'], fallback: ''),
      ),
      instructorName: _stringFromJson(
        instructor ?? const {},
        const ['full_name', 'display_name', 'name'],
        fallback: _stringFromJson(course, const ['instructor_name', 'teacher_name'], fallback: 'Instructor'),
      ),
      level: _stringFromJson(course, const ['level', 'edu_level', 'education_level']),
      imageUrl: formatFullUrl(_stringFromJson(course, const ['image_url', 'imageUrl', 'poster_url'])),
      isEnrolled: _boolFromJson(course, const ['is_enrolled', 'enrolled']),
      enrollmentStatus: _stringFromJson(course, const ['enrollment_status', 'status']),
      progressPercent: _doubleFromJson(course, const ['progress_percent', 'progress', 'completion_percent']),
      modulesCount: _intFromJson(course, const ['modules_count', 'module_count'], fallback: modules.length),
      lessonsCount: derivedLessonsCount,
      announcementsCount: _intFromJson(course, const ['announcements_count']),
      modules: modules,
      extra: course,
    );
  }
}

class AnnouncementItem {
  const AnnouncementItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.courseTitle,
    required this.courseId,
    required this.authorName,
    this.expiresAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? createdAt;
  final String courseTitle;
  final String? courseId;
  final String authorName;
  final DateTime? expiresAt;

  factory AnnouncementItem.fromJson(Map<String, dynamic> json) {
    final course = _mapFromJson(json, const ['course', 'course_info']);
    final author = _mapFromJson(json, const ['author', 'user', 'created_by']);
    return AnnouncementItem(
      id: _stringFromJson(json, const ['id', 'uuid', 'announcement_id']),
      title: _stringFromJson(json, const ['title', 'heading'], fallback: 'Announcement'),
      body: _stringFromJson(json, const ['body', 'message', 'content', 'description']),
      createdAt: _dateTimeFromJson(json, const ['created_at', 'date_created', 'published_at']),
      courseTitle: _stringFromJson(course ?? const {}, const ['title', 'name'], fallback: ''),
      courseId: _stringFromJson(json, const ['course_id']),
      authorName: _stringFromJson(
        author ?? const {},
        const ['full_name', 'display_name', 'name'],
        fallback: _stringFromJson(json, const ['author_name', 'username'], fallback: ''),
      ),
      expiresAt: _dateTimeFromJson(json, const ['expires_at', 'expiry_date', 'due_date']),
    );
  }
}

class EnrollmentSummary {
  const EnrollmentSummary({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.courseDescription,
    required this.studentName,
    required this.status,
    required this.progressPercent,
    required this.enrolledAt,
    this.imageUrl,
  });

  final String id;
  final String courseId;
  final String courseTitle;
  final String courseDescription;
  final String studentName;
  final String status;
  final double progressPercent;
  final DateTime? enrolledAt;
  final String? imageUrl;

  factory EnrollmentSummary.fromJson(Map<String, dynamic> json) {
    final course = _mapFromJson(json, const ['course', 'course_info']);
    final student = _mapFromJson(json, const ['student', 'user']);
    return EnrollmentSummary(
      id: _stringFromJson(json, const ['id', 'uuid', 'enrollment_id']),
      courseId: _stringFromJson(course ?? json, const ['course_id', 'id', 'uuid']),
      courseTitle: _stringFromJson(course ?? json, const ['title', 'name'], fallback: 'Course'),
      courseDescription: _stringFromJson(course ?? json, const ['description', 'summary']),
      studentName: _stringFromJson(student ?? const {}, const ['full_name', 'name', 'display_name'], fallback: 'Student'),
      status: _stringFromJson(json, const ['status', 'state'], fallback: 'active'),
      progressPercent: _doubleFromJson(json, const ['progress_percent', 'progress', 'completion_percent']),
      enrolledAt: _dateTimeFromJson(json, const ['enrolled_at', 'created_at', 'joined_at']),
      imageUrl: formatFullUrl(_stringFromJson(course ?? json, const ['image_url', 'imageUrl', 'poster_url'])),
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.enrolledCourses,
    required this.completedLessons,
    required this.pendingLessons,
    required this.totalAnnouncements,
    required this.averageProgress,
    required this.activeEnrollments,
    this.coursesCreated = 0,
    this.totalStudents = 0,
    this.totalLessonsAuthored = 0,
    this.unreadMessages = 0,
    this.coursesByLevel = const {},
  });

  final int enrolledCourses;
  final int completedLessons;
  final int pendingLessons;
  final int totalAnnouncements;
  final double averageProgress;
  final int activeEnrollments;
  
  // Instructor specific
  final int coursesCreated;
  final int totalStudents;
  final int totalLessonsAuthored;

  final int unreadMessages;

  final Map<String, int> coursesByLevel;

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final Map<String, int> levelMap = {};
    final rawLevelMap = json['courses_by_level'];
    if (rawLevelMap is Map) {
      rawLevelMap.forEach((k, v) {
        levelMap[k.toString()] = (v is num) ? v.toInt() : 0;
      });
    }

    return DashboardStats(
      enrolledCourses: _intFromJson(json, const ['enrolled_courses', 'course_count', 'courses']),
      completedLessons: _intFromJson(json, const ['completed_lessons', 'lessons_completed']),
      pendingLessons: _intFromJson(json, const ['pending_lessons', 'lessons_pending']),
      totalAnnouncements: _intFromJson(json, const ['total_announcements', 'announcements', 'announcement_count']),
      averageProgress: _doubleFromJson(json, const ['average_progress', 'progress_average', 'progress']),
      activeEnrollments: _intFromJson(json, const ['active_enrollments', 'enrollments']),
      coursesCreated: _intFromJson(json, const ['courses_created', 'created_courses']),
      totalStudents: _intFromJson(json, const ['total_students', 'student_count']),
      totalLessonsAuthored: _intFromJson(json, const ['total_lessons_authored', 'lesson_count']),
      unreadMessages: _intFromJson(json, const ['unread_messages', 'unread_count', 'messages']),
      coursesByLevel: levelMap,
    );
  }
}

class ScheduleItemModel {
  const ScheduleItemModel({
    required this.id,
    required this.title,
    required this.timeStr,
  });

  final String id;
  final String title;
  final String timeStr;

  factory ScheduleItemModel.fromJson(Map<String, dynamic> json) {
    return ScheduleItemModel(
      id: _stringFromJson(json, const ['id', 'uuid']),
      title: _stringFromJson(json, const ['title', 'name'], fallback: 'Untitled'),
      timeStr: _stringFromJson(json, const ['time_str', 'time'], fallback: 'Unknown time'),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.user,
    required this.stats,
    required this.courses,
    required this.announcements,
    required this.enrollments,
    required this.schedule,
  });

  final AppUser? user;
  final DashboardStats? stats;
  final List<CourseSummary> courses;
  final List<AnnouncementItem> announcements;
  final List<EnrollmentSummary> enrollments;
  final List<ScheduleItemModel> schedule;
}

@immutable
class ApiPage<T> {
  const ApiPage({
    required this.items,
    this.raw,
  });

  final List<T> items;
  final Map<String, dynamic>? raw;
}
