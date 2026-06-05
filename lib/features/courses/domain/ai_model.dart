class AIQuestionRequest {
  final String courseId;
  final String question;

  AIQuestionRequest({required this.courseId, required this.question});

  Map<String, dynamic> toJson() => {
    'course_id': courseId,
    'question': question,
  };
}

class AIAnswerResponse {
  final String answer;

  AIAnswerResponse({required this.answer});

  factory AIAnswerResponse.fromJson(Map<String, dynamic> json) {
    return AIAnswerResponse(
      answer: json['answer'] as String,
    );
  }
}
