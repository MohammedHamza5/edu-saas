import 'package:equatable/equatable.dart';

enum QuestionType {
  multipleChoice,
  trueFalse;

  static QuestionType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'true_false':
        return QuestionType.trueFalse;
      case 'multiple_choice':
      default:
        return QuestionType.multipleChoice;
    }
  }

  String get value {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.trueFalse:
        return 'true_false';
    }
  }

  String get labelAr {
    switch (this) {
      case QuestionType.multipleChoice:
        return 'اختيار من متعدد';
      case QuestionType.trueFalse:
        return 'صواب أو خطأ';
    }
  }
}

enum ExamStatus {
  draft,
  published,
  archived;

  static ExamStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'published':
        return ExamStatus.published;
      case 'archived':
        return ExamStatus.archived;
      case 'draft':
      default:
        return ExamStatus.draft;
    }
  }

  String get value => name;

  String get labelAr {
    switch (this) {
      case ExamStatus.draft:
        return 'مسودة';
      case ExamStatus.published:
        return 'منشور (مجمد)';
      case ExamStatus.archived:
        return 'مؤرشف';
    }
  }
}

enum AttemptStatus {
  inProgress,
  submitted,
  expired;

  static AttemptStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'submitted':
        return AttemptStatus.submitted;
      case 'expired':
        return AttemptStatus.expired;
      case 'in_progress':
      default:
        return AttemptStatus.inProgress;
    }
  }

  String get value {
    switch (this) {
      case AttemptStatus.inProgress:
        return 'in_progress';
      case AttemptStatus.submitted:
        return 'submitted';
      case AttemptStatus.expired:
        return 'expired';
    }
  }

  String get labelAr {
    switch (this) {
      case AttemptStatus.inProgress:
        return 'قيد الأداء';
      case AttemptStatus.submitted:
        return 'تم التسليم';
      case AttemptStatus.expired:
        return 'انتهى الوقت';
    }
  }
}

enum ExamSubmissionReason {
  studentSubmitted,
  timeExpired,
  forcedExit,
  securityViolations,
  tabClosed,
  systemTimeout;

  static ExamSubmissionReason fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'time_expired':
        return ExamSubmissionReason.timeExpired;
      case 'forced_exit':
        return ExamSubmissionReason.forcedExit;
      case 'security_violations':
        return ExamSubmissionReason.securityViolations;
      case 'tab_closed':
        return ExamSubmissionReason.tabClosed;
      case 'system_timeout':
        return ExamSubmissionReason.systemTimeout;
      case 'student_submitted':
      default:
        return ExamSubmissionReason.studentSubmitted;
    }
  }

  String get value {
    switch (this) {
      case ExamSubmissionReason.studentSubmitted:
        return 'student_submitted';
      case ExamSubmissionReason.timeExpired:
        return 'time_expired';
      case ExamSubmissionReason.forcedExit:
        return 'forced_exit';
      case ExamSubmissionReason.securityViolations:
        return 'security_violations';
      case ExamSubmissionReason.tabClosed:
        return 'tab_closed';
      case ExamSubmissionReason.systemTimeout:
        return 'system_timeout';
    }
  }


}

class QuestionOptionEntity extends Equatable {
  final String id;
  final String questionId;
  final String optionText;
  final int sortOrder;
  final bool? isCorrect; // Hidden from student responses
  final String? imageUrl;
  final Map<String, dynamic>? imageMeta;

  const QuestionOptionEntity({
    required this.id,
    required this.questionId,
    required this.optionText,
    this.sortOrder = 0,
    this.isCorrect,
    this.imageUrl,
    this.imageMeta,
  });

