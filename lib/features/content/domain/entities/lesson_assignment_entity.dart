import 'package:equatable/equatable.dart';
import 'content_entity.dart';
import 'file_attachment_entity.dart';

/// إمكانية وصول الطالب للدرس
enum LessonAccess {
  locked,
  unlocked,
}

/// حالة تقدم الطالب في الدرس
enum LessonProgress {
  notStarted,
  inProgress,
  videoCompleted,
  quizAvailable,
  quizFailed,
  completed,
}

/// مصدر فتح الدرس
enum UnlockSource {
  firstLesson,
  prerequisiteCompletion,
  manualOverride,
}

/// تمثيل درس واحد معيَّن لمجموعة محددة (صف من content_groups)
/// 
/// Video مستقل + Group Settings + حالة الطالب = LessonAssignment
class LessonAssignmentEntity extends Equatable {
  /// معرّف صف content_groups
  final String contentGroupId;

  /// معرّف الـ content (الفيديو / الدرس)
  final String contentId;

  /// معرّف المجموعة
  final String groupId;

  /// العنوان (من content.title)
  final String title;

  final String? description;

  final ContentType type;

  /// الترتيب داخل المجموعة
  final int sortOrder;

  /// معرّف PDF الخاص بهذه المجموعة (content_groups.file_id)
  final String? pdfFileId;
  final String? pdfFileName;
  final String? pdfStoragePath;

  /// الاختبار المرتبط بهذا الدرس
  final String? lessonExamId;
  final String? lessonExamTitle;

  /// درجة النجاح الفعالة (إما override أو default)
  final int effectivePassingScore;

  /// اختبار شرط لفتح هذا الدرس (prerequisite)
  final String? prerequisiteExamId;

  // ─── حالة الطالب (من الـ DB الموحد) ─────────────────────────────────

  final LessonAccess access;
  final LessonProgress progress;
  final UnlockSource? unlockSource;

  // ─── مقاييس التقدم ───────────────────────────────────────────

  /// نسبة التغطية الفعلية (Legitimate watched coverage 0-100)
  final double watchedCoveragePercent;

  /// آخر نقطة وقف عندها
  final int lastPositionSeconds;

  /// أبعد نقطة وصل إليها بشكل شرعي
  final int furthestLegitimatePositionSeconds;

  /// مدة الفيديو الكاملة
  final int videoDurationSeconds;

  /// هل أكمل الفيديو (من قاعدة البيانات)
  final bool videoCompleted;

  /// أفضل درجة للطالب في الاختبار المرتبط (null = لم يأخذه)
  final double? examBestScore;

  /// هل نجح في الاختبار بالدرجة المطلوبة
  final bool examPassed;

  /// هل تم فتحه يدوياً من المعلم
  final bool isManuallyUnlocked;

  const LessonAssignmentEntity({
    required this.contentGroupId,
    required this.contentId,
    required this.groupId,
    required this.title,
    this.description,
    this.type = ContentType.video,
    required this.sortOrder,
    this.pdfFileId,
    this.pdfFileName,
    this.pdfStoragePath,
    this.lessonExamId,
    this.lessonExamTitle,
    this.effectivePassingScore = 60,
    this.prerequisiteExamId,
    this.access = LessonAccess.locked,
    this.progress = LessonProgress.notStarted,
    this.unlockSource,
    this.watchedCoveragePercent = 0.0,
    this.lastPositionSeconds = 0,
    this.furthestLegitimatePositionSeconds = 0,
    this.videoDurationSeconds = 0,
    this.videoCompleted = false,
    this.examBestScore,
    this.examPassed = false,
    this.isManuallyUnlocked = false,
  });

  /// هل أكمل الطالب 90% فعلياً؟
  bool get hasWatched90Percent =>
      videoDurationSeconds > 0
          ? furthestLegitimatePositionSeconds >= (videoDurationSeconds * 0.90).floor()
          : videoCompleted;

