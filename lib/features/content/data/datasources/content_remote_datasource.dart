import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
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

  /// Updates sort_order for multiple items atomically
  Future<void> reorderContentItems({required List<String> contentIdsInOrder});

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
}

class ContentRemoteDataSourceImpl implements ContentRemoteDataSource {
  final SupabaseClient? _client;

  ContentRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<List<ContentModel>> getGroupContent({
    required String groupId,
    String? statusFilter,
    int page = 0,
    int pageSize = 20,
  }) async {
    // Fetch any content linked to this group via the junction table content_groups with group overrides
    final junctionRes = await _safeClient
        .from('content_groups')
        .select(
          'content_id, file_id, associated_exam_id, prerequisite_exam_id, sort_order, custom_title, '
          'file:files!content_groups_file_id_fkey(*), '
          'associated_exam:exams!content_groups_associated_exam_id_fkey(id, title), '
          'prerequisite_exam:exams!content_groups_prerequisite_exam_id_fkey(id, title, passing_score)',
        )
        .eq('group_id', groupId);

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
          '*, files(*), videos(id, status, provider_video_id, provider), '
          'content_groups(group_id, groups(name)), '
          'associated_exam:exams!content_associated_exam_id_fkey(id, title), '
          'prerequisite_exam:exams!content_prerequisite_exam_id_fkey(id, title, passing_score)',
        );