  QuestionOptionEntity copyWith({
    String? id,
    String? questionId,
    String? optionText,
    int? sortOrder,
    bool? isCorrect,
    String? imageUrl,
    Map<String, dynamic>? imageMeta,
  }) {
    return QuestionOptionEntity(
      id: id ?? this.id,
      questionId: questionId ?? this.questionId,
      optionText: optionText ?? this.optionText,
      sortOrder: sortOrder ?? this.sortOrder,
      isCorrect: isCorrect ?? this.isCorrect,
      imageUrl: imageUrl ?? this.imageUrl,
      imageMeta: imageMeta ?? this.imageMeta,
    );
  }

  @override
  List<Object?> get props => [
    id,
    questionId,
    optionText,
    sortOrder,
    isCorrect,
    imageUrl,
    imageMeta,
  ];
}

class ExamContextEntity extends Equatable {
  final String id;
  final String examVersionId;
  final String? title;
  final String? contextText;
  final String? imageUrl;
  final Map<String, dynamic>? imageMeta;
  final int sortOrder;

  const ExamContextEntity({
    required this.id,
    required this.examVersionId,
    this.title,
    this.contextText,
    this.imageUrl,
    this.imageMeta,
    this.sortOrder = 0,
  });

  @override
  List<Object?> get props => [
    id,
    examVersionId,
    title,
    contextText,
    imageUrl,
    imageMeta,
    sortOrder,
  ];
}

class ExamQuestionEntity extends Equatable {
  final String id;
  final String examVersionId;
  final String questionText;
  final QuestionType questionType;
  final int points;
  final int sortOrder;
  final List<QuestionOptionEntity> options;
  final String? imageUrl;
  final Map<String, dynamic>? imageMeta;
  final String? contextId;

  const ExamQuestionEntity({
    required this.id,
    required this.examVersionId,
    required this.questionText,
    this.questionType = QuestionType.multipleChoice,
    this.points = 1,
    this.sortOrder = 0,
    this.options = const [],
    this.imageUrl,
    this.imageMeta,
    this.contextId,
  });

  ExamQuestionEntity copyWith({
    String? id,
    String? examVersionId,
    String? questionText,
    QuestionType? questionType,
    int? points,
    int? sortOrder,
    List<QuestionOptionEntity>? options,
    String? imageUrl,
    Map<String, dynamic>? imageMeta,
    String? contextId,
  }) {
    return ExamQuestionEntity(
      id: id ?? this.id,
      examVersionId: examVersionId ?? this.examVersionId,
      questionText: questionText ?? this.questionText,
      questionType: questionType ?? this.questionType,
      points: points ?? this.points,
      sortOrder: sortOrder ?? this.sortOrder,
      options: options ?? this.options,
      imageUrl: imageUrl ?? this.imageUrl,
      imageMeta: imageMeta ?? this.imageMeta,
      contextId: contextId ?? this.contextId,
    );
  }

  @override
  List<Object?> get props => [
    id,
    examVersionId,
    questionText,
    questionType,
    points,
    sortOrder,
    options,
    imageUrl,
    imageMeta,
    contextId,
  ];
}

class ExamVersionEntity extends Equatable {
  final String id;
  final String examId;
  final int versionNumber;
  final ExamStatus status;
  final DateTime createdAt;
  final DateTime? publishedAt;
  final List<ExamQuestionEntity> questions;
  final List<ExamContextEntity> contexts;

  const ExamVersionEntity({
    required this.id,
    required this.examId,
    this.versionNumber = 1,
    this.status = ExamStatus.draft,
    required this.createdAt,
    this.publishedAt,
    this.questions = const [],
    this.contexts = const [],
  });

  bool get isPublished => status == ExamStatus.published;
  bool get isDraft => status == ExamStatus.draft;

  int get totalPoints => questions.fold(0, (sum, q) => sum + q.points);

  ExamVersionEntity copyWith({
    String? id,
    String? examId,
    int? versionNumber,
    ExamStatus? status,
    DateTime? createdAt,
    DateTime? publishedAt,
    List<ExamQuestionEntity>? questions,
    List<ExamContextEntity>? contexts,
  }) {
    return ExamVersionEntity(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      versionNumber: versionNumber ?? this.versionNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      publishedAt: publishedAt ?? this.publishedAt,
      questions: questions ?? this.questions,
      contexts: contexts ?? this.contexts,
    );
  }