  /// هل يوجد PDF مرتبط بهذا الدرس في هذه المجموعة؟
  bool get hasPdf => pdfFileId != null && pdfFileName != null;

  /// هل يوجد اختبار مرتبط بهذا الدرس؟
  bool get hasLessonExam => lessonExamId != null;

  /// [status] computed based on Access and Progress for backward compatibility with UI components.
  /// New UI components should use `access` and `progress` directly.
  LessonProgress get status => progress;
  bool get isLocked => access == LessonAccess.locked;

  /// يعتبر الدرس منتهياً فقط إذا اكتمل تقدمه فعلياً (الفتح اليدوي يغير الوصول فقط ولا ينهي الدرس).
  bool get isEffectivelyCompleted => progress == LessonProgress.completed;

  /// تحويل كائن التعيين إلى ContentEntity للتوافق مع مكونات العرض (StudentLessonTile)
  ContentEntity toContentEntity() {
    return ContentEntity(
      id: contentId,
      tenantId: '',
      groupId: groupId,
      title: title,
      description: description,
      type: type,
      status: ContentStatus.published,
      sortOrder: sortOrder,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      videoId: type == ContentType.video ? contentId : null,
      associatedExamId: lessonExamId,
      associatedExamTitle: lessonExamTitle,
      prerequisiteExamId: prerequisiteExamId,
      isLocked: isLocked,
      isVideoCompleted: isEffectivelyCompleted || videoCompleted,
      videoProgressPercentage: watchedCoveragePercent,
      isExamPassed: isEffectivelyCompleted || examPassed,
      file: pdfFileId != null
          ? FileAttachmentEntity(
              id: pdfFileId!,
              tenantId: '',
              contentId: contentId,
              fileName: pdfFileName ?? '',
              storagePath: pdfStoragePath ?? '',
              mimeType: 'application/pdf',
              fileSize: 0,
              createdAt: DateTime.now(),
            )
          : null,
    );
  }

  LessonAssignmentEntity copyWith({
    String? contentGroupId,
    String? contentId,
    String? groupId,
    String? title,
    String? description,
    ContentType? type,
    int? sortOrder,
    String? pdfFileId,
    String? pdfFileName,
    String? pdfStoragePath,
    String? lessonExamId,
    String? lessonExamTitle,
    int? effectivePassingScore,
    String? prerequisiteExamId,
    LessonAccess? access,
    LessonProgress? progress,
    UnlockSource? unlockSource,
    double? watchedCoveragePercent,
    int? lastPositionSeconds,
    int? furthestLegitimatePositionSeconds,
    int? videoDurationSeconds,
    bool? videoCompleted,
    double? examBestScore,
    bool? examPassed,
    bool? isManuallyUnlocked,
  }) {
    return LessonAssignmentEntity(
      contentGroupId: contentGroupId ?? this.contentGroupId,
      contentId: contentId ?? this.contentId,
      groupId: groupId ?? this.groupId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      sortOrder: sortOrder ?? this.sortOrder,
      pdfFileId: pdfFileId ?? this.pdfFileId,
      pdfFileName: pdfFileName ?? this.pdfFileName,
      pdfStoragePath: pdfStoragePath ?? this.pdfStoragePath,
      lessonExamId: lessonExamId ?? this.lessonExamId,
      lessonExamTitle: lessonExamTitle ?? this.lessonExamTitle,
      effectivePassingScore:
          effectivePassingScore ?? this.effectivePassingScore,
      prerequisiteExamId: prerequisiteExamId ?? this.prerequisiteExamId,
      access: access ?? this.access,
      progress: progress ?? this.progress,
      unlockSource: unlockSource ?? this.unlockSource,
      watchedCoveragePercent:
          watchedCoveragePercent ?? this.watchedCoveragePercent,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      furthestLegitimatePositionSeconds:
          furthestLegitimatePositionSeconds ??
              this.furthestLegitimatePositionSeconds,
      videoDurationSeconds: videoDurationSeconds ?? this.videoDurationSeconds,
      videoCompleted: videoCompleted ?? this.videoCompleted,
      examBestScore: examBestScore ?? this.examBestScore,
      examPassed: examPassed ?? this.examPassed,
      isManuallyUnlocked: isManuallyUnlocked ?? this.isManuallyUnlocked,
    );
  }

