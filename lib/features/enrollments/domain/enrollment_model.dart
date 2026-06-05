import '../../../data/json_parsing.dart';

enum EnrollmentStatus {
  pending,
  active,
  completed,
  cancelled,
  declined,
  unknown;

  static EnrollmentStatus fromJson(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'pending':
        return EnrollmentStatus.pending;
      case 'active':
      case 'enrolled':
        return EnrollmentStatus.active;
      case 'completed':
      case 'finished':
        return EnrollmentStatus.completed;
      case 'cancelled':
      case 'canceled':
        return EnrollmentStatus.cancelled;
      case 'declined':
      case 'rejected':
        return EnrollmentStatus.declined;
      default:
        return EnrollmentStatus.unknown;
    }
  }

  String toJson() {
    return switch (this) {
      EnrollmentStatus.pending => 'pending',
      EnrollmentStatus.active => 'active',
      EnrollmentStatus.completed => 'completed',
      EnrollmentStatus.cancelled => 'cancelled',
      EnrollmentStatus.declined => 'declined',
      EnrollmentStatus.unknown => 'unknown',
    };
  }
}

class EnrollmentModel {
  final String id;
  final String userId;
  final String courseId;
  final String? joinCode;
  final EnrollmentStatus status;
  final String? courseTitle;
  final DateTime? enrolledAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EnrollmentModel({
    required this.id,
    required this.userId,
    required this.courseId,
    this.joinCode,
    this.status = EnrollmentStatus.unknown,
    this.courseTitle,
    this.enrolledAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory EnrollmentModel.fromJson(dynamic source) {
    final json = unwrapJsonMap(source);

    return EnrollmentModel(
      id: readString(json, const ['id', 'enrollment_id', 'uuid']) ?? '',
      userId: readString(json, const ['user_id', 'userId']) ?? '',
      courseId: readString(json, const ['course_id', 'courseId']) ?? '',
      joinCode: readString(json, const ['join_code', 'joinCode']),
      status: EnrollmentStatus.fromJson(readJsonValue(json, const ['status', 'state'])),
      courseTitle: readString(json, const ['course_title', 'courseTitle']),
      enrolledAt: readDateTime(json, const ['enrolled_at', 'enrolledAt', 'created_at']),
      completedAt: readDateTime(json, const ['completed_at', 'completedAt']),
      createdAt: readDateTime(json, const ['created_at', 'createdAt']),
      updatedAt: readDateTime(json, const ['updated_at', 'updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'course_id': courseId,
      'join_code': joinCode,
      'status': status.toJson(),
      'course_title': courseTitle,
      'enrolled_at': enrolledAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  EnrollmentModel copyWith({
    String? id,
    String? userId,
    String? courseId,
    String? joinCode,
    EnrollmentStatus? status,
    String? courseTitle,
    DateTime? enrolledAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EnrollmentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      courseId: courseId ?? this.courseId,
      joinCode: joinCode ?? this.joinCode,
      status: status ?? this.status,
      courseTitle: courseTitle ?? this.courseTitle,
      enrolledAt: enrolledAt ?? this.enrolledAt,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class EnrollmentJoinResult {
  final EnrollmentModel? enrollment;
  final String? message;
  final String? joinCode;

  const EnrollmentJoinResult({
    this.enrollment,
    this.message,
    this.joinCode,
  });

  factory EnrollmentJoinResult.fromJson(dynamic source) {
    final json = unwrapJsonMap(source);
    final enrollmentValue = readJsonValue(json, const ['enrollment', 'data', 'result', 'item']);
    return EnrollmentJoinResult(
      enrollment: enrollmentValue == null ? null : EnrollmentModel.fromJson(enrollmentValue),
      message: readString(json, const ['message', 'detail', 'status_message']),
      joinCode: readString(json, const ['join_code', 'joinCode']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'enrollment': enrollment?.toJson(),
      'message': message,
      'join_code': joinCode,
    };
  }
}