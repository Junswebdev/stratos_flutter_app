import '../../../data/json_parsing.dart';
import '../../../core/utils/url_utils.dart';
import '../../auth/domain/user_model.dart';
import 'lesson_model.dart';

class ModuleModel {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final int order;
  final List<LessonModel> lessons;

  const ModuleModel({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.order = 0,
    this.lessons = const <LessonModel>[],
  });

  factory ModuleModel.fromJson(dynamic source) {
    final json = unwrapJsonMap(source);
    final lessons = asJsonMapList(readJsonValue(json, const ['lessons', 'items']));

    return ModuleModel(
      id: readString(json, const ['id', 'module_id', 'uuid']) ?? '',
      courseId: readString(json, const ['course_id', 'courseId']) ?? '',
      title: readString(json, const ['title', 'name']) ?? '',
      description: readString(json, const ['description', 'summary']),
      order: readInt(json, const ['order', 'position', 'sort_order']) ?? 0,
      lessons: lessons.map(LessonModel.fromJson).toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'course_id': courseId,
      'title': title,
      'description': description,
      'order': order,
      'lessons': lessons.map((lesson) => lesson.toJson()).toList(growable: false),
    };
  }

  ModuleModel copyWith({
    String? id,
    String? courseId,
    String? title,
    String? description,
    int? order,
    List<LessonModel>? lessons,
  }) {
    return ModuleModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      title: title ?? this.title,
      description: description ?? this.description,
      order: order ?? this.order,
      lessons: lessons ?? this.lessons,
    );
  }
}

class CourseModel {
  final String id;
  final String title;
  final String? description;
  final EduLevel eduLevel;
  final String instructorId;
  final String? instructorName;
  final String joinCode;
  final String? imageUrl;

  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ModuleModel> modules;
  final List<LessonModel> lessons;

  const CourseModel({
    required this.id,
    required this.title,
    this.description,
    this.eduLevel = EduLevel.unknown,
    required this.instructorId,
    this.instructorName,
    required this.joinCode,
    this.imageUrl,
    this.isPublished = true,
    this.createdAt,
    this.updatedAt,
    this.modules = const <ModuleModel>[],
    this.lessons = const <LessonModel>[],
  });

  factory CourseModel.fromJson(dynamic source) {
    final json = unwrapJsonMap(source);
    final moduleList = asJsonMapList(readJsonValue(json, const ['modules']));
    final lessonList = asJsonMapList(readJsonValue(json, const ['lessons']));
    final instructor = asJsonMap(readJsonValue(json, const ['instructor', 'teacher', 'owner']) ?? {});

    return CourseModel(
      id: readString(json, const ['id', 'course_id', 'uuid']) ?? '',
      title: readString(json, const ['title', 'name']) ?? '',
      description: readString(json, const ['description', 'summary']),
      eduLevel: EduLevel.fromJson(readJsonValue(json, const ['edu_level', 'eduLevel'])),
      instructorId: readString(json, const ['instructor_id', 'instructorId', 'owner_id']) ?? '',
      instructorName: readString(
        instructor,
        const ['full_name', 'display_name', 'name'],
      ) ??
          readString(json, const ['instructor_name', 'instructorName', 'teacher_name']),
      joinCode: readString(json, const ['join_code', 'joinCode']) ?? '',
      imageUrl: formatFullUrl(readString(json, const ['image_url', 'imageUrl', 'poster_url'])),
      isPublished: readBool(json, const ['is_published', 'isPublished', 'published']) ?? true,
      createdAt: readDateTime(json, const ['created_at', 'createdAt']),
      updatedAt: readDateTime(json, const ['updated_at', 'updatedAt']),
      modules: moduleList.map(ModuleModel.fromJson).toList(growable: false),
      lessons: lessonList.map(LessonModel.fromJson).toList(growable: false),
    );
  }

  List<LessonModel> get allLessons {
    if (lessons.isNotEmpty) {
      return lessons;
    }

    return modules
        .expand((module) => module.lessons)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'description': description,
      'edu_level': eduLevel.toJson(),
      'instructor_id': instructorId,
      'instructor_name': instructorName,
      'join_code': joinCode,
      'image_url': imageUrl,
      'is_published': isPublished,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'modules': modules.map((module) => module.toJson()).toList(growable: false),
      'lessons': lessons.map((lesson) => lesson.toJson()).toList(growable: false),
    };
  }

  CourseModel copyWith({
    String? id,
    String? title,
    String? description,
    EduLevel? eduLevel,
    String? instructorId,
    String? instructorName,
    String? joinCode,
    String? imageUrl,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ModuleModel>? modules,
    List<LessonModel>? lessons,
  }) {
    return CourseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eduLevel: eduLevel ?? this.eduLevel,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      joinCode: joinCode ?? this.joinCode,
      imageUrl: imageUrl ?? this.imageUrl,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      modules: modules ?? this.modules,
      lessons: lessons ?? this.lessons,
    );
  }
}
