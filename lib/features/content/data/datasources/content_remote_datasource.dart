import 'dart:async';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/group_slug_resolver.dart';
import '../../../notifications/domain/services/notification_dispatcher.dart';
import '../../domain/entities/attached_lesson_exam_entity.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/content_analytics_entity.dart';
import '../models/content_model.dart';
import '../models/file_attachment_model.dart';

abstract interface class ContentRemoteDataSource {
  /// Fetches content items for a specific group, ordered by sort_order asc
  Future<List<ContentModel>> getGroupContent({
    required String groupId,
    String? statusFilter,
    int page = 0,
    int pageSize = 20,
  });

  /// Creates a content entry and optional file attachment record (groupId optional for Bank)
  Future<ContentModel> createContent({
    String? groupId,
    required String title,
    String? description,
    required String type,
    required String status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  });

  /// Updates content metadata
  Future<ContentModel> updateContent({
    required String contentId,
    String? title,
    String? description,
    String? type,
    String? status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  });

  /// Updates lifecycle status and sets published_at if publishing
  Future<void> updateContentStatus({
    required String contentId,
    required String status,
  });

  /// Updates sort_order for multiple items atomically (across content and content_groups)
  Future<void> reorderContentItems({
    required List<String> contentIdsInOrder,
    String? groupId,
  });

  /// Deletes a content item (and cascading file attachment)
  Future<void> deleteContent(String contentId);

  /// Generates a signed URL for a private storage asset
  Future<String> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  });

  /// Retrieves the centralized video bank for the tenant (all video lessons)
  Future<List<ContentModel>> getCentralVideoBank({
    int page = 0,
    int pageSize = 100,
  });

  /// Assigns/synchronizes a content item to one or more groups
  Future<void> assignContentToGroups({
    required String contentId,
    required List<String> groupIds,
    List<Map<String, dynamic>>? groupConfigs,
  });

  /// Resolves an existing content_id or creates one for a video assigned to a group
  Future<String> resolveOrCreateLectureContent({
    required String videoId,
    required String groupId,
    required String title,
    String? tenantId,
  });

  /// Atomically assigns multiple content items/videos to a group in one transaction
  Future<void> assignBatchContentToGroup({
    required String groupId,
    required List<Map<String, dynamic>> items,
  });

  /// Links a quiz/exam to a lesson unit
  Future<void> linkLessonExam({
    required String contentId,
    required String examId,
  });

  /// Fetches the course progress for a group
  Future<List<Map<String, dynamic>>> getGroupCourseProgress({
    required String groupId,
    String? studentId,
  });

  /// Manually unlocks a lesson for a specific student in a group
  Future<void> manualUnlockLesson({
    required String studentId,
    required String groupId,
    required String contentId,
    String? reason,
  });

  /// Toggles visibility (draft vs published) of a lesson within a specific group
  Future<void> toggleLessonVisibility({
    required String contentId,
    required String groupId,
    required bool isPublished,
  });

  /// Bulk toggles visibility of all lessons in a specific group
  Future<void> toggleAllLessonsVisibility({
    required String groupId,
    required bool isPublished,
  });

  /// Uploads a file (R2 or fallback) and creates a record in the files table.
  /// Returns the newly created file_id.
  Future<String> uploadAndCreateFileRecord({
    required String tenantId,
    required String contentId,
    required String fileName,
    required String mimeType,
    required List<int> fileBytes,
    required String storagePath,
  });

  /// Fetches chapters belonging to a group ordered by sort_order
  Future<List<ChapterEntity>> getGroupChapters(String groupId);

  /// Creates a new chapter for a group
  Future<ChapterEntity> createChapter({
    required String groupId,
    required String title,
    bool isPublished = true,
  });

  /// Toggles visibility of a chapter (published/draft)
  Future<void> toggleChapterVisibility({
    required String chapterId,
    required bool isPublished,
  });

  /// Renames / updates an existing chapter
  Future<void> updateChapter({
    required String chapterId,
    required String title,
  });

  /// Deletes a chapter (unlinks its lessons to general)
  Future<void> deleteChapter(String chapterId);

  /// Assigns or unassigns a lesson to/from a chapter
  Future<void> setLessonChapter({
    required String contentId,
    required String groupId,
    String? chapterId,
  });

  /// Reorders lessons within a chapter or course
  Future<void> reorderChapterLessons({
    required String groupId,
    required List<String> contentIdsInOrder,
  });

  /// Reorders chapters within a course
  Future<void> reorderCourseChapters({
    required String groupId,
    required List<String> chapterIdsInOrder,
  });

  /// Removes a lesson from a group (without deleting underlying central asset)
  Future<void> removeLessonFromGroup({
    required String contentId,
    required String groupId,
  });

  /// Fetches summary of available exams (id, title) for lesson exam selectors
  Future<List<Map<String, dynamic>>> getAvailableExamsSummary();

  /// Fetches the linked exam (id, title) for a specific content item
  Future<Map<String, String>?> getExamByContentId(String contentId);

  /// Fetches aggregated analytics for a single lesson
  Future<LessonAnalyticsEntity> getLessonAnalytics({
    required String lessonId,
    required String groupId,
    String? videoId,
    String? examId,
  });

  /// Fetches aggregated analytics for a chapter
  Future<ChapterAnalyticsEntity> getChapterAnalytics({
    required String groupId,
    required List<String> lessonIds,
    required List<String> examIds,
  });

  /// Fetches existing group customizations for a specific content item
  Future<List<Map<String, dynamic>>> getContentGroupCustomizations(String contentId);

  /// Fetches panoramic aggregated group analytics for courses
  Future<GroupAnalyticsEntity> getGroupAnalytics({
    required String groupId,
    required List<ChapterEntity> chapters,
    required List<ContentEntity> lessons,
  });
}

class ContentRemoteDataSourceImpl implements ContentRemoteDataSource {
  final SupabaseClient? _client;

  ContentRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  Future<String> _resolveGroupId(String groupId) async {
    final cached = GroupSlugResolver.toId(groupId);
    if (GroupSlugResolver.isUuid(cached)) return cached;
    return await GroupSlugResolver.toIdAsync(cached, _safeClient);
  }

  @override
  Future<List<ContentModel>> getGroupContent({
    required String groupId,
    String? statusFilter,
    int page = 0,
    int pageSize = 20,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);

    // Launch lesson_exams query concurrently with content queries to eliminate waterfall round-trip
    final lessonExamsFuture = _safeClient
        .from('lesson_exams')
        .select(
          'content_id, exam_id, sort_order, is_required, exams(id, title, passing_score)',
        )
        .eq('group_id', resolvedGroupId)
        .order('sort_order', ascending: true);

    // Fetch any content linked to this group via the junction table content_groups with group overrides
    final junctionRes = await _safeClient
        .from('content_groups')
        .select(
          'content_id, file_id, associated_exam_id, prerequisite_exam_id, sort_order, custom_title, is_published, chapter_id, '
          'file:files!content_groups_file_id_fkey(id, tenant_id, content_id, storage_path, file_name, mime_type, file_size, created_at, storage_provider), '
          'associated_exam:exams!content_groups_associated_exam_id_fkey(id, title), '
          'prerequisite_exam:exams!content_groups_prerequisite_exam_id_fkey(id, title, passing_score), '
          'chapter:chapters!content_groups_chapter_id_fkey(id, title, sort_order)',
        )
        .eq('group_id', resolvedGroupId);

    final Map<String, Map<String, dynamic>> junctionConfigMap = {};
    final junctionIds = <String>[];
    for (final row in (junctionRes as List<dynamic>)) {
      final cId = row['content_id'] as String?;
      if (cId != null) {
        junctionIds.add(cId);
        junctionConfigMap[cId] = row as Map<String, dynamic>;
      }
    }

    var query = _safeClient
        .from('content')
        .select(
          'id, tenant_id, group_id, title, description, type, status, sort_order, published_at, created_at, updated_at, associated_exam_id, prerequisite_exam_id, '
          'files(id, tenant_id, content_id, storage_path, file_name, mime_type, file_size, created_at, storage_provider), '
          'videos(id, status, provider_video_id, provider), '
          'content_groups(group_id, is_published, groups(name)), '
          'associated_exam:exams!content_associated_exam_id_fkey(id, title), '
          'prerequisite_exam:exams!content_prerequisite_exam_id_fkey(id, title, passing_score)',
        )
        .neq('type', 'exam')
        .neq('type', 'assignment');

    if (junctionIds.isEmpty) {
      query = query.eq('group_id', resolvedGroupId);
    } else {
      final joinedIds = junctionIds.join(',');
      query = query.or('group_id.eq.$resolvedGroupId,id.in.($joinedIds)');
    }

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }

