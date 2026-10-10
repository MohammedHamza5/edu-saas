import 'package:equatable/equatable.dart';

/// تمثيل اختبار واحد مرتبط بمحاضرة تعليمية (علاقة 1-to-Many بين الدرس والاختبارات)
class AttachedLessonExamEntity extends Equatable {
  /// معرّف الاختبار
  final String examId;

  /// عنوان الاختبار
  final String examTitle;

  /// ترتيب ظهور الاختبار بالنسبة لبقية اختبارات الدرس
  final int sortOrder;

  /// هل اجتياز هذا الاختبار إلزامي لفتح الدرس التالي في التعاقب الأكاديمي
  final bool isRequired;

  /// درجة النجاح المقررة (النسبة المئوية)
  final int passingScore;

  /// أفضل درجة حققها الطالب (null إذا لم يقم بأي محاولة بعد)
  final double? bestScore;

  /// هل نجح الطالب في هذا الاختبار
  final bool isPassed;

  /// عدد محاولات الطالب
  final int attemptCount;

  /// حالة آخر محاولة ('in_progress' | 'submitted' | 'completed' | 'expired')
  final String? latestAttemptStatus;

  const AttachedLessonExamEntity({
    required this.examId,
    required this.examTitle,
    this.sortOrder = 0,
    this.isRequired = true,
    this.passingScore = 60,
    this.bestScore,
    this.isPassed = false,
    this.attemptCount = 0,
    this.latestAttemptStatus,
  });

  factory AttachedLessonExamEntity.fromJson(Map<String, dynamic> json) {
    return AttachedLessonExamEntity(
      examId: json['exam_id'] as String? ?? '',
      examTitle: json['exam_title'] as String? ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isRequired: json['is_required'] as bool? ?? true,
      passingScore: (json['passing_score'] as num?)?.toInt() ?? 60,
      bestScore: (json['best_score'] as num?)?.toDouble(),
      isPassed: json['is_passed'] as bool? ?? false,
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
      latestAttemptStatus: json['latest_attempt_status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exam_id': examId,
      'exam_title': examTitle,
      'sort_order': sortOrder,
      'is_required': isRequired,
      'passing_score': passingScore,
      if (bestScore != null) 'best_score': bestScore,
      'is_passed': isPassed,
      'attempt_count': attemptCount,
      if (latestAttemptStatus != null)
        'latest_attempt_status': latestAttemptStatus,
    };
  }

  AttachedLessonExamEntity copyWith({
    String? examId,
    String? examTitle,
    int? sortOrder,
    bool? isRequired,
    int? passingScore,
    double? bestScore,
    bool? isPassed,
    int? attemptCount,
    String? latestAttemptStatus,
  }) {
    return AttachedLessonExamEntity(
      examId: examId ?? this.examId,
      examTitle: examTitle ?? this.examTitle,
      sortOrder: sortOrder ?? this.sortOrder,
      isRequired: isRequired ?? this.isRequired,
      passingScore: passingScore ?? this.passingScore,
      bestScore: bestScore ?? this.bestScore,
      isPassed: isPassed ?? this.isPassed,
      attemptCount: attemptCount ?? this.attemptCount,
      latestAttemptStatus: latestAttemptStatus ?? this.latestAttemptStatus,
    );
  }

  @override
  List<Object?> get props => [
    examId,
    examTitle,
    sortOrder,
    isRequired,
    passingScore,
    bestScore,
    isPassed,
    attemptCount,
    latestAttemptStatus,
  ];
}
