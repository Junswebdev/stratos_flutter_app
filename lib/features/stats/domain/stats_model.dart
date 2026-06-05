import '../../../data/json_parsing.dart';

class StatsMeModel {
  final int? totalCourses;
  final int? enrolledCourses;
  final int? completedCourses;
  final int? totalLessons;
  final int? completedLessons;
  final int? unreadAnnouncements;
  final int? unreadMessages;
  final int? activeStreakDays;
  final double? progressPercentage;
  final String? period;
  final Map<String, dynamic> raw;

  const StatsMeModel({
    this.totalCourses,
    this.enrolledCourses,
    this.completedCourses,
    this.totalLessons,
    this.completedLessons,
    this.unreadAnnouncements,
    this.unreadMessages,
    this.activeStreakDays,
    this.progressPercentage,
    this.period,
    this.raw = const <String, dynamic>{},
  });

  factory StatsMeModel.fromJson(dynamic source) {
    final json = unwrapJsonMap(source);

    return StatsMeModel(
      totalCourses: readInt(json, const ['total_courses', 'courses_total', 'course_count']),
      enrolledCourses: readInt(json, const ['enrolled_courses', 'courses_enrolled', 'enrollment_count']),
      completedCourses: readInt(json, const ['completed_courses', 'courses_completed']),
      totalLessons: readInt(json, const ['total_lessons', 'lessons_total']),
      completedLessons: readInt(json, const ['completed_lessons', 'lessons_completed']),
      unreadAnnouncements: readInt(json, const ['unread_announcements', 'announcements_unread']),
      unreadMessages: readInt(json, const ['unread_messages', 'messages_unread']),
      activeStreakDays: readInt(json, const ['active_streak_days', 'streak_days', 'streak']),
      progressPercentage: readDouble(json, const ['progress_percentage', 'progress', 'completion_rate']),
      period: readString(json, const ['period', 'range', 'timeframe']),
      raw: Map<String, dynamic>.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total_courses': totalCourses,
      'enrolled_courses': enrolledCourses,
      'completed_courses': completedCourses,
      'total_lessons': totalLessons,
      'completed_lessons': completedLessons,
      'unread_announcements': unreadAnnouncements,
      'unread_messages': unreadMessages,
      'active_streak_days': activeStreakDays,
      'progress_percentage': progressPercentage,
      'period': period,
      ...raw,
    };
  }

  StatsMeModel copyWith({
    int? totalCourses,
    int? enrolledCourses,
    int? completedCourses,
    int? totalLessons,
    int? completedLessons,
    int? unreadAnnouncements,
    int? unreadMessages,
    int? activeStreakDays,
    double? progressPercentage,
    String? period,
    Map<String, dynamic>? raw,
  }) {
    return StatsMeModel(
      totalCourses: totalCourses ?? this.totalCourses,
      enrolledCourses: enrolledCourses ?? this.enrolledCourses,
      completedCourses: completedCourses ?? this.completedCourses,
      totalLessons: totalLessons ?? this.totalLessons,
      completedLessons: completedLessons ?? this.completedLessons,
      unreadAnnouncements: unreadAnnouncements ?? this.unreadAnnouncements,
      unreadMessages: unreadMessages ?? this.unreadMessages,
      activeStreakDays: activeStreakDays ?? this.activeStreakDays,
      progressPercentage: progressPercentage ?? this.progressPercentage,
      period: period ?? this.period,
      raw: raw ?? this.raw,
    );
  }
}