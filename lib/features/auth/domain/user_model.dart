import '../../../data/json_parsing.dart';
import '../../../core/utils/url_utils.dart';

enum UserRole {
  student,
  instructor,
  admin,
  unknown;

  static UserRole fromJson(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    switch (normalized) {
      case 'student':
        return UserRole.student;
      case 'instructor':
        return UserRole.instructor;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.unknown;
    }
  }

  String toJson() {
    return switch (this) {
      UserRole.student => 'student',
      UserRole.instructor => 'instructor',
      UserRole.admin => 'admin',
      UserRole.unknown => 'unknown',
    };
  }
}

enum EduLevel {
  primary,
  secondary,
  higherEd,
  unknown;

  static EduLevel fromJson(dynamic value) {
    final normalized = value?.toString().trim().toUpperCase();
    switch (normalized) {
      case 'PRIMARY':
        return EduLevel.primary;
      case 'SECONDARY':
        return EduLevel.secondary;
      case 'HIGHER_ED':
      case 'HIGHERED':
      case 'HIGHER-ED':
        return EduLevel.higherEd;
      default:
        return EduLevel.unknown;
    }
  }

  String toJson() {
    return switch (this) {
      EduLevel.primary => 'PRIMARY',
      EduLevel.secondary => 'SECONDARY',
      EduLevel.higherEd => 'HIGHER_ED',
      EduLevel.unknown => 'UNKNOWN',
    };
  }
}

class UserModel {
  final String id;
  final String email;
  final String? username;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String? phoneNumber;
  final String? avatarUrl;
  final UserRole role;
  final EduLevel eduLevel;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    this.username,
    this.firstName,
    this.lastName,
    this.fullName,
    this.phoneNumber,
    this.avatarUrl,
    this.role = UserRole.unknown,
    this.eduLevel = EduLevel.unknown,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(dynamic source) {
    final json = unwrapJsonMap(source);

    return UserModel(
      id: readString(json, const ['id', 'user_id', 'uuid']) ?? '',
      email: readString(json, const ['email', 'email_address']) ?? '',
      username: readString(json, const ['username', 'user_name']),
      firstName: readString(json, const ['first_name', 'firstName']),
      lastName: readString(json, const ['last_name', 'lastName']),
      fullName: readString(json, const ['full_name', 'fullName', 'name']),
      phoneNumber: readString(json, const ['phone_number', 'phoneNumber', 'phone']),
      avatarUrl: formatFullUrl(readString(json, const ['avatar_url', 'avatarUrl', 'profile_image', 'profileImage'])),
      role: UserRole.fromJson(readJsonValue(json, const ['role', 'user_role'])),
      eduLevel: EduLevel.fromJson(readJsonValue(json, const ['edu_level', 'eduLevel', 'education_level'])),
      isActive: readBool(json, const ['is_active', 'isActive']) ?? true,
      createdAt: readDateTime(json, const ['created_at', 'createdAt']),
      updatedAt: readDateTime(json, const ['updated_at', 'updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'email': email,
      'username': username,
      'first_name': firstName,
      'last_name': lastName,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'avatar_url': avatarUrl,
      'role': role.toJson(),
      'edu_level': eduLevel.toJson(),
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? username,
    String? firstName,
    String? lastName,
    String? fullName,
    String? phoneNumber,
    String? avatarUrl,
    UserRole? role,
    EduLevel? eduLevel,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      eduLevel: eduLevel ?? this.eduLevel,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName {
    final candidates = [
      fullName,
      [firstName, lastName].whereType<String>().join(' ').trim(),
      username,
      email,
    ];

    for (final value in candidates) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }
}