import '../../../data/json_parsing.dart';

class LessonModel {
  final String id;
  final String courseId;
  final String? moduleId;
  final String title;
  final String? slug;
  final String? description;
  final String? content;
  final String? videoUrl;
  final String? attachmentUrl;
  final String? contentType;
  final int order;
  final int? durationMinutes;
  final bool isPreview;
  final bool isCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const LessonModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.moduleId,
    this.slug,
    this.description,
    this.content,
    this.videoUrl,
    this.attachmentUrl,
    this.contentType,
    this.order = 0,
    this.durationMinutes,
    this.isPreview = false,
    this.isCompleted = false,
    this.createdAt,
    this.updatedAt,
  });

  factory LessonModel.fromJson(dynamic source) {
    final json = unwrapJsonMap(source);

    return LessonModel(
      id: readString(json, const ['id', 'lesson_id', 'uuid']) ?? '',
      courseId: readString(json, const ['course_id', 'courseId']) ?? '',
      moduleId: readString(json, const ['module_id', 'moduleId']),
      title: readString(json, const ['title', 'name']) ?? '',
      slug: readString(json, const ['slug']),
      description: readString(json, const ['description', 'summary']),
      content: readString(json, const ['content', 'body', 'text', 'content_data']),
      videoUrl: readString(json, const ['video_url', 'videoUrl', 'video']),
      attachmentUrl: readString(json, const ['attachment_url', 'attachmentUrl', 'file_url', 'fileUrl']),
      contentType: readString(json, const ['content_type', 'contentType']),
      order: readInt(json, const ['order', 'position', 'sort_order']) ?? 0,
      durationMinutes: readInt(json, const ['duration_minutes', 'durationMinutes', 'minutes']),
      isPreview: readBool(json, const ['is_preview', 'isPreview']) ?? false,
      isCompleted: readBool(json, const ['is_completed', 'isCompleted', 'completed']) ?? false,
      createdAt: readDateTime(json, const ['created_at', 'createdAt']),
      updatedAt: readDateTime(json, const ['updated_at', 'updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'course_id': courseId,
      'module_id': moduleId,
      'title': title,
      'slug': slug,
      'description': description,
      'content': content,
      'video_url': videoUrl,
      'attachment_url': attachmentUrl,
      'order': order,
      'duration_minutes': durationMinutes,
      'content_type': contentType,
      'is_preview': isPreview,
      'is_completed': isCompleted,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  LessonModel copyWith({
    String? id,
    String? courseId,
    String? moduleId,
    String? title,
    String? slug,
    String? description,
    String? content,
    String? videoUrl,
    String? attachmentUrl,
    int? order,
    int? durationMinutes,
    String? contentType,
    bool? isPreview,
    bool? isCompleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LessonModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      moduleId: moduleId ?? this.moduleId,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      content: content ?? this.content,
      videoUrl: videoUrl ?? this.videoUrl,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      order: order ?? this.order,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      contentType: contentType ?? this.contentType,
      isPreview: isPreview ?? this.isPreview,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}