    if (junctionIds.isEmpty) {
      query = query.eq('group_id', groupId);
    } else {
      final joinedIds = junctionIds.join(',');
      query = query.or('group_id.eq.$groupId,id.in.($joinedIds)');
    }

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    final list = response as List<dynamic>;
    final models = list
        .map((json) => ContentModel.fromJson(json as Map<String, dynamic>))
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
          assocExamTitle = assocObj?['title'] as String? ?? assocExamTitle;
        }

        String? prereqExamId = m.prerequisiteExamId;
        String? prereqExamTitle = m.prerequisiteExamTitle;
        int? prereqPassingScore = m.prerequisitePassingScore;
        if (cfg['prerequisite_exam_id'] != null) {
          prereqExamId = cfg['prerequisite_exam_id'] as String?;
          final prereqObj = cfg['prerequisite_exam'] as Map<String, dynamic>?;
          prereqExamTitle = prereqObj?['title'] as String? ?? prereqExamTitle;
          prereqPassingScore =
              (prereqObj?['passing_score'] as num?)?.toInt() ??
              prereqPassingScore;
        }

        int sortOrder = m.sortOrder;
        if (cfg['sort_order'] != null &&
            (cfg['sort_order'] as num).toInt() > 0) {
          sortOrder = (cfg['sort_order'] as num).toInt();
        }

        String title = m.title;
        if (cfg['custom_title'] != null &&
            cfg['custom_title'].toString().trim().isNotEmpty) {
          title = cfg['custom_title'].toString().trim();
        }

        models[i] =
            m.copyWith(
                  title: title,
                  file: customFile,
                  associatedExamId: assocExamId,
                  associatedExamTitle: assocExamTitle,
                  prerequisiteExamId: prereqExamId,
                  prerequisiteExamTitle: prereqExamTitle,
                  prerequisitePassingScore: prereqPassingScore,
                  sortOrder: sortOrder,
                )
                as ContentModel;
      }
    }

    models.sort((a, b) {
      final s = a.sortOrder.compareTo(b.sortOrder);
      if (s != 0) return s;
      return b.createdAt.compareTo(a.createdAt);
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
          final passScore = (examObj?['passing_score'] as num?)?.toInt() ?? 60;
          final score = (att['score'] as num?)?.toInt() ?? 0;
          final pct = (att['percentage'] as num?)?.toDouble() ?? 0.0;
          if (score >= passScore || pct >= passScore) {
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

          models[i] =
              models[i].copyWith(
                    isLocked: locked,
                    isVideoCompleted: isVideoCompleted,
                    videoProgressPercentage: progressPct,
                    isExamPassed: isExamPassed,
                  )
                  as ContentModel;

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
      final existing = await _safeClient
          .from('content')
          .select('sort_order')
          .eq('group_id', groupId)
          .order('sort_order', ascending: false)
          .limit(1);
      final existingList = existing as List<dynamic>;
      order = existingList.isNotEmpty
          ? ((existingList.first['sort_order'] as num?)?.toInt() ?? 0) + 1
          : 0;
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
      if (fileBytes != null && fileBytes.isNotEmpty) {
        await _safeClient.storage
            .from('group-content')
            .uploadBinary(
              storagePath,
              Uint8List.fromList(fileBytes),
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );
      }

      final filePayload = {
        'tenant_id': tenantId,
        'content_id': contentId,
        'storage_path': storagePath,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size': fileSize ?? (fileBytes?.length ?? 0),
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
      if (fileBytes != null && fileBytes.isNotEmpty) {
        await _safeClient.storage
            .from('group-content')
            .uploadBinary(
              storagePath,
              Uint8List.fromList(fileBytes),
              fileOptions: FileOptions(contentType: mimeType, upsert: true),
            );
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
              'storage_path': storagePath,
              'file_name': fileName,
              'mime_type': mimeType,
              'file_size': fileSize ?? (fileBytes?.length ?? 0),
              'created_at': now,
            })
            .eq('id', existingId);
      } else {
        await _safeClient.from('files').insert({
          'tenant_id': tenantId,
          'content_id': contentId,
          'storage_path': storagePath,
          'file_name': fileName,
          'mime_type': mimeType,
          'file_size': fileSize ?? (fileBytes?.length ?? 0),
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

    await _safeClient.from('content').update(updatePayload).eq('id', contentId);
  }

  @override
  Future<void> reorderContentItems({
    required List<String> contentIdsInOrder,
  }) async {
    // ⚡ Performance: RPC واحد بدلاً من N رحلات HTTP
    // ترتيب 10 عناصر = 10 × ~400ms = 4s  →  RPC واحد = ~80ms
    await _safeClient.rpc<void>(
      'reorder_content_items',
      params: {'p_ids': contentIdsInOrder},
    );
  }

  @override
  Future<void> deleteContent(String contentId) async {
    await _safeClient.from('content').delete().eq('id', contentId);
  }

  @override
  Future<String> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 900,
  }) async {
    final signedUrl = await _safeClient.storage
        .from('group-content')
        .createSignedUrl(storagePath, expiresInSeconds);
    return signedUrl;
  }

  @override
  Future<List<ContentModel>> getCentralVideoBank({
    int page = 0,
    int pageSize = 100,
  }) async {
    final startIndex = page * pageSize;
    final endIndex = startIndex + pageSize - 1;

    final response = await _safeClient
        .from('content')
        .select(
          '*, files(*), videos(*), content_groups(group_id, groups(name)), '
          'associated_exam:exams!content_associated_exam_id_fkey(id, title), '
          'prerequisite_exam:exams!content_prerequisite_exam_id_fkey(id, title, passing_score)',
        )
        .inFilter('type', ['video', 'youtube'])
        .order('created_at', ascending: false)
        .range(startIndex, endIndex);

    final list = response as List<dynamic>;
    return list
        .map((e) => ContentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> assignContentToGroups({
    required String contentId,
    required List<String> groupIds,
    List<Map<String, dynamic>>? groupConfigs,
  }) async {
    await _safeClient.rpc<void>(
      'assign_content_to_groups',
      params: {
        'p_content_id': contentId,
        'p_group_ids': groupIds,
        'p_group_configs': groupConfigs ?? [],
      },
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
  }

  @override
  Future<List<Map<String, dynamic>>> getGroupCourseProgress({
    required String groupId,
    String? studentId,
  }) async {
    final response = await _safeClient.rpc<List<dynamic>>(
      'get_group_course_progress',
      params: {
        'p_group_id': groupId,
        if (studentId != null) 'p_student_id': studentId,
      },
    );

    return response.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> manualUnlockLesson({
    required String studentId,
    required String groupId,
    required String contentId,
    String? reason,
  }) async {
    await _safeClient.rpc<void>(
      'manual_unlock_lesson',
      params: {
        'p_student_id': studentId,
        'p_group_id': groupId,
        'p_content_id': contentId,
        if (reason != null && reason.isNotEmpty) 'p_reason': reason,
      },
    );
  }
}