  @override
  List<Object?> get props => [
    id,
    examId,
    versionNumber,
    status,
    createdAt,
    publishedAt,
    questions,
    contexts,
  ];
}

class ExamAnswerEntity extends Equatable {
  final String id;
  final String attemptId;
  final String questionId;
  final String? selectedOptionId;
  final bool? isCorrect;
  final double? pointsEarned;
  final DateTime answeredAt;

  const ExamAnswerEntity({
    required this.id,
    required this.attemptId,
    required this.questionId,
    this.selectedOptionId,
    this.isCorrect,
    this.pointsEarned,
    required this.answeredAt,
  });

  @override
  List<Object?> get props => [
    id,
    attemptId,
    questionId,
    selectedOptionId,
    isCorrect,
    pointsEarned,
    answeredAt,
  ];
}

class ExamAttemptEntity extends Equatable {
  final String id;
  final String examId;
  final String examVersionId;
  final String studentId;
  final String? studentName;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final AttemptStatus status;
  final ExamSubmissionReason submissionReason;
  final int? score;
  final double? percentage;
  final int? remainingSeconds;
  final int? answeredQuestionsCount;
  final List<ExamAnswerEntity> answers;
  final List<ExamQuestionEntity> questions;
  final Map<String, int> questionTimes;
  final Set<String> flaggedGuesses;

  const ExamAttemptEntity({
    required this.id,
    required this.examId,
    required this.examVersionId,
    required this.studentId,
    this.studentName,
    required this.startedAt,
    this.submittedAt,
    this.status = AttemptStatus.inProgress,
    this.submissionReason = ExamSubmissionReason.studentSubmitted,
    this.score,
    this.percentage,
    this.remainingSeconds,
    this.answeredQuestionsCount,
    this.answers = const [],
    this.questions = const [],
    this.questionTimes = const {},
    this.flaggedGuesses = const {},
  });

  int get answeredCount {
    if (answeredQuestionsCount != null) return answeredQuestionsCount!;
    if (answers.isNotEmpty) {
      return answers.where((a) => a.selectedOptionId != null).length;
    }
    return 0;
  }

  bool get isInProgress => status == AttemptStatus.inProgress;
  bool get isSubmitted => status == AttemptStatus.submitted;
  bool get isExpired => status == AttemptStatus.expired;

  bool isPassed(int? passingScore) {
    if (passingScore == null || score == null) return true;
    return score! >= passingScore;
  }

  ExamAttemptEntity copyWith({
    String? id,
    String? examId,
    String? examVersionId,
    String? studentId,
    String? studentName,
    DateTime? startedAt,
    DateTime? submittedAt,
    AttemptStatus? status,
    ExamSubmissionReason? submissionReason,
    int? score,
    double? percentage,
    int? remainingSeconds,
    int? answeredQuestionsCount,
    List<ExamAnswerEntity>? answers,
    List<ExamQuestionEntity>? questions,
    Map<String, int>? questionTimes,
    Set<String>? flaggedGuesses,
  }) {
    return ExamAttemptEntity(
      id: id ?? this.id,
      examId: examId ?? this.examId,
      examVersionId: examVersionId ?? this.examVersionId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      status: status ?? this.status,
      submissionReason: submissionReason ?? this.submissionReason,
      score: score ?? this.score,
      percentage: percentage ?? this.percentage,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      answeredQuestionsCount:
          answeredQuestionsCount ?? this.answeredQuestionsCount,
      answers: answers ?? this.answers,
      questions: questions ?? this.questions,
      questionTimes: questionTimes ?? this.questionTimes,
      flaggedGuesses: flaggedGuesses ?? this.flaggedGuesses,
    );
  }