  factory LessonAssignmentEntity.fromJson(Map<String, dynamic> json) {
    return LessonAssignmentEntity(
      contentGroupId: json['content_group_id'] as String? ?? '',
      contentId: json['content_id'] as String,
      groupId: json['group_id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      type: ContentType.values.firstWhere(
        (e) => e.value == (json['content_type'] as String?),
        orElse: () => ContentType.video,
      ),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      pdfFileId: json['pdf_file_id'] as String?,
      pdfFileName: json['pdf_file_name'] as String?,
      pdfStoragePath: json['pdf_storage_path'] as String?,
      lessonExamId: json['lesson_exam_id'] as String?,
      lessonExamTitle: json['lesson_exam_title'] as String?,
      effectivePassingScore:
          (json['effective_passing_score'] as num?)?.toInt() ?? 60,
      prerequisiteExamId: json['prerequisite_exam_id'] as String?,
      access: _parseAccess(json['access_state'] as String?),
      progress: _parseProgress(json['progress_state'] as String?),
      unlockSource: _parseUnlockSource(json['unlock_source'] as String?),
      watchedCoveragePercent:
          (json['watched_coverage_percent'] as num?)?.toDouble() ?? 0.0,
      lastPositionSeconds: (json['last_position_seconds'] as num?)?.toInt() ?? 0,
      furthestLegitimatePositionSeconds:
          (json['furthest_legitimate_position'] as num?)?.toInt() ?? 0,
      videoDurationSeconds: (json['video_duration_seconds'] as num?)?.toInt() ?? 0,
      videoCompleted: json['video_completed'] as bool? ?? false,
      examBestScore: (json['exam_best_score'] as num?)?.toDouble(),
      examPassed: json['exam_passed'] as bool? ?? false,
      isManuallyUnlocked: json['is_manually_unlocked'] as bool? ?? false,
    );
  }

  static LessonAccess _parseAccess(String? val) {
    if (val == 'unlocked') return LessonAccess.unlocked;
    return LessonAccess.locked;
  }

  static LessonProgress _parseProgress(String? val) {
    switch (val) {
      case 'in_progress':
        return LessonProgress.inProgress;
      case 'video_completed':
        return LessonProgress.videoCompleted;
      case 'quiz_available':
        return LessonProgress.quizAvailable;
      case 'quiz_failed':
        return LessonProgress.quizFailed;
      case 'completed':
        return LessonProgress.completed;
      case 'not_started':
      default:
        return LessonProgress.notStarted;
    }
  }

  static UnlockSource? _parseUnlockSource(String? val) {
    switch (val) {
      case 'first_lesson':
        return UnlockSource.firstLesson;
      case 'prerequisite_completion':
        return UnlockSource.prerequisiteCompletion;
      case 'manual_override':
        return UnlockSource.manualOverride;
      default:
        return null;
    }
  }

  @override
  List<Object?> get props => [
        contentGroupId,
        contentId,
        groupId,
        title,
        description,
        type,
        sortOrder,
        pdfFileId,
        pdfFileName,
        pdfStoragePath,
        lessonExamId,
        lessonExamTitle,
        effectivePassingScore,
        prerequisiteExamId,
        access,
        progress,
        unlockSource,
        watchedCoveragePercent,
        lastPositionSeconds,
        furthestLegitimatePositionSeconds,
        videoDurationSeconds,
        videoCompleted,
        examBestScore,
        examPassed,
        isManuallyUnlocked,
      ];
}