    // Await content and pre-launched lesson_exams concurrently
    List<dynamic> response;
    dynamic lessonExamsRes;
    try {
      final results = await Future.wait<dynamic>([
        query
            .order('sort_order', ascending: true)
            .order('created_at', ascending: true)
            .range(page * pageSize, (page + 1) * pageSize - 1),
        lessonExamsFuture.catchError((Object e) {
          AppLogger.w(
            'ContentRemoteDataSource',
            'Could not fetch lesson_exams concurrently: $e',
          );
          return <dynamic>[];
        }),
      ]);
      response = results[0] as List<dynamic>;
      lessonExamsRes = results[1];
    } catch (_) {
      response = await query
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true)
          .range(page * pageSize, (page + 1) * pageSize - 1);
    }

    // Parse attached exams from lesson_exams junction
    final Map<String, List<AttachedLessonExamEntity>> lessonExamsMap = {};
    if (lessonExamsRes is List<dynamic>) {
      for (final row in lessonExamsRes) {
        final cId = row['content_id'] as String?;
        final examObj = row['exams'] as Map<String, dynamic>?;
        if (cId != null && examObj != null) {
          int qCount = 0;
          final versionsList = examObj['exam_versions'] as List<dynamic>?;
          if (versionsList != null && versionsList.isNotEmpty) {
            final firstVer = versionsList.first as Map<String, dynamic>;
            final eqList = firstVer['exam_questions'] as List<dynamic>?;
            if (eqList != null && eqList.isNotEmpty) {
              qCount =
                  (eqList.first as Map<String, dynamic>)['count'] as int? ?? 0;
            }
          }

          final item = AttachedLessonExamEntity(
            examId: row['exam_id'] as String? ?? examObj['id'] as String? ?? '',
            examTitle: examObj['title'] as String? ?? '',
            sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
            isRequired: row['is_required'] as bool? ?? true,
            passingScore: (examObj['passing_score'] as num?)?.toInt() ?? 60,
            questionsCount: qCount,
          );
          lessonExamsMap.putIfAbsent(cId, () => []).add(item);
        }
      }
    }

    final list = response;
    final models = list
        .map((json) => ContentModel.fromJson(json as Map<String, dynamic>))
        .where(
          (m) =>
              m.type != ContentType.exam && m.type != ContentType.assignment,
        )
        .toList();

    // Apply group-specific customizations from content_groups junction
    for (int i = 0; i < models.length; i++) {
      final m = models[i];
      final cfg = junctionConfigMap[m.id];
      if (cfg != null) {
        FileAttachmentModel? customFile = m.file as FileAttachmentModel?;
        if (cfg['file'] != null && cfg['file'] is Map<String, dynamic>) {
          customFile = FileAttachmentModel.fromJson(
            cfg['file'] as Map<String, dynamic>,
          );
        }

        String? assocExamId = m.associatedExamId;
        String? assocExamTitle = m.associatedExamTitle;
        if (cfg['associated_exam_id'] != null) {
          assocExamId = cfg['associated_exam_id'] as String?;
          final assocObj = cfg['associated_exam'] as Map<String, dynamic>?;
          if (assocObj != null) {
            if (assocObj['content'] != null) {
              final contentObj = assocObj['content'] as Map<String, dynamic>;
              assocExamTitle = contentObj['title'] as String? ?? assocExamTitle;
            } else if (assocObj['title'] != null) {
              assocExamTitle = assocObj['title'] as String? ?? assocExamTitle;
            }
          }
        }

        String? prereqExamId = m.prerequisiteExamId;
        String? prereqExamTitle = m.prerequisiteExamTitle;
        int? prereqPassingScore = m.prerequisitePassingScore;
        if (cfg['prerequisite_exam_id'] != null) {
          prereqExamId = cfg['prerequisite_exam_id'] as String?;
          final prereqObj = cfg['prerequisite_exam'] as Map<String, dynamic>?;
          if (prereqObj != null) {
            if (prereqObj['content'] != null) {
              final contentObj = prereqObj['content'] as Map<String, dynamic>;
              prereqExamTitle =
                  contentObj['title'] as String? ?? prereqExamTitle;
            } else if (prereqObj['title'] != null) {
              prereqExamTitle =
                  prereqObj['title'] as String? ?? prereqExamTitle;
            }
            prereqPassingScore =
                (prereqObj['passing_score'] as num?)?.toInt() ??
                prereqPassingScore;
          }
        }

        int sortOrder = m.sortOrder;
        if (cfg['sort_order'] != null) {
          sortOrder = (cfg['sort_order'] as num).toInt();
        }

        String title = m.title;
        if (cfg['custom_title'] != null &&
            cfg['custom_title'].toString().trim().isNotEmpty) {
          title = cfg['custom_title'].toString().trim();
        }

        bool isPublishedInGroup = m.isPublishedInGroup;
        if (cfg['is_published'] != null) {
          isPublishedInGroup = cfg['is_published'] == true;
        }

        String? chapterId = cfg['chapter_id'] as String?;
        String? chapterTitle;
        int? chapterSortOrder;
        if (chapterId != null) {
          final chapObj = cfg['chapter'] as Map<String, dynamic>?;
          if (chapObj != null) {
            chapterTitle = chapObj['title'] as String?;
            chapterSortOrder = (chapObj['sort_order'] as num?)?.toInt();
          }
        }

        List<AttachedLessonExamEntity> attached =
            lessonExamsMap[m.id] ?? const [];
        if (attached.isEmpty && assocExamId != null) {
          attached = [
            AttachedLessonExamEntity(
              examId: assocExamId,
              examTitle: assocExamTitle ?? '',
              sortOrder: 0,
              isRequired: true,
            ),
          ];
        }

        models[i] = m.copyWith(
          title: title,
          file: customFile,
          associatedExamId: assocExamId,
          associatedExamTitle: assocExamTitle,
          attachedExams: attached,
          prerequisiteExamId: prereqExamId,
          prerequisiteExamTitle: prereqExamTitle,
          prerequisitePassingScore: prereqPassingScore,
          sortOrder: sortOrder,
          isPublishedInGroup: isPublishedInGroup,
          chapterId: chapterId,
          chapterTitle: chapterTitle,
          chapterSortOrder: chapterSortOrder,
        );
      } else if (lessonExamsMap.containsKey(m.id)) {
        models[i] = m.copyWith(attachedExams: lessonExamsMap[m.id]);
      }
    }

    models.sort((a, b) {
      if (a.chapterSortOrder != null && b.chapterSortOrder != null) {
        final c = a.chapterSortOrder!.compareTo(b.chapterSortOrder!);
        if (c != 0) return c;
      } else if (a.chapterSortOrder != null && b.chapterSortOrder == null) {
        return -1;
      } else if (a.chapterSortOrder == null && b.chapterSortOrder != null) {
        return 1;
      }
      final s = a.sortOrder.compareTo(b.sortOrder);
      if (s != 0) return s;
      return a.createdAt.compareTo(b.createdAt);
    });

    // Check student sequential progression lock status
    final currentUserId = _safeClient.auth.currentUser?.id;
    final userRole = SupabaseService.currentUserRole;

    if (userRole == 'student' && currentUserId != null && models.isNotEmpty) {
      try {
        final groupData = await _safeClient
            .from('groups')
            .select('enforce_sequential_learning')
            .eq('id', groupId)
            .maybeSingle();
        final enforceSeq = groupData?['enforce_sequential_learning'] != false;

        final attemptsRes = await _safeClient
            .from('exam_attempts')
            .select('exam_id, score, percentage, exams(passing_score)')
            .eq('student_id', currentUserId)
            .eq('status', 'submitted');

        final Set<String> passedExamIds = {};
        for (final att in (attemptsRes as List<dynamic>)) {
          final examObj = att['exams'] as Map<String, dynamic>?;
          final passScore = (examObj?['passing_score'] as num?)?.toInt();
          final score = (att['score'] as num?)?.toInt() ?? 0;
          final isPassed = passScore == null || score >= passScore;
          if (isPassed) {
            final eId = att['exam_id'] as String?;
            if (eId != null) passedExamIds.add(eId);
          }
        }

        // Fetch video progress for all video lessons in this group
        final videoIds = models
            .map((m) => m.videoId)
            .where((id) => id != null && id.isNotEmpty)
            .cast<String>()
            .toList();

        final Set<String> completedVideoIds = {};
        final Map<String, double> videoProgressMap = {};

        if (videoIds.isNotEmpty) {
          final progressRes = await _safeClient
              .from('video_progress')
              .select('video_id, completed, percentage')
              .eq('student_id', currentUserId)
              .inFilter('video_id', videoIds);

          for (final row in (progressRes as List<dynamic>)) {
            final vId = row['video_id'] as String?;
            final comp = row['completed'] == true;
            final pct = (row['percentage'] as num?)?.toDouble() ?? 0.0;
            if (vId != null) {
              videoProgressMap[vId] = pct;
              if (comp || pct >= 90.0) {
                completedVideoIds.add(vId);
              }
            }
          }
        }

        String? previousLessonExamId;
        String? previousLessonVideoId;
        for (int i = 0; i < models.length; i++) {
          final item = models[i];
          final isVideoCompleted =
              item.videoId == null || completedVideoIds.contains(item.videoId);
          final progressPct = item.videoId != null
              ? (videoProgressMap[item.videoId] ?? 0.0)
              : 0.0;
          final isExamPassed =
              item.associatedExamId != null &&
              passedExamIds.contains(item.associatedExamId);

          bool locked = false;
          if (item.prerequisiteExamId != null) {
            locked = !passedExamIds.contains(item.prerequisiteExamId);
          } else if (enforceSeq && i > 0) {
            if (previousLessonExamId != null &&
                !passedExamIds.contains(previousLessonExamId)) {
              locked = true;
            } else if (previousLessonVideoId != null &&
                !completedVideoIds.contains(previousLessonVideoId)) {
              locked = true;
            }
          }

          models[i] = models[i].copyWith(
            isLocked: locked,
            isVideoCompleted: isVideoCompleted,
            videoProgressPercentage: progressPct,
            isExamPassed: isExamPassed,
          );

          previousLessonExamId = item.associatedExamId;
          previousLessonVideoId = item.videoId;
        }
      } catch (_) {}
    }

    return models;
  }

  @override
  Future<ContentModel> createContent({
    String? groupId,
    required String title,
    String? description,
    required String type,
    required String status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('AUTH_REQUIRED: User not authenticated');
    }

    final userMeta = _safeClient.auth.currentUser?.userMetadata;
    final tenantId = userMeta?['tenant_id'] as String?;

    if (tenantId == null) {
      final userProfile = await _safeClient
          .from('users')
          .select('tenant_id')
          .eq('id', currentUserId)
          .single();
      final resolvedTenantId = userProfile['tenant_id'] as String;
      return _createContentInternal(
        groupId: groupId,
        title: title,
        description: description,
        type: type,
        status: status,
        sortOrder: sortOrder,
        fileName: fileName,
        storagePath: storagePath,
        mimeType: mimeType,
        fileSize: fileSize,
        fileBytes: fileBytes,
        tenantId: resolvedTenantId,
        associatedExamId: associatedExamId,
        prerequisiteExamId: prerequisiteExamId,
      );
    }

    return _createContentInternal(
      groupId: groupId,
      title: title,
      description: description,
      type: type,
      status: status,
      sortOrder: sortOrder,
      fileName: fileName,
      storagePath: storagePath,
      mimeType: mimeType,
      fileSize: fileSize,
      fileBytes: fileBytes,
      tenantId: tenantId,
      associatedExamId: associatedExamId,
      prerequisiteExamId: prerequisiteExamId,
    );
  }

  @override
  Future<String> uploadAndCreateFileRecord({
    required String tenantId,
    required String contentId,
    required String fileName,
    required String mimeType,
    required List<int> fileBytes,
    required String storagePath,
  }) async {
    final uploadResult = await _uploadMaterialFile(
      fileName: fileName,
      mimeType: mimeType,
      fileBytes: fileBytes,
      defaultStoragePath: storagePath,
    );

    final filePayload = {
      'tenant_id': tenantId,
      'content_id': contentId,
      'storage_path': uploadResult.path,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileBytes.length,
      'storage_provider': uploadResult.provider,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };

    final fileRes = await _safeClient
        .from('files')
        .insert(filePayload)
        .select('id')
        .single();

    return fileRes['id'] as String;
  }

  Future<({String path, String provider})> _uploadMaterialFile({
    required String fileName,
    required String mimeType,
    required List<int> fileBytes,
    required String defaultStoragePath,
  }) async {
    // Supabase Private Storage 'group-content' (fast, reliable native upload)
    await _safeClient.storage
        .from('group-content')
        .uploadBinary(
          defaultStoragePath,
          fileBytes is Uint8List ? fileBytes : Uint8List.fromList(fileBytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    return (path: defaultStoragePath, provider: 'supabase');
  }

  Future<ContentModel> _createContentInternal({
    String? groupId,
    required String title,
    String? description,
    required String type,
    required String status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    required String tenantId,
    String? associatedExamId,
    String? prerequisiteExamId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final publishedAt = status == 'published' ? now : null;

    // Calculate max sort_order if not provided
    var order = sortOrder;
    if (order == null && groupId != null) {
      final existingCg = await _safeClient
          .from('content_groups')
          .select('sort_order')
          .eq('group_id', groupId)
          .order('sort_order', ascending: false)
          .limit(1);
      final existingCgList = existingCg as List<dynamic>;
      final maxCg = existingCgList.isNotEmpty
          ? ((existingCgList.first['sort_order'] as num?)?.toInt() ?? -1)
          : -1;

      final existingContent = await _safeClient
          .from('content')
          .select('sort_order')
          .eq('group_id', groupId)
          .neq('type', 'exam')
          .neq('type', 'assignment')
          .order('sort_order', ascending: false)
          .limit(1);
      final existingContentList = existingContent as List<dynamic>;
      final maxContent = existingContentList.isNotEmpty
          ? ((existingContentList.first['sort_order'] as num?)?.toInt() ?? -1)
          : -1;

      final highest = maxCg > maxContent ? maxCg : maxContent;
      order = highest >= 0 ? highest + 1 : 0;
    }

    final insertPayload = <String, dynamic>{
      'tenant_id': tenantId,
      if (groupId != null) 'group_id': groupId,
      'title': title,
      if (description != null) 'description': description,
      'type': type,
      'status': status,
      'sort_order': order ?? 0,
      if (publishedAt != null) 'published_at': publishedAt,
      if (associatedExamId != null) 'associated_exam_id': associatedExamId,
      if (prerequisiteExamId != null)
        'prerequisite_exam_id': prerequisiteExamId,
      'created_at': now,
      'updated_at': now,
    };

    final contentRes = await _safeClient
        .from('content')
        .insert(insertPayload)
        .select()
        .single();

    final contentId = contentRes['id'] as String;

    FileAttachmentModel? attachedFile;
    if (storagePath != null && fileName != null && mimeType != null) {
      String finalStoragePath = storagePath;
      String storageProvider = 'supabase';

      if (fileBytes != null && fileBytes.isNotEmpty) {
        final uploadResult = await _uploadMaterialFile(
          fileName: fileName,
          mimeType: mimeType,
          fileBytes: fileBytes,
          defaultStoragePath: storagePath,
        );
        finalStoragePath = uploadResult.path;
        storageProvider = uploadResult.provider;
      }

      final filePayload = {
        'tenant_id': tenantId,
        'content_id': contentId,
        'storage_path': finalStoragePath,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size': fileSize ?? (fileBytes?.length ?? 0),
        'storage_provider': storageProvider,
        'created_at': now,
      };

      final fileRes = await _safeClient
          .from('files')
          .insert(filePayload)
          .select()
          .single();

      attachedFile = FileAttachmentModel.fromJson(fileRes);
    }

    final model = ContentModel.fromJson(contentRes);

    if (status == 'published' && groupId != null && groupId.isNotEmpty) {
      unawaited(
        NotificationDispatcher.notifyNewLecture(
          title: title,
          groupId: groupId,
          contentId: model.id,
          contentType: type,
        ),
      );
    }

    return ContentModel(
      id: model.id,
      tenantId: model.tenantId,
      groupId: model.groupId,
      title: model.title,
      description: model.description,
      type: model.type,
      status: model.status,
      sortOrder: model.sortOrder,
      publishedAt: model.publishedAt,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      file: attachedFile,
      associatedExamId: associatedExamId,
      prerequisiteExamId: prerequisiteExamId,
    );
  }

  @override
  Future<ContentModel> updateContent({
    required String contentId,
    String? title,
    String? description,
    String? type,
    String? status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updatePayload = <String, dynamic>{'updated_at': now};

    if (title != null) updatePayload['title'] = title;
    if (description != null) updatePayload['description'] = description;
    if (type != null) updatePayload['type'] = type;
    if (sortOrder != null) updatePayload['sort_order'] = sortOrder;
    if (associatedExamId != null) {
      updatePayload['associated_exam_id'] = associatedExamId;
    }
    if (prerequisiteExamId != null) {
      updatePayload['prerequisite_exam_id'] = prerequisiteExamId;
    }

    if (status != null) {
      updatePayload['status'] = status;
      if (status == 'published') {
        updatePayload['published_at'] = now;
      }
    }

    final res = await _safeClient
        .from('content')
        .update(updatePayload)
        .eq('id', contentId)
        .select('*, files(*)')
        .single();

    if (storagePath != null && fileName != null && mimeType != null) {
      String finalStoragePath = storagePath;
      String storageProvider = 'supabase';

      if (fileBytes != null && fileBytes.isNotEmpty) {
        final uploadResult = await _uploadMaterialFile(
          fileName: fileName,
          mimeType: mimeType,
          fileBytes: fileBytes,
          defaultStoragePath: storagePath,
        );
        finalStoragePath = uploadResult.path;
        storageProvider = uploadResult.provider;
      }

      final tenantId = res['tenant_id'] as String;
      final existingFiles = await _safeClient
          .from('files')
          .select('id')
          .eq('content_id', contentId)
          .limit(1);
      final list = existingFiles as List<dynamic>;

      if (list.isNotEmpty) {
        final existingId = list.first['id'] as String;
        await _safeClient
            .from('files')
            .update({
              'storage_path': finalStoragePath,
              'file_name': fileName,
              'mime_type': mimeType,
              'file_size': fileSize ?? (fileBytes?.length ?? 0),
              'storage_provider': storageProvider,
              'created_at': now,
            })
            .eq('id', existingId);
      } else {
        await _safeClient.from('files').insert({
          'tenant_id': tenantId,
          'content_id': contentId,
          'storage_path': finalStoragePath,
          'file_name': fileName,
          'mime_type': mimeType,
          'file_size': fileSize ?? (fileBytes?.length ?? 0),
          'storage_provider': storageProvider,
          'created_at': now,
        });
      }

      final refreshed = await _safeClient
          .from('content')
          .select('*, files(*)')
          .eq('id', contentId)
          .single();
      return ContentModel.fromJson(refreshed);
    }

    return ContentModel.fromJson(res);
  }

  @override
  Future<void> updateContentStatus({
    required String contentId,
    required String status,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updatePayload = <String, dynamic>{
      'status': status,
      'updated_at': now,
    };

    if (status == 'published') {
      updatePayload['published_at'] = now;
    }

    final updated = await _safeClient
        .from('content')
        .update(updatePayload)
        .eq('id', contentId)
        .select('title, group_id, type')
        .maybeSingle();

    if (status == 'published' && updated != null) {
      final grpId = updated['group_id'] as String?;
      final title = updated['title'] as String? ?? 'محاضرة جديدة';
      final type = updated['type'] as String? ?? 'lesson';
      if (grpId != null && grpId.isNotEmpty) {
        unawaited(
          NotificationDispatcher.notifyNewLecture(
            title: title,
            groupId: grpId,
            contentId: contentId,
            contentType: type,
          ),
        );
      }
    }
  }

  @override
  Future<void> reorderContentItems({
    required List<String> contentIdsInOrder,
    String? groupId,
  }) async {
    // ⚡ Performance: RPC واحد بدلاً من N رحلات HTTP
    // ترتيب 10 عناصر = 10 × ~400ms = 4s  →  RPC واحد = ~80ms
    // يُحدّث كلاً من جدول content وجدول content_groups لضمان تزامن الطالب والمعلم 100%
    final resolvedGroupId = groupId != null
        ? GroupSlugResolver.toId(groupId)
        : null;
    await _safeClient.rpc<void>(
      'reorder_content_items',
      params: {
        'p_ids': contentIdsInOrder,
        if (resolvedGroupId != null &&
            GroupSlugResolver.isUuid(resolvedGroupId))
          'p_group_id': resolvedGroupId,
      },
    );
  }

  @override
  Future<void> deleteContent(String contentId) async {
    // 1. Call atomic database cleanup RPC (preserves exams, cleans DB child records)
    final res = await _safeClient.rpc<dynamic>(
      'delete_lesson_with_cleanup',
      params: {'p_content_id': contentId},
    );

    // 2. The RPC returns a list of storage paths of deleted files (e.g. materials/... or files in group-content)
    if (res != null && res is List) {
      final paths = res.map((e) => e.toString()).toList();
      if (paths.isNotEmpty) {
        try {
          await _safeClient.storage.from('group-content').remove(paths);
        } catch (_) {
          // Non-blocking cleanup
        }
      }
    }
  }

  @override
  Future<String> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    // 1. Primary: Supabase Storage ('group-content') where all platform materials are stored
    try {
      final signedUrl = await _safeClient.storage
          .from('group-content')
          .createSignedUrl(storagePath, expiresInSeconds);
      if (signedUrl.isNotEmpty) {
        return signedUrl;
      }
    } catch (_) {
      // Fallback: If not in Supabase Storage and path starts with materials/, attempt R2
    }

    if (storagePath.startsWith('materials/')) {
      try {
        final r2Res = await _safeClient.functions.invoke(
          'r2-storage',
          body: {'action': 'get-download-url', 'storage_path': storagePath},
        );

        if (r2Res.status == 200 && r2Res.data is Map<String, dynamic>) {
          final data = r2Res.data as Map<String, dynamic>;
          final downloadUrl = data['download_url'] as String?;
          if (downloadUrl != null && downloadUrl.isNotEmpty) {
            return downloadUrl;
          }
        }
      } catch (_) {
        // Fallback
      }
    }

    return await _safeClient.storage
        .from('group-content')
        .createSignedUrl(storagePath, expiresInSeconds);
  }

  @override
  Future<List<ContentModel>> getCentralVideoBank({
    int page = 0,
    int pageSize = 100,
  }) async {
    final List<ContentModel> allVideos = [];

    // 1. Fetch all ready videos from video_library (Central Video Bank CMS)
    try {
      final libResponse = await _safeClient
          .from('video_library')
          .select(
            '*, videos(id, library_video_id, provider_video_id, content(id, group_id, group:groups(id, name), content_groups(group_id, groups(id, name))))',
          )
          .neq('status', 'failed')
          .order('created_at', ascending: false);

      final libList = libResponse as List<dynamic>;
      for (final item in libList) {
        final row = item as Map<String, dynamic>;
        final List<String> assignedNames = [];
        final List<String> assignedIds = [];
        final videosList = row['videos'] as List<dynamic>?;
        if (videosList != null) {
          for (final v in videosList) {
            final c = v['content'] as Map<String, dynamic>?;
            if (c != null) {
              final gId = c['group_id'] as String?;
              if (gId != null && !assignedIds.contains(gId)) {
                assignedIds.add(gId);
              }
              final g = c['group'] as Map<String, dynamic>?;
              final name = g?['name'] as String?;
              if (name != null && !assignedNames.contains(name)) {
                assignedNames.add(name);
              }
              final cGroups = c['content_groups'] as List<dynamic>?;
              if (cGroups != null) {
                for (final cg in cGroups) {
                  final cgMap = cg as Map<String, dynamic>?;
                  final cgId = cgMap?['group_id'] as String?;
                  if (cgId != null && !assignedIds.contains(cgId)) {
                    assignedIds.add(cgId);
                  }
                  final cgGroup = cgMap?['groups'] as Map<String, dynamic>?;
                  final cgName = cgGroup?['name'] as String?;
                  if (cgName != null && !assignedNames.contains(cgName)) {
                    assignedNames.add(cgName);
                  }
                }
              }
            }
          }
        }

        allVideos.add(
          ContentModel(
            id: row['id'] as String,
            tenantId: row['tenant_id'] as String,
            title: row['title'] as String,
            description: row['description'] as String?,
            type: ContentType.video,
            status: ContentStatus.published,
            sortOrder: 0,
            createdAt: DateTime.parse(row['created_at'] as String),
            updatedAt: DateTime.parse(row['updated_at'] as String),
            videoId: row['id'] as String,
            videoStatus: row['status'] as String? ?? 'ready',
            videoProviderId: row['provider_video_id'] as String?,
            videoProvider: row['provider'] as String? ?? 'bunny',
            assignedGroupIds: assignedIds,
            assignedGroupNames: assignedNames,
            isPublishedInGroup: true,
          ),
        );
      }
    } catch (_) {}

    // 2. Fetch standalone / existing lessons from content table
    try {
      final response = await _safeClient
          .from('content')
          .select(
            '*, files(*), videos(*), content_groups(group_id, groups(id, name)), '
            'associated_exam:exams!content_associated_exam_id_fkey(id, title), '
            'prerequisite_exam:exams!content_prerequisite_exam_id_fkey(id, title, passing_score)',
          )
          .inFilter('type', ['video', 'youtube'])
          .order('created_at', ascending: false);

      final list = response as List<dynamic>;
      final contentModels = list
          .map((e) => ContentModel.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final c in contentModels) {
        final existingIdx = allVideos.indexWhere((v) {
          final matchId =
              v.id == c.id || (c.videoId != null && v.id == c.videoId);
          final matchProvider =
              v.videoProviderId != null &&
              v.videoProviderId!.isNotEmpty &&
              c.videoProviderId != null &&
              v.videoProviderId == c.videoProviderId;
          final matchTitle =
              v.title.trim().toLowerCase() == c.title.trim().toLowerCase();
          return matchId || matchProvider || matchTitle;
        });

        if (existingIdx != -1) {
          // Merge assigned groups into the existing video bank item
          final existing = allVideos[existingIdx];
          final mergedIds = Set<String>.from(existing.assignedGroupIds)
            ..addAll(c.assignedGroupIds);
          final mergedNames = Set<String>.from(existing.assignedGroupNames)
            ..addAll(c.assignedGroupNames);

          allVideos[existingIdx] = ContentModel(
            id: existing.id,
            tenantId: existing.tenantId,
            groupId: existing.groupId,
            title: existing.title,
            description: existing.description ?? c.description,
            type: existing.type,
            status: existing.status,
            sortOrder: existing.sortOrder,
            publishedAt: existing.publishedAt,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
            file: existing.file,
            videoId: existing.videoId,
            videoStatus: existing.videoStatus,
            videoProviderId: existing.videoProviderId,
            videoProvider: existing.videoProvider ?? c.videoProvider,
            assignedGroupIds: mergedIds.toList(),
            assignedGroupNames: mergedNames.toList(),
            associatedExamId: existing.associatedExamId,
            associatedExamTitle: existing.associatedExamTitle,
            prerequisiteExamId: existing.prerequisiteExamId,
            prerequisiteExamTitle: existing.prerequisiteExamTitle,
            prerequisitePassingScore: existing.prerequisitePassingScore,
            isLocked: existing.isLocked,
            isVideoCompleted: existing.isVideoCompleted,
            videoProgressPercentage: existing.videoProgressPercentage,
            isExamPassed: existing.isExamPassed,
            isPublishedInGroup: existing.isPublishedInGroup,
          );
        } else {
          // Only add standalone videos that actually have a valid video source (YouTube or video record)
          final hasVideo =
              (c.videoProviderId != null && c.videoProviderId!.isNotEmpty) ||
              (c.videoId != null && c.videoId!.isNotEmpty) ||
              c.videoProvider == 'youtube' ||
              c.type == ContentType.video;
          if (hasVideo && c.title.trim().isNotEmpty) {
            allVideos.add(c);
          }
        }
      }
    } catch (_) {}

    return allVideos;
  }

  @override
  Future<void> assignContentToGroups({
    required String contentId,
    required List<String> groupIds,
    List<Map<String, dynamic>>? groupConfigs,
  }) async {
    final resolvedGroupIds = groupIds.map(GroupSlugResolver.toId).toList();
    final resolvedConfigs = groupConfigs?.map((cfg) {
      final copy = Map<String, dynamic>.from(cfg);
      if (copy['group_id'] != null) {
        copy['group_id'] = GroupSlugResolver.toId(copy['group_id'] as String);
      }
      return copy;
    }).toList();

    // 1. Resolve or create actualContentId cleanly
    final customTitle =
        (resolvedConfigs != null &&
            resolvedConfigs.isNotEmpty &&
            resolvedConfigs.first['custom_title'] != null)
        ? resolvedConfigs.first['custom_title'] as String
        : null;

    final actualContentId = await resolveOrCreateLectureContent(
      videoId: contentId,
      groupId: resolvedGroupIds.isNotEmpty ? resolvedGroupIds.first : '',
      title: customTitle ?? '',
    );

    // Ensure any file_id in groupConfigs has content_id linked in files table
    if (resolvedConfigs != null) {
      for (final cfg in resolvedConfigs) {
        final fId = cfg['file_id'] as String?;
        if (fId != null && fId.isNotEmpty) {
          try {
            await _safeClient
                .from('files')
                .update({'content_id': actualContentId})
                .eq('id', fId)
                .filter('content_id', 'is', 'null');
          } catch (_) {}
        }
      }
    }

    // 2. Assign actualContentId to groups via atomic RPC
    await _safeClient.rpc<void>(
      'assign_content_to_groups',
      params: {
        'p_content_id': actualContentId,
        'p_group_ids': resolvedGroupIds,
        'p_group_configs': resolvedConfigs ?? [],
      },
    );
  }

  @override
  Future<String> resolveOrCreateLectureContent({
    required String videoId,
    required String groupId,
    required String title,
    String? tenantId,
  }) async {
    final resolvedGroupId = GroupSlugResolver.toId(groupId);

    // 1. Check if videoId is already a valid UUID in public.content
    final contentCheck = await _safeClient
        .from('content')
        .select('id')
        .eq('id', videoId)
        .maybeSingle();

    if (contentCheck != null) {
      return contentCheck['id'] as String;
    }

    // 2. Check if a lecture already exists in videos table for this library_video_id
    final existingVideos = await _safeClient
        .from('videos')
        .select(
          'content_id, content:content!videos_content_id_fkey(id, group_id)',
        )
        .eq('library_video_id', videoId);

    final list = existingVideos as List<dynamic>;
    if (list.isNotEmpty) {
      // Find one matching this group first
      for (final item in list) {
        final cId = item['content_id'] as String;
        if (resolvedGroupId.isNotEmpty) {
          final cgCheck = await _safeClient
              .from('content_groups')
              .select('id')
              .eq('content_id', cId)
              .eq('group_id', resolvedGroupId)
              .maybeSingle();
          if (cgCheck != null) {
            return cId;
          }
        }
      }
      // Or reuse the existing content_id
      return list.first['content_id'] as String;
    }

    // 3. Brand new video from video_library — create content and videos records
    final libVideo = await _safeClient
        .from('video_library')
        .select(
          'id, tenant_id, title, description, bunny_video_id, duration_seconds',
        )
        .eq('id', videoId)
        .maybeSingle();

    if (libVideo != null) {
      final effTenantId = tenantId ?? (libVideo['tenant_id'] as String);
      final effTitle = title.trim().isNotEmpty
          ? title.trim()
          : (libVideo['title'] as String);

      final contentInsert = await _safeClient
          .from('content')
          .insert({
            'tenant_id': effTenantId,
            'group_id': resolvedGroupId.isNotEmpty ? resolvedGroupId : null,
            'title': effTitle,
            'description': libVideo['description'],
            'type': 'video',
            'status': 'published',
            'sort_order': 0,
          })
          .select('id')
          .single();

      final newContentId = contentInsert['id'] as String;

      await _safeClient.from('videos').insert({
        'content_id': newContentId,
        'library_video_id': videoId,
        'provider': libVideo['provider'] ?? 'bunny',
        'provider_video_id': libVideo['provider_video_id'],
        'thumbnail_url': libVideo['thumbnail_url'],
        'duration': libVideo['duration'],
        'status': libVideo['status'] ?? 'ready',
      });

      return newContentId;
    }

    // Fallback: return videoId directly
    return videoId;
  }

  @override
  Future<void> assignBatchContentToGroup({
    required String groupId,
    required List<Map<String, dynamic>> items,
  }) async {
    final resolvedGroupId = GroupSlugResolver.toId(groupId);
    await _safeClient.rpc<void>(
      'assign_batch_content_to_group',
      params: {'p_group_id': resolvedGroupId, 'p_items': items},
    );
  }

  @override
  Future<void> linkLessonExam({
    required String contentId,
    required String examId,
  }) async {
    await _safeClient
        .from('content')
        .update({
          'associated_exam_id': examId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', contentId);

    try {
      await _safeClient
          .from('content_groups')
          .update({'associated_exam_id': examId})
          .eq('content_id', contentId);
    } catch (_) {}
  }

  @override
  Future<List<Map<String, dynamic>>> getGroupCourseProgress({
    required String groupId,
    String? studentId,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    if (!GroupSlugResolver.isUuid(resolvedGroupId)) {
      AppLogger.w(
        'ContentRemoteDataSource',
        'Cannot getGroupCourseProgress: group "$groupId" could not be resolved to a valid UUID',
      );
      return [];
    }
    final response = await _safeClient.rpc<dynamic>(
      'get_group_course_progress',
      params: {
        'p_group_id': resolvedGroupId,
        if (studentId != null) 'p_student_id': studentId,
      },
    );

    if (response is Map) {
      final lessons = response['lessons'];
      if (lessons is List) {
        return lessons.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } else if (response is List) {
      return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  @override
  Future<void> manualUnlockLesson({
    required String studentId,
    required String groupId,
    required String contentId,
    String? reason,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    if (!GroupSlugResolver.isUuid(resolvedGroupId)) return;
    await _safeClient.rpc<void>(
      'manual_unlock_lesson',
      params: {
        'p_student_id': studentId,
        'p_group_id': resolvedGroupId,
        'p_content_id': contentId,
        if (reason != null && reason.isNotEmpty) 'p_reason': reason,
      },
    );
  }

  @override
  Future<void> toggleLessonVisibility({
    required String contentId,
    required String groupId,
    required bool isPublished,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    if (!GroupSlugResolver.isUuid(resolvedGroupId)) return;
    await _safeClient.rpc<void>(
      'toggle_lesson_group_visibility',
      params: {
        'p_content_id': contentId,
        'p_group_id': resolvedGroupId,
        'p_is_published': isPublished,
      },
    );
  }

  @override
  Future<void> toggleAllLessonsVisibility({
    required String groupId,
    required bool isPublished,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    if (!GroupSlugResolver.isUuid(resolvedGroupId)) return;
    await _safeClient.rpc<void>(
      'toggle_group_all_content_visibility',
      params: {'p_group_id': resolvedGroupId, 'p_is_published': isPublished},
    );
  }

  @override
  Future<List<ChapterEntity>> getGroupChapters(String groupId) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    if (!GroupSlugResolver.isUuid(resolvedGroupId)) {
      return [];
    }
    final response = await _safeClient
        .from('chapters')
        .select(
          'id, group_id, title, sort_order, is_published, created_at, updated_at',
        )
        .eq('group_id', resolvedGroupId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    return (response as List<dynamic>)
        .map((json) => ChapterEntity.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ChapterEntity> createChapter({
    required String groupId,
    required String title,
    bool isPublished = true,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    final res = await _safeClient.rpc<dynamic>(
      'create_chapter',
      params: {
        'p_group_id': resolvedGroupId,
        'p_title': title.trim(),
        'p_is_published': isPublished,
      },
    );

    final map = res is Map<String, dynamic>
        ? res
        : Map<String, dynamic>.from(res as Map);
    return ChapterEntity(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? title.trim(),
      sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      isPublished: (map['is_published'] as bool?) ?? isPublished,
    );
  }

  @override
  Future<void> toggleChapterVisibility({
    required String chapterId,
    required bool isPublished,
  }) async {
    await _safeClient.rpc<void>(
      'toggle_chapter_visibility',
      params: {'p_chapter_id': chapterId, 'p_is_published': isPublished},
    );
  }

  @override
  Future<void> updateChapter({
    required String chapterId,
    required String title,
  }) async {
    await _safeClient.rpc<void>(
      'update_chapter',
      params: {'p_chapter_id': chapterId, 'p_title': title.trim()},
    );
  }

  @override
  Future<void> deleteChapter(String chapterId) async {
    await _safeClient.rpc<void>(
      'delete_chapter',
      params: {'p_chapter_id': chapterId},
    );
  }

  @override
  Future<void> setLessonChapter({
    required String contentId,
    required String groupId,
    String? chapterId,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    await _safeClient.rpc<void>(
      'set_lesson_chapter',
      params: {
        'p_content_id': contentId,
        'p_group_id': resolvedGroupId,
        if (chapterId != null && chapterId.isNotEmpty)
          'p_chapter_id': chapterId,
      },
    );
  }

  @override
  Future<void> reorderChapterLessons({
    required String groupId,
    required List<String> contentIdsInOrder,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    await _safeClient.rpc<void>(
      'reorder_chapter_lessons',
      params: {
        'p_group_id': resolvedGroupId,
        'p_content_ids': contentIdsInOrder,
      },
    );
  }

  @override
  Future<void> reorderCourseChapters({
    required String groupId,
    required List<String> chapterIdsInOrder,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    await _safeClient.rpc<void>(
      'reorder_course_chapters',
      params: {
        'p_group_id': resolvedGroupId,
        'p_chapter_ids': chapterIdsInOrder,
      },
    );
  }

  @override
  Future<void> removeLessonFromGroup({
    required String contentId,
    required String groupId,
  }) async {
    final resolvedGroupId = await _resolveGroupId(groupId);
    await _safeClient.rpc<void>(
      'remove_lesson_from_group',
      params: {'p_content_id': contentId, 'p_group_id': resolvedGroupId},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableExamsSummary() async {
    try {
      final res = await _safeClient
          .from('exams')
          .select('id, title, content:content!exams_content_id_fkey(group_id, title)')
          .order('created_at', ascending: false);

      return (res as List<dynamic>).map((e) {
        final map = e as Map<String, dynamic>;
        final contentMap = map['content'] as Map<String, dynamic>?;
        final title = map['title'] as String? ??
            contentMap?['title'] as String? ??
            'بدون عنوان';
        final gId = contentMap?['group_id'] as String?;
        return {
          'id': map['id'] as String,
          'title': title,
          if (gId != null) 'group_id': gId,
        };
      }).toList();
    } catch (e, stack) {
      AppLogger.e('ContentRemoteDataSource', 'Failed to fetch available exams summary', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<Map<String, String>?> getExamByContentId(String contentId) async {
    try {
      final res = await _safeClient
          .from('exams')
          .select('id, title')
          .eq('content_id', contentId)
          .maybeSingle();
      if (res != null && res['id'] != null) {
        return {
          'id': res['id'] as String,
          'title': (res['title'] as String?) ?? 'بدون عنوان',
        };
      }
      return null;
    } catch (e, stack) {
      AppLogger.e('ContentRemoteDataSource', 'Failed to fetch exam by contentId', error: e, stackTrace: stack);
      return null;
    }
  }

  @override
  Future<LessonAnalyticsEntity> getLessonAnalytics({
    required String lessonId,
    required String groupId,
    String? videoId,
    String? examId,
  }) async {
    try {
      String? vId = videoId;
      if (vId == null) {
        final videoRes = await _safeClient
            .from('videos')
            .select('id')
            .eq('content_id', lessonId)
            .maybeSingle();
        if (videoRes != null && videoRes['id'] != null) {
          vId = videoRes['id'] as String;
        }
      }

      final membersFuture = _safeClient
          .from('group_members')
          .select('id')
          .eq('group_id', groupId)
          .eq('status', 'active');

      final videoProgressFuture = vId != null
          ? _safeClient
              .from('video_progress')
              .select('completed, progress_seconds')
              .eq('video_id', vId)
          : Future.value(<dynamic>[]);

      final attemptsFuture = examId != null
          ? _safeClient
              .from('exam_attempts')
              .select('percentage')
              .eq('exam_id', examId)
              .inFilter('status', const ['submitted', 'completed'])
          : Future.value(<dynamic>[]);

      final results = await Future.wait<dynamic>([
        membersFuture,
        videoProgressFuture,
        attemptsFuture,
      ]);

      final countRes = results[0] as List<dynamic>;
      final total = countRes.length;

      final vpList = results[1] as List<dynamic>;
      final views = vpList
          .where((r) => (r['progress_seconds'] as int? ?? 0) > 0)
          .length;
      final completed = vpList.where((r) => r['completed'] == true).length;

      double? avgScore;
      final attempts = results[2] as List<dynamic>;
      if (attempts.isNotEmpty) {
        double sum = 0;
        int validCount = 0;
        for (final a in attempts) {
          final p = a['percentage'];
          if (p != null) {
            sum += (p is num ? p.toDouble() : double.tryParse(p.toString()) ?? 0);
            validCount++;
          }
        }
        if (validCount > 0) {
          avgScore = sum / validCount;
        }
      }

      return LessonAnalyticsEntity(
        totalStudents: total,
        totalViews: views,
        completedStudents: completed,
        averageQuizScore: avgScore,
      );
    } catch (e, stack) {
      AppLogger.e('ContentRemoteDataSource', 'Failed to fetch lesson analytics', error: e, stackTrace: stack);
      return const LessonAnalyticsEntity(
        totalStudents: 0,
        totalViews: 0,
        completedStudents: 0,
      );
    }
  }

  @override
  Future<ChapterAnalyticsEntity> getChapterAnalytics({
    required String groupId,
    required List<String> lessonIds,
    required List<String> examIds,
  }) async {
    try {
      final membersRes = await _safeClient
          .from('group_members')
          .select('student_id')
          .eq('group_id', groupId)
          .eq('status', 'active');
      final studentIds = (membersRes as List)
          .map((m) => m['student_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      final totalStudents = studentIds.length;

      final List<String> videoIds = [];
      if (lessonIds.isNotEmpty) {
        final videosRes = await _safeClient
            .from('videos')
            .select('id, content_id')
            .inFilter('content_id', lessonIds);
        for (final v in (videosRes as List)) {
          if (v['id'] != null) {
            videoIds.add(v['id'] as String);
          }
        }
      }

      int totalViews = 0;
      final Map<String, Set<String>> studentCompletedVideos = {};
      final Map<String, int> studentWatchedCount = {};

      if (videoIds.isNotEmpty) {
        final vpRes = await _safeClient
            .from('video_progress')
            .select('student_id, video_id, completed, progress_seconds')
            .inFilter('video_id', videoIds);

        for (final row in (vpRes as List)) {
          final sId = row['student_id'] as String?;
          final vId = row['video_id'] as String?;
          final progSec = row['progress_seconds'] as int? ?? 0;
          final isComp = row['completed'] == true;

          if (progSec > 0) {
            totalViews++;
            if (sId != null) {
              studentWatchedCount[sId] = (studentWatchedCount[sId] ?? 0) + 1;
            }
          }

          if (isComp && sId != null && vId != null) {
            studentCompletedVideos.putIfAbsent(sId, () => <String>{}).add(vId);
          }
        }
      }

      int completedCount = 0;
      int inProgressCount = 0;
      int notStartedCount = 0;

      for (final sId in studentIds) {
        final completedSet = studentCompletedVideos[sId] ?? {};
        if (videoIds.isNotEmpty && completedSet.length >= videoIds.length) {
          completedCount++;
        } else if ((studentWatchedCount[sId] ?? 0) > 0 || completedSet.isNotEmpty) {
          inProgressCount++;
        } else {
          notStartedCount++;
        }
      }

      double? avgScore;
      if (examIds.isNotEmpty) {
        final attemptsRes = await _safeClient
            .from('exam_attempts')
            .select('percentage')
            .inFilter('exam_id', examIds)
            .inFilter('status', const ['submitted', 'completed']);

        final attempts = attemptsRes as List;
        if (attempts.isNotEmpty) {
          double sum = 0;
          int validCount = 0;
          for (final a in attempts) {
            final p = a['percentage'];
            if (p != null) {
              sum += (p is num ? p.toDouble() : double.tryParse(p.toString()) ?? 0);
              validCount++;
            }
          }
          if (validCount > 0) {
            avgScore = sum / validCount;
          }
        }
      }

      return ChapterAnalyticsEntity(
        totalStudents: totalStudents,
        totalViews: totalViews,
        completedCount: completedCount,
        inProgressCount: inProgressCount,
        notStartedCount: notStartedCount,
        averageScore: avgScore,
      );
    } catch (e, stack) {
      AppLogger.e('ContentRemoteDataSource', 'Failed to fetch chapter analytics', error: e, stackTrace: stack);
      return const ChapterAnalyticsEntity(
        totalStudents: 0,
        totalViews: 0,
        completedCount: 0,
        inProgressCount: 0,
        notStartedCount: 0,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getContentGroupCustomizations(String contentId) async {
    try {
      final res = await _safeClient
          .from('content_groups')
          .select(
            'group_id, file_id, associated_exam_id, prerequisite_exam_id, sort_order, passing_score_override, '
            'file:files!content_groups_file_id_fkey(id, file_name), '
            'associated_exam:exams!content_groups_associated_exam_id_fkey(id, title), '
            'prerequisite_exam:exams!content_groups_prerequisite_exam_id_fkey(id, title)',
          )
          .eq('content_id', contentId);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e, stack) {
      AppLogger.e('ContentRemoteDataSource', 'Failed to fetch content group customizations', error: e, stackTrace: stack);
      return [];
    }
  }

  @override
  Future<GroupAnalyticsEntity> getGroupAnalytics({
    required String groupId,
    required List<ChapterEntity> chapters,
    required List<ContentEntity> lessons,
  }) async {
    try {
      // 1. Fetch active students in this group with user profiles
      final membersRes = await _safeClient
          .from('group_members')
          .select('student_id, users!inner(id, full_name, avatar_url)')
          .eq('group_id', groupId)
          .eq('status', 'active');

      final membersList = membersRes as List;
      final Map<String, Map<String, dynamic>> studentsMap = {};
      for (final row in membersList) {
        final sId = row['student_id'] as String?;
        final userObj = row['users'] as Map<String, dynamic>?;
        if (sId != null && userObj != null) {
          studentsMap[sId] = userObj;
        }
      }

      final totalStudents = studentsMap.length;

      // 2. Fetch all video IDs for this course's lessons
      final allLessonIds = lessons.map((l) => l.id).toList();
      final Map<String, String> videoIdToLessonId = {};
      final List<String> allVideoIds = [];

      if (allLessonIds.isNotEmpty) {
        final videosRes = await _safeClient
            .from('videos')
            .select('id, content_id')
            .inFilter('content_id', allLessonIds);

        for (final v in (videosRes as List)) {
          final vid = v['id'] as String?;
          final cid = v['content_id'] as String?;
          if (vid != null && cid != null) {
            allVideoIds.add(vid);
            videoIdToLessonId[vid] = cid;
          }
        }
      }

      // 3. Fetch video progress across all course videos
      int totalViews = 0;
      final Map<String, Set<String>> studentCompletedVideoIds = {};

      if (allVideoIds.isNotEmpty) {
        final vpRes = await _safeClient
            .from('video_progress')
            .select('student_id, video_id, completed, progress_seconds')
            .inFilter('video_id', allVideoIds);

        for (final row in (vpRes as List)) {
          final sId = row['student_id'] as String?;
          final vId = row['video_id'] as String?;
          final progSec = row['progress_seconds'] as int? ?? 0;
          final isComp = row['completed'] == true;

          if (progSec > 0) {
            totalViews++;
          }
          if (isComp && sId != null && vId != null) {
            studentCompletedVideoIds
                .putIfAbsent(sId, () => <String>{})
                .add(vId);
          }
        }
      }

      // 4. Calculate overall completion per student & identify attention list (< 50%)
      int sumStudentProgress = 0;
      final List<StudentAttentionItemEntity> attentionList = [];
      final totalVideosCount = allVideoIds.length;

      for (final entry in studentsMap.entries) {
        final sId = entry.key;
        final profile = entry.value;
        final name = (profile['full_name'] as String?)?.trim();
        final avatar = profile['avatar_url'] as String?;

        final completedCount = studentCompletedVideoIds[sId]?.length ?? 0;
        final rate = totalVideosCount > 0
            ? ((completedCount / totalVideosCount) * 100).round()
            : 0;

        sumStudentProgress += rate;

        if (rate < 50) {
          attentionList.add(
            StudentAttentionItemEntity(
              id: sId,
              name: name?.isNotEmpty == true ? name! : 'Student',
              avatarUrl: avatar,
              completionPercentage: rate,
            ),
          );
        }
      }

      final overallProgress = totalStudents > 0
          ? (sumStudentProgress ~/ totalStudents)
          : 0;

      // 5. Calculate overall quizzes average
      final allExamIds = lessons
          .expand((l) => [
                if (l.associatedExamId != null) l.associatedExamId!,
                ...l.attachedExams.map((e) => e.examId),
              ])
          .toSet()
          .toList();

      double? groupQuizAvg;
      final Map<String, double> examAvgMap = {};

      if (allExamIds.isNotEmpty) {
        final attemptsRes = await _safeClient
            .from('exam_attempts')
            .select('exam_id, percentage')
            .inFilter('exam_id', allExamIds)
            .inFilter('status', ['submitted', 'completed']);

        final Map<String, List<double>> examScores = {};
        for (final row in (attemptsRes as List)) {
          final eId = row['exam_id'] as String?;
          final p = row['percentage'];
          if (eId != null && p != null) {
            final val = p is num ? p.toDouble() : double.tryParse(p.toString());
            if (val != null) {
              examScores.putIfAbsent(eId, () => []).add(val);
            }
          }
        }

        double totalScoreSum = 0;
        int totalScoreCount = 0;
        for (final entry in examScores.entries) {
          final avg = entry.value.reduce((a, b) => a + b) / entry.value.length;
          examAvgMap[entry.key] = avg;
          totalScoreSum += entry.value.reduce((a, b) => a + b);
          totalScoreCount += entry.value.length;
        }

        if (totalScoreCount > 0) {
          groupQuizAvg = totalScoreSum / totalScoreCount;
        }
      }

      // 6. Chapter-by-chapter metrics breakdown
      final List<ChapterMetricItemEntity> chapterMetrics = [];
      for (final ch in chapters) {
        final chLessons = lessons.where((l) => l.chapterId == ch.id).toList();
        final chLessonIds = chLessons.map((l) => l.id).toSet();
        final chVideoIds = allVideoIds
            .where((vid) => chLessonIds.contains(videoIdToLessonId[vid]))
            .toList();

        int chCompletedStudents = 0;
        for (final sId in studentsMap.keys) {
          final completed = studentCompletedVideoIds[sId] ?? {};
          if (chVideoIds.isNotEmpty &&
              chVideoIds.every((vid) => completed.contains(vid))) {
            chCompletedStudents++;
          }
        }

        final chRate = totalStudents > 0
            ? ((chCompletedStudents / totalStudents) * 100).round()
            : 0;

        final chExamIds = chLessons
            .expand((l) => [
                  if (l.associatedExamId != null) l.associatedExamId!,
                  ...l.attachedExams.map((e) => e.examId),
                ])
            .toSet()
            .toList();
        double? chAvg;
        if (chExamIds.isNotEmpty) {
          final validAvgs = chExamIds
              .map((id) => examAvgMap[id])
              .whereType<double>()
              .toList();
          if (validAvgs.isNotEmpty) {
            chAvg = validAvgs.reduce((a, b) => a + b) / validAvgs.length;
          }
        }

        chapterMetrics.add(
          ChapterMetricItemEntity(
            chapterId: ch.id,
            title: ch.title,
            lessonCount: chLessons.length,
            completionRate: chRate,
            quizAvg: chAvg,
          ),
        );
      }

      return GroupAnalyticsEntity(
        totalStudents: totalStudents,
        totalViews: totalViews,
        overallProgress: overallProgress,
        overallQuizzesAverage: groupQuizAvg,
        chapterMetrics: chapterMetrics,
        studentsNeedingAttention: attentionList,
      );
    } catch (e, stack) {
      AppLogger.e('ContentRemoteDataSource', 'Failed to calculate group analytics', error: e, stackTrace: stack);
      return const GroupAnalyticsEntity(
        totalStudents: 0,
        totalViews: 0,
        overallProgress: 0,
        chapterMetrics: [],
        studentsNeedingAttention: [],
      );
    }
  }
}
