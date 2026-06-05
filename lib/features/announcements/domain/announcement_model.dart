import '../../../data/json_parsing.dart';
import '../../auth/domain/user_model.dart';

class AnnouncementModel {
  final String id;
  final String title;
  final String? content;
  final String? summary;
  final String? courseId;
  final String? courseTitle;
  final String? authorId;
  final String? authorName;
  final UserModel? author;
  final bool isPinned;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    this.content,
    this.summary,
    this.courseId,
    this.courseTitle,
    this.authorId,
    this.authorName,
    this.author,
    this.isPinned = false,
    this.isPublished = true,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
  });

  factory AnnouncementModel.fromJson(dynamic source) {
    final json = unwrapJsonMap(source);
    final authorValue = readJsonValue(json, const ['author', 'created_by', 'user']);

    return AnnouncementModel(


      id: readString(json, const ['id', 'announcement_id', 'uuid']) ?? '',
      title: readString(json, const ['title', 'subject']) ?? '',
      content: readString(json, const ['content', 'body', 'message']),
      summary: readString(json, const ['summary', 'excerpt', 'preview']),
      courseId: readString(json, const ['course_id', 'courseId']),
      courseTitle: readString(json, const ['course_title', 'courseTitle']),
      authorId: readString(json, const ['author_id', 'authorId', 'created_by_id']),
      authorName: readString(json, const ['author_name', 'authorName', 'created_by_name']),
      author: authorValue is Map ? UserModel.fromJson(authorValue) : null,

      isPinned: readBool(json, const ['is_pinned', 'isPinned']) ?? false,
      isPublished: readBool(json, const ['is_published', 'isPublished', 'published']) ?? true,
      publishedAt: readDateTime(json, const ['published_at', 'publishedAt']),
      createdAt: readDateTime(json, const ['created_at', 'createdAt']),
      updatedAt: readDateTime(json, const ['updated_at', 'updatedAt']),
      expiresAt: readDateTime(json, const ['expires_at', 'expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'summary': summary,
      'course_id': courseId,
      'course_title': courseTitle,
      'author_id': authorId,
      'author_name': authorName,
      'author': author?.toJson(),
      'is_pinned': isPinned,
      'is_published': isPublished,
      'published_at': publishedAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  AnnouncementModel copyWith({
    String? id,
    String? title,
    String? content,
    String? summary,
    String? courseId,
    String? courseTitle,
    String? authorId,
    String? authorName,
    UserModel? author,
    bool? isPinned,
    bool? isPublished,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? expiresAt,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      summary: summary ?? this.summary,
      courseId: courseId ?? this.courseId,
      courseTitle: courseTitle ?? this.courseTitle,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      author: author ?? this.author,
      isPinned: isPinned ?? this.isPinned,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}