  @override
  List<Object?> get props => [
    id,
    examId,
    examVersionId,
    studentId,
    studentName,
    startedAt,
    submittedAt,
    status,
    submissionReason,
    score,
    percentage,
    remainingSeconds,
    answeredQuestionsCount,
    answers,
    questions,
    questionTimes,
    flaggedGuesses,
  ];
}

class ExamEntity extends Equatable {
  final String id;
  final String contentId;
  final String tenantId;
  final String groupId;
  final String? groupName;
  final String title;
  final int durationMinutes;
  final int maxScore;
  final int? passingScore;
  final bool shuffleQuestions;
  final bool showResult;
  final bool allowRetake;
  final DateTime? startAt;
  final DateTime? endAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ExamVersionEntity? activeVersion;
  final int attemptsCount;
  final int questionsCount;
  final ExamAttemptEntity? myLatestAttempt;
  final int? myBestScore;
  final bool isLectureExam;
  final String? linkedLessonId;
  final String? linkedLessonTitle;
  final String? folderId;
  final String? folderName;
  final String? folderColor;
  final String? pdfFileId;
  final String? pdfFileName;
  final int? pdfFileSize;
  final String? pdfStoragePath;
  final String? pdfStorageProvider;

  const ExamEntity({
    required this.id,
    required this.contentId,
    required this.tenantId,
    required this.groupId,
    this.groupName,
    required this.title,
    this.durationMinutes = 60,
    this.maxScore = 100,
    this.passingScore,
    this.shuffleQuestions = false,
    this.showResult = true,
    this.allowRetake = false,
    this.startAt,
    this.endAt,
    required this.createdAt,
    required this.updatedAt,
    this.activeVersion,
    this.attemptsCount = 0,
    this.questionsCount = 0,
    this.myLatestAttempt,
    this.myBestScore,
    this.isLectureExam = false,
    this.linkedLessonId,
    this.linkedLessonTitle,
    this.folderId,
    this.folderName,
    this.folderColor,
    this.pdfFileId,
    this.pdfFileName,
    this.pdfFileSize,
    this.pdfStoragePath,
    this.pdfStorageProvider,
  });

  bool get hasAttachedPdf =>
      (pdfFileId != null && pdfFileId!.isNotEmpty) ||
      (pdfStoragePath != null && pdfStoragePath!.isNotEmpty);

  int get totalQuestions => questionsCount > 0
      ? questionsCount
      : (activeVersion?.questions.length ?? 0);

  bool get hasAttempted => myLatestAttempt != null || attemptsCount > 0;
  bool get isUntimed => durationMinutes <= 0;

  bool get hasPassed =>
      myBestScore != null &&
      (passingScore == null || myBestScore! >= passingScore!);

  bool get hasActiveAttempt {
    if (myLatestAttempt == null) return false;
    if (!myLatestAttempt!.isInProgress) return false;
    // An untimed exam is always active while in progress
    if (isUntimed) return true;
    final elapsedMinutes = DateTime.now().toUtc()
        .difference(myLatestAttempt!.startedAt.toUtc())
        .inMinutes;
    if (elapsedMinutes < 0) return true;
    return elapsedMinutes < (durationMinutes + 5);
  }

  bool get canTakeExam {
    if (!hasAttempted) return true;
    if (hasActiveAttempt) return true; // Resume
    return allowRetake;
  }

  bool get isFullyCompleted {
    if (myBestScore != null && !hasActiveAttempt) return true;
    return hasAttempted && (myLatestAttempt?.isSubmitted == true) && !hasActiveAttempt;
  }

  int get solvedQuestionsCount {
    if (isFullyCompleted) return totalQuestions;
    final att = myLatestAttempt;
    if (att == null) return 0;
    if (att.answeredQuestionsCount != null && att.answeredQuestionsCount! > 0) {
      return att.answeredQuestionsCount!;
    }
    if (att.answers.isNotEmpty) {
      return att.answers.where((a) => a.selectedOptionId != null).length;
    }
    return 0;
  }

