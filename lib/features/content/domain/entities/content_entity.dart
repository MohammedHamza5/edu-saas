import 'package:equatable/equatable.dart';
import 'file_attachment_entity.dart';

import 'package:flutter/widgets.dart';
import '../../../../core/extensions/localized_context_extension.dart';

/// Supported types of content in Educational SaaS V1
enum ContentType {
  video,
  pdf,
  image,
  assignment,
  exam;

  static ContentType fromString(String val) {
    return switch (val.toLowerCase()) {
      'video' => ContentType.video,
      'pdf' => ContentType.pdf,
      'image' => ContentType.image,
      'assignment' => ContentType.assignment,
      'exam' => ContentType.exam,
      _ => ContentType.pdf,
    };
  }

  String get value => name;

  String get labelAr {
    return switch (this) {
      ContentType.video => 'فيديو تعليمي',
      ContentType.pdf => 'مذكرة / PDF',
      ContentType.image => 'صورة توضيحية',
      ContentType.assignment => 'واجب دراسي',
      ContentType.exam => 'امتحان تقييمي',
    };
  }

  String localizedLabel(BuildContext context) {
    return switch (this) {
      ContentType.video => context.l10n.contentTypeVideo,
      ContentType.pdf => context.l10n.contentTypePdf,
      ContentType.image => context.l10n.contentTypeImage,
      ContentType.assignment => context.l10n.contentTypeAssignment,
      ContentType.exam => context.l10n.contentTypeExam,
    };
  }
}

/// Lifecycle status of content
enum ContentStatus {
  draft,
  published,
  archived;

  static ContentStatus fromString(String val) {
    return switch (val.toLowerCase()) {
      'published' => ContentStatus.published,
      'archived' => ContentStatus.archived,
      _ => ContentStatus.draft,
    };
  }

  String get value => name;

  String get labelAr {
    return switch (this) {
      ContentStatus.draft => 'مسودة',
      ContentStatus.published => 'منشور',
      ContentStatus.archived => 'مؤرشف',
    };
  }

  String localizedLabel(BuildContext context) {
    return switch (this) {
      ContentStatus.draft => context.l10n.draftBadge,
      ContentStatus.published => context.l10n.publishedBadge,
      ContentStatus.archived => context.l10n.statusArchived,
    };
  }
}

/// Main Academic Content Entity
class ContentEntity extends Equatable {
  final String id;
  final String tenantId;
  final String? groupId;
  final String title;
  final String? description;
  final ContentType type;
  final ContentStatus status;
  final int sortOrder;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final FileAttachmentEntity? file;

  /// Video metadata — populated when type == ContentType.video and a
  /// video record exists in the `videos` table for this content item.
  final String? videoId;          // UUID from videos.id
  final String? videoStatus;      // 'uploading' | 'processing' | 'ready' | 'failed'
  final String? videoProviderId;  // Bunny Stream GUID or YouTube Video ID
  final String? videoProvider;    // 'youtube' | 'bunny'

  /// Multi-group assignments (from content_groups junction)
  final List<String> assignedGroupIds;
  final List<String> assignedGroupNames;

  /// Integrated Lesson Unit & Prerequisite Progression
  final String? associatedExamId;     // The quiz for this lesson unit
  final String? associatedExamTitle;
  final String? prerequisiteExamId;   // Prerequisite exam that must be passed
  final String? prerequisiteExamTitle;
  final int? prerequisitePassingScore;
  final bool isLocked;                // True if student has not passed prerequisite exam
  final bool isVideoCompleted;        // True if student completed video playback (>=90%)
  final double videoProgressPercentage; // Student live progress (0.0 to 100.0)
  final bool isExamPassed;            // True if student passed associated exam

  const ContentEntity({
    required this.id,
    required this.tenantId,
    this.groupId,
    required this.title,
    this.description,
    required this.type,
    required this.status,
    this.sortOrder = 0,
    this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.file,
    this.videoId,
    this.videoStatus,
    this.videoProviderId,
    this.videoProvider,
    this.assignedGroupIds = const [],
    this.assignedGroupNames = const [],
    this.associatedExamId,
    this.associatedExamTitle,
    this.prerequisiteExamId,
    this.prerequisiteExamTitle,
    this.prerequisitePassingScore,
    this.isLocked = false,
    this.isVideoCompleted = false,
    this.videoProgressPercentage = 0.0,
    this.isExamPassed = false,
  });

