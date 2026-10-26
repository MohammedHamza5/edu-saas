import 'package:equatable/equatable.dart';
import 'exam_entity.dart';
import 'question_difficulty_rating.dart';

export 'question_difficulty_rating.dart';

/// An entity representing a bookmarked/saved question in student's personal vault
class SavedQuestionEntity extends Equatable {
  final String id;
  final String questionId;
  final String examId;
  final String examTitle;
  final String questionText;
  final String? questionImageUrl;
  final List<QuestionOptionEntity> options;
  final String? personalNote;
  final QuestionDifficultyRating? difficultyRating;
  final DateTime savedAt;
  final int reviewCount;
  final bool isMastered;
  final String? userAnswerOptionId;
  final String? correctOptionId;
  final String? explanation;
  final int? questionIndex;
  final bool isPdfQuestion;
  final String? pdfUrl;
  final DateTime? nextReviewAt;
  final DateTime? lastReviewedAt;
  final int intervalDays;

  const SavedQuestionEntity({
    required this.id,
    required this.questionId,
    required this.examId,
    required this.examTitle,
    required this.questionText,
    this.questionImageUrl,
    required this.options,
    this.personalNote,
    this.difficultyRating,
    required this.savedAt,
    this.reviewCount = 0,
    this.isMastered = false,
    this.userAnswerOptionId,
    this.correctOptionId,
    this.explanation,
    this.questionIndex,
    this.isPdfQuestion = false,
    this.pdfUrl,
    this.nextReviewAt,
    this.lastReviewedAt,
    this.intervalDays = 0,
  });

  bool get isDueToday {
    if (isMastered) return false;
    if (nextReviewAt == null) return true;
    return !nextReviewAt!.isAfter(DateTime.now());
  }

  int get daysUntilReview {
    if (nextReviewAt == null) return 0;
    final diff = nextReviewAt!.difference(DateTime.now()).inDays;
    return diff <= 0 ? 0 : diff;
  }

  SavedQuestionEntity copyWith({
    String? id,
    String? questionId,
    String? examId,
    String? examTitle,
    String? questionText,
    String? questionImageUrl,
    List<QuestionOptionEntity>? options,
    String? personalNote,
    QuestionDifficultyRating? difficultyRating,
    DateTime? savedAt,
    int? reviewCount,
    bool? isMastered,
    String? userAnswerOptionId,
    String? correctOptionId,
    String? explanation,
    int? questionIndex,
    bool? isPdfQuestion,
    String? pdfUrl,
    DateTime? nextReviewAt,
    bool clearNextReviewAt = false,
    DateTime? lastReviewedAt,
    int? intervalDays,
  }) {
    return SavedQuestionEntity(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      examId: examId ?? this.examId,
      examTitle: examTitle ?? this.examTitle,
      questionText: questionText ?? this.questionText,
      questionImageUrl: questionImageUrl ?? this.questionImageUrl,
      options: options ?? this.options,
      personalNote: personalNote ?? this.personalNote,
      difficultyRating: difficultyRating ?? this.difficultyRating,
      savedAt: savedAt ?? this.savedAt,
      reviewCount: reviewCount ?? this.reviewCount,
      isMastered: isMastered ?? this.isMastered,
      userAnswerOptionId: userAnswerOptionId ?? this.userAnswerOptionId,
      correctOptionId: correctOptionId ?? this.correctOptionId,
      explanation: explanation ?? this.explanation,
      questionIndex: questionIndex ?? this.questionIndex,
      isPdfQuestion: isPdfQuestion ?? this.isPdfQuestion,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      nextReviewAt: clearNextReviewAt ? null : (nextReviewAt ?? this.nextReviewAt),
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      intervalDays: intervalDays ?? this.intervalDays,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_id': questionId,
      'exam_id': examId,
      'exam_title': examTitle,
      'question_text': questionText,
      'question_image_url': questionImageUrl,
      'options': options.map((o) => {
        'id': o.id,
        'option_text': o.optionText,
        'sort_order': o.sortOrder,
        'is_correct': o.isCorrect,
      }).toList(),
      'personal_note': personalNote,
      'difficulty_rating': difficultyRating?.value,
      'saved_at': savedAt.toIso8601String(),
      'review_count': reviewCount,
      'is_mastered': isMastered,
      'user_answer_option_id': userAnswerOptionId,
      'correct_option_id': correctOptionId,
      'explanation': explanation,
      'question_index': questionIndex,
      'is_pdf_question': isPdfQuestion,
      'pdf_url': pdfUrl,
      'next_review_at': nextReviewAt?.toIso8601String(),
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
      'interval_days': intervalDays,
    };
  }

  factory SavedQuestionEntity.fromJson(Map<String, dynamic> json) {
    return SavedQuestionEntity(
      id: json['id'] as String,
      questionId: json['question_id'] as String,
      examId: json['exam_id'] as String? ?? '',
      examTitle: json['exam_title'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      questionImageUrl: json['question_image_url'] as String?,
      options: (json['options'] as List<dynamic>? ?? []).map((o) {
        final optMap = o as Map<String, dynamic>;
        return QuestionOptionEntity(
          id: optMap['id'] as String,
          questionId: json['question_id'] as String,
          optionText: optMap['option_text'] as String? ?? '',
          sortOrder: optMap['sort_order'] as int? ?? 0,
          isCorrect: optMap['is_correct'] as bool? ?? false,
        );
      }).toList(),
      personalNote: json['personal_note'] as String?,
      difficultyRating: QuestionDifficultyRating.fromString(json['difficulty_rating'] as String?),
      savedAt: DateTime.tryParse(json['saved_at'] as String? ?? '') ?? DateTime.now(),
      reviewCount: json['review_count'] as int? ?? 0,
      isMastered: json['is_mastered'] as bool? ?? false,
      userAnswerOptionId: json['user_answer_option_id'] as String?,
      correctOptionId: json['correct_option_id'] as String?,
      explanation: json['explanation'] as String?,
      questionIndex: json['question_index'] as int?,
      isPdfQuestion: json['is_pdf_question'] as bool? ?? false,
      pdfUrl: json['pdf_url'] as String?,
      nextReviewAt: json['next_review_at'] != null ? DateTime.tryParse(json['next_review_at'] as String) : null,
      lastReviewedAt: json['last_reviewed_at'] != null ? DateTime.tryParse(json['last_reviewed_at'] as String) : null,
      intervalDays: json['interval_days'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
    id,
    questionId,
    examId,
    examTitle,
    personalNote,
    difficultyRating,
    reviewCount,
    isMastered,
    userAnswerOptionId,
    correctOptionId,
    questionIndex,
    isPdfQuestion,
    nextReviewAt,
    lastReviewedAt,
    intervalDays,
  ];
}
