enum QuestionType {
  multipleChoice,
  fillInTheBlanks,
  objective,
  essay;

  String toJson() {
    return name.replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}');
  }

  static QuestionType fromJson(String json) {
    if (json == 'multiple_choice') return multipleChoice;
    if (json == 'fill_in_the_blanks') return fillInTheBlanks;
    if (json == 'objective') return objective;
    if (json == 'essay') return essay;
    return multipleChoice;
  }
}

class QuizQuestionModel {
  final String id;
  final String questionText;
  final QuestionType type;
  final Map<String, dynamic> data;
  final String? explanation;
  final int order;

  QuizQuestionModel({
    required this.id,
    required this.questionText,
    required this.type,
    required this.data,
    this.explanation,
    required this.order,
  });

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      id: json['id'] as String,
      questionText: json['question_text'] as String,
      type: QuestionType.fromJson(json['question_type'] as String),
      data: json['question_data'] as Map<String, dynamic>,
      explanation: json['explanation'] as String?,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'question_text': questionText,
    'question_type': type.toJson(),
    'question_data': data,
    'explanation': explanation,
    'order': order,
  };
}

class QuizModel {
  final String id;
  final String lessonId;
  final String title;
  final String? description;
  final List<QuizQuestionModel> questions;

  QuizModel({
    required this.id,
    required this.lessonId,
    required this.title,
    this.description,
    required this.questions,
  });

  factory QuizModel.fromJson(Map<String, dynamic> json) {
    return QuizModel(
      id: json['id'] as String,
      lessonId: json['lesson_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      questions: (json['questions'] as List<dynamic>)
          .map((q) => QuizQuestionModel.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuizAttemptModel {
  final String id;
  final double score;
  final int totalPoints;
  final List<dynamic> answers;
  final String? instructorFeedback;
  final String? studentName;
  final String? studentEmail;
  final DateTime completedAt;

  QuizAttemptModel({
    required this.id,
    required this.score,
    required this.totalPoints,
    required this.answers,
    this.instructorFeedback,
    this.studentName,
    this.studentEmail,
    required this.completedAt,
  });

  factory QuizAttemptModel.fromJson(Map<String, dynamic> json) {
    return QuizAttemptModel(
      id: json['id'] as String,
      score: (json['score'] as num).toDouble(),
      totalPoints: json['total_points'] as int,
      answers: json['answers'] as List<dynamic>,
      instructorFeedback: json['instructor_feedback'] as String?,
      studentName: json['student_name'] as String?,
      studentEmail: json['student_email'] as String?,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }
}
