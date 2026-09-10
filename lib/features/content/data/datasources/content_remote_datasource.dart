import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/content_model.dart';
import '../models/file_attachment_model.dart';

abstract interface class ContentRemoteDataSource {
  /// Fetches content items for a specific group, ordered by sort_order asc
  Future<List<ContentModel>> getGroupContent({
    required String groupId,
    String? statusFilter,
  });

  /// Creates a content entry and optional file attachment record
  Future<ContentModel> createContent({
    required String groupId,
    required String title,
    String? description,
    required String type,
    required String status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
  });

  /// Updates content metadata
  Future<ContentModel> updateContent({
    required String contentId,
    String? title,
    String? description,
    String? type,
    String? status,
    int? sortOrder,
  });

  /// Updates lifecycle status and sets published_at if publishing
  Future<void> updateContentStatus({
    required String contentId,
    required String status,
  });

  /// Updates sort_order for multiple items atomically
  Future<void> reorderContentItems({
    required List<String> contentIdsInOrder,
  });

  /// Deletes a content item (and cascading file attachment)
  Future<void> deleteContent(String contentId);

  /// Generates a signed URL for a private storage asset
  Future<String> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
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
  }) async {
    var query = _safeClient
        .from('content')
        .select('*, files(*)')
        .eq('group_id', groupId);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }

    final response = await query
        .order('sort_order', ascending: true)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list
        .map((json) => ContentModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ContentModel> createContent({
    required String groupId,
    required String title,
    String? description,
    required String type,
    required String status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
  }) async {
    final currentUserId = _safeClient.auth.currentUser?.id;
    if (currentUserId == null) {
      throw const AuthException('AUTH_REQUIRED: User not authenticated');
    }

    // ⚡ Performance: نجلب tenant_id من JWT claims مباشرةً
    // بدلاً من SELECT إضافي من جدول users — توفير ~400ms
    final userMeta = _safeClient.auth.currentUser?.userMetadata;
    final tenantId = userMeta?['tenant_id'] as String?;

    if (tenantId == null) {
      // احتياطي: إذا لم يكن في الـ JWT metadata نجلبه مرة واحدة فقط
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
        tenantId: resolvedTenantId,
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
      tenantId: tenantId,
    );
  }

  Future<ContentModel> _createContentInternal({
    required String groupId,
    required String title,
    String? description,
    required String type,
    required String status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    required String tenantId,
  }) async {

    final now = DateTime.now().toUtc().toIso8601String();
    final publishedAt = status == 'published' ? now : null;

    // Calculate max sort_order if not provided
    var order = sortOrder;
    if (order == null) {
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

    final insertPayload = {
      'tenant_id': tenantId,
      'group_id': groupId,
      'title': title,
      if (description != null) 'description': description,
      'type': type,
      'status': status,
      'sort_order': order,
      if (publishedAt != null) 'published_at': publishedAt,
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
      final filePayload = {
        'tenant_id': tenantId,
        'content_id': contentId,
        'storage_path': storagePath,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_size': fileSize ?? 0,
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
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updatePayload = <String, dynamic>{
      'updated_at': now,
    };

    if (title != null) updatePayload['title'] = title;
    if (description != null) updatePayload['description'] = description;
    if (type != null) updatePayload['type'] = type;
    if (sortOrder != null) updatePayload['sort_order'] = sortOrder;

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

    await _safeClient
        .from('content')
        .update(updatePayload)
        .eq('id', contentId);
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
    int expiresInSeconds = 3600,
  }) async {
    final signedUrl = await _safeClient.storage
        .from('group-content')
        .createSignedUrl(storagePath, expiresInSeconds);
    return signedUrl;
  }
}