  bool get isPublished => status == ContentStatus.published;
  bool get isDraft => status == ContentStatus.draft;
  bool get isArchived => status == ContentStatus.archived;
  bool get hasAttachment => file != null;

  /// True when in Central Bank without any assigned groups
  bool get isUnassigned =>
      (groupId == null || groupId!.isEmpty) && assignedGroupIds.isEmpty;

  /// True when a video has been successfully linked to this content item.
  bool get hasVideo => videoId != null;

  /// True when video is fully processed and ready for playback.
  bool get isVideoReady => videoStatus == 'ready';

  /// True when video is still being processed by Bunny Stream.
  bool get isVideoProcessing =>
      videoStatus == 'uploading' || videoStatus == 'processing';

  bool get isYouTube => videoProvider == 'youtube';
  bool get isBunny => videoProvider == 'bunny';

  /// True when the student has completed the entire lecture unit
  /// (both video watched >=90% and associated exam passed, or whatever is required).
  bool get isCompleted =>
      (videoId == null || isVideoCompleted) &&
      (associatedExamId == null || isExamPassed);

  /// True when student can take the associated exam (must have watched video first)
  bool get canTakeExam => !isLocked && (videoId == null || isVideoCompleted);

  ContentEntity copyWith({
    String? id,
    String? tenantId,
    Object? groupId = _sentinel,
    String? title,
    String? description,
    ContentType? type,
    ContentStatus? status,
    int? sortOrder,
    DateTime? publishedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    FileAttachmentEntity? file,
    Object? videoId = _sentinel,
    Object? videoStatus = _sentinel,
    Object? videoProviderId = _sentinel,
    Object? videoProvider = _sentinel,
    List<String>? assignedGroupIds,
    List<String>? assignedGroupNames,
    Object? associatedExamId = _sentinel,
    Object? associatedExamTitle = _sentinel,
    Object? prerequisiteExamId = _sentinel,
    Object? prerequisiteExamTitle = _sentinel,
    Object? prerequisitePassingScore = _sentinel,
    bool? isLocked,
    bool? isVideoCompleted,
    double? videoProgressPercentage,
    bool? isExamPassed,
  }) {
    return ContentEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      groupId: groupId == _sentinel ? this.groupId : groupId as String?,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      sortOrder: sortOrder ?? this.sortOrder,
      publishedAt: publishedAt ?? this.publishedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      file: file ?? this.file,
      videoId: videoId == _sentinel ? this.videoId : videoId as String?,
      videoStatus: videoStatus == _sentinel ? this.videoStatus : videoStatus as String?,
      videoProviderId: videoProviderId == _sentinel ? this.videoProviderId : videoProviderId as String?,
      videoProvider: videoProvider == _sentinel ? this.videoProvider : videoProvider as String?,
      assignedGroupIds: assignedGroupIds ?? this.assignedGroupIds,
      assignedGroupNames: assignedGroupNames ?? this.assignedGroupNames,
      associatedExamId: associatedExamId == _sentinel ? this.associatedExamId : associatedExamId as String?,
      associatedExamTitle: associatedExamTitle == _sentinel ? this.associatedExamTitle : associatedExamTitle as String?,
      prerequisiteExamId: prerequisiteExamId == _sentinel ? this.prerequisiteExamId : prerequisiteExamId as String?,
      prerequisiteExamTitle: prerequisiteExamTitle == _sentinel ? this.prerequisiteExamTitle : prerequisiteExamTitle as String?,
      prerequisitePassingScore: prerequisitePassingScore == _sentinel ? this.prerequisitePassingScore : prerequisitePassingScore as int?,
      isLocked: isLocked ?? this.isLocked,
      isVideoCompleted: isVideoCompleted ?? this.isVideoCompleted,
      videoProgressPercentage: videoProgressPercentage ?? this.videoProgressPercentage,
      isExamPassed: isExamPassed ?? this.isExamPassed,
    );
  }

  static const Object _sentinel = Object();

  @override
  List<Object?> get props => [
        id,
        tenantId,
        groupId,
        title,
        description,
        type,
        status,
        sortOrder,
        publishedAt,
        createdAt,
        updatedAt,
        file,
        videoId,
        videoStatus,
        videoProviderId,
        videoProvider,
        assignedGroupIds,
        assignedGroupNames,
        associatedExamId,
        associatedExamTitle,
        prerequisiteExamId,
        prerequisiteExamTitle,
        prerequisitePassingScore,
        isLocked,
        isVideoCompleted,
        videoProgressPercentage,
        isExamPassed,
      ];
}