  double get completionProgress {
    if (isFullyCompleted) return 1.0;
    if (totalQuestions <= 0) return 0.0;
    final solved = solvedQuestionsCount;
    return (solved / totalQuestions).clamp(0.0, 1.0);
  }

  bool get isPublished => activeVersion?.isPublished ?? (activeVersion != null);
  bool get isDraft => !isPublished;
  bool get canEditQuestions => true;
  bool get isLinkedToLesson => linkedLessonId != null && linkedLessonId!.isNotEmpty;
  bool get isGeneralExam => !isLectureExam;
  String? get description => null;

  ExamEntity copyWith({
    String? id,
    String? contentId,
    String? tenantId,
    String? groupId,
    String? groupName,
    String? title,
    int? durationMinutes,
    int? maxScore,
    int? passingScore,
    bool? shuffleQuestions,
    bool? showResult,
    bool? allowRetake,
    DateTime? startAt,
    DateTime? endAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    ExamVersionEntity? activeVersion,
    int? attemptsCount,
    int? questionsCount,
    ExamAttemptEntity? myLatestAttempt,
    int? myBestScore,
    bool? isLectureExam,
    String? linkedLessonId,
    String? linkedLessonTitle,
    String? folderId,
    String? folderName,
    String? folderColor,
    String? pdfFileId,
    String? pdfFileName,
    int? pdfFileSize,
    String? pdfStoragePath,
    String? pdfStorageProvider,
    bool clearPdfFile = false,
  }) {
    return ExamEntity(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      tenantId: tenantId ?? this.tenantId,
      groupId: groupId ?? this.groupId,
      groupName: groupName ?? this.groupName,
      title: title ?? this.title,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      maxScore: maxScore ?? this.maxScore,
      passingScore: passingScore ?? this.passingScore,
      shuffleQuestions: shuffleQuestions ?? this.shuffleQuestions,
      showResult: showResult ?? this.showResult,
      allowRetake: allowRetake ?? this.allowRetake,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activeVersion: activeVersion ?? this.activeVersion,
      attemptsCount: attemptsCount ?? this.attemptsCount,
      questionsCount: questionsCount ?? this.questionsCount,
      myLatestAttempt: myLatestAttempt ?? this.myLatestAttempt,
      myBestScore: myBestScore ?? this.myBestScore,
      isLectureExam: isLectureExam ?? this.isLectureExam,
      linkedLessonId: linkedLessonId ?? this.linkedLessonId,
      linkedLessonTitle: linkedLessonTitle ?? this.linkedLessonTitle,
      folderId: folderId ?? this.folderId,
      folderName: folderName ?? this.folderName,
      folderColor: folderColor ?? this.folderColor,
      pdfFileId: clearPdfFile ? null : (pdfFileId ?? this.pdfFileId),
      pdfFileName: clearPdfFile ? null : (pdfFileName ?? this.pdfFileName),
      pdfFileSize: clearPdfFile ? null : (pdfFileSize ?? this.pdfFileSize),
      pdfStoragePath: clearPdfFile ? null : (pdfStoragePath ?? this.pdfStoragePath),
      pdfStorageProvider: clearPdfFile ? null : (pdfStorageProvider ?? this.pdfStorageProvider),
    );
  }

  @override
  List<Object?> get props => [
    id,
    contentId,
    tenantId,
    groupId,
    groupName,
    title,
    durationMinutes,
    maxScore,
    passingScore,
    shuffleQuestions,
    showResult,
    allowRetake,
    startAt,
    endAt,
    createdAt,
    updatedAt,
    activeVersion,
    attemptsCount,
    questionsCount,
    myLatestAttempt,
    myBestScore,
    isLectureExam,
    linkedLessonId,
    linkedLessonTitle,
    folderId,
    folderName,
    folderColor,
    pdfFileId,
    pdfFileName,
    pdfFileSize,
    pdfStoragePath,
    pdfStorageProvider,
  ];
}
