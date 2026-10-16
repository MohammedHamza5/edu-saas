import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_service.dart';
import '../models/library_material_model.dart';
import '../models/material_folder_model.dart';

abstract interface class MaterialsLibraryRemoteDataSource {
  Future<List<MaterialFolderModel>> getFolders({String? parentId});

  Future<List<MaterialFolderModel>> getAllFolders();

  Future<MaterialFolderModel> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
  });

  Future<MaterialFolderModel> updateFolder({
    required String id,
    required String name,
    String? color,
    String? icon,
  });

  Future<void> deleteFolder(String id);

  Future<List<LibraryMaterialModel>> getMaterials({
    String? folderId,
    String? search,
    String? mimeTypeFilter,
    int page = 0,
    int pageSize = 30,
  });

  Future<LibraryMaterialModel> getMaterialById(String id);

  Future<LibraryMaterialModel?> checkDuplicate({
    String? fileHash,
    String? fileName,
    int? fileSize,
  });

  Future<LibraryMaterialModel> uploadMaterial({
    required String title,
    String? description,
    String? folderId,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
    String? fileHash,
  });

  Future<LibraryMaterialModel> updateMaterial({
    required String id,
    required String title,
    String? description,
    String? folderId,
  });

  Future<LibraryMaterialModel> moveMaterial({
    required String id,
    String? targetFolderId,
  });

  Future<void> deleteMaterial(String id);

  Future<String> getSignedUrl(
    String storagePath, {
    String? storageProvider,
    int expiresInSeconds = 3600,
  });

  Future<String> linkToLecture({
    required String libraryMaterialId,
    required String contentId,
    required String tenantId,
  });
}

class MaterialsLibraryRemoteDataSourceImpl
    implements MaterialsLibraryRemoteDataSource {
  final SupabaseClient? _client;

  MaterialsLibraryRemoteDataSourceImpl({SupabaseClient? client})
      : _client = client;

  SupabaseClient get _c => _client ?? SupabaseService.client;
  String? _cachedTenantId;

  Future<String> _resolveTenantId() async {
    if (_cachedTenantId != null && _cachedTenantId!.isNotEmpty) {
      return _cachedTenantId!;
    }
    final cached = SupabaseService.currentTenantId;
    if (cached != null && cached.isNotEmpty) {
      _cachedTenantId = cached;
      return cached;
    }
    final uid = _c.auth.currentUser?.id;
    if (uid != null) {
      final userRow = await _c
          .from('users')
          .select('tenant_id')
          .eq('id', uid)
          .maybeSingle();
      if (userRow != null && userRow['tenant_id'] != null) {
        _cachedTenantId = userRow['tenant_id'] as String;
        return _cachedTenantId!;
      }
    }
    throw const ServerException(
      'Tenant ID could not be resolved',
      code: 'TENANT_NOT_FOUND',
    );
  }

  @override
  Future<List<MaterialFolderModel>> getFolders({String? parentId}) async {
    try {
      final tenantId = await _resolveTenantId();
      var query = _c
          .from('material_folders_with_counts')
          .select()
          .eq('tenant_id', tenantId);

      if (parentId == null) {
        query = query.filter('parent_id', 'is', 'null');
      } else {
        query = query.eq('parent_id', parentId);
      }

      final res = await query
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      return (res as List<dynamic>)
          .map((json) =>
              MaterialFolderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'FETCH_FOLDERS_FAILED');
    }
  }

  @override
  Future<List<MaterialFolderModel>> getAllFolders() async {
    try {
      final res = await _c
          .from('material_folders_with_counts')
          .select()
          .order('name', ascending: true);

      return (res as List<dynamic>)
          .map((json) =>
              MaterialFolderModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'FETCH_ALL_FOLDERS_FAILED');
    }
  }

  @override
  Future<MaterialFolderModel> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
  }) async {
    try {
      final tenantId = await _resolveTenantId();
      final payload = {
        'tenant_id': tenantId,
        'name': name.trim(),
        'parent_id': parentId,
        'color': color ?? '#EA580C',
        'icon': icon ?? 'folder',
      };

      final res = await _c
          .from('material_folders')
          .insert(payload)
          .select()
          .single();

      return MaterialFolderModel.fromJson(res);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'CREATE_FOLDER_FAILED');
    }
  }

  @override
  Future<MaterialFolderModel> updateFolder({
    required String id,
    required String name,
    String? color,
    String? icon,
  }) async {
    try {
      final updates = <String, dynamic>{
        'name': name.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (color != null) updates['color'] = color;
      if (icon != null) updates['icon'] = icon;

      final res = await _c
          .from('material_folders')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return MaterialFolderModel.fromJson(res);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'UPDATE_FOLDER_FAILED');
    }
  }

  @override
  Future<void> deleteFolder(String id) async {
    try {
      await _c.from('material_folders').delete().eq('id', id);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'DELETE_FOLDER_FAILED');
    }
  }

  @override
  Future<List<LibraryMaterialModel>> getMaterials({
    String? folderId,
    String? search,
    String? mimeTypeFilter,
    int page = 0,
    int pageSize = 30,
  }) async {
    try {
      final tenantId = await _resolveTenantId();
      var query = _c
          .from('material_library')
          .select()
          .eq('tenant_id', tenantId);

      final hasSearch = search != null && search.trim().isNotEmpty;
      if (!hasSearch) {
        if (folderId == null) {
          query = query.filter('folder_id', 'is', 'null');
        } else {
          query = query.eq('folder_id', folderId);
        }
      }

      if (hasSearch) {
        query = query.ilike('title', '%${search.trim()}%');
      }

      if (mimeTypeFilter != null && mimeTypeFilter.isNotEmpty) {
        query = query.ilike('mime_type', '%$mimeTypeFilter%');
      }

      final start = page * pageSize;
      final end = start + pageSize - 1;

      final res = await query
          .order('created_at', ascending: false)
          .range(start, end);

      return (res as List<dynamic>)
          .map((json) =>
              LibraryMaterialModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'FETCH_MATERIALS_FAILED');
    }
  }

  @override
  Future<LibraryMaterialModel> getMaterialById(String id) async {
    try {
      final res = await _c
          .from('material_library')
          .select()
          .eq('id', id)
          .single();

      return LibraryMaterialModel.fromJson(res);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'FETCH_MATERIAL_FAILED');
    }
  }

  @override
  Future<LibraryMaterialModel?> checkDuplicate({
    String? fileHash,
    String? fileName,
    int? fileSize,
  }) async {
    try {
      final res = await _c.rpc<dynamic>(
        'find_duplicate_material',
        params: {
          'p_file_hash': fileHash,
          'p_file_name': fileName,
          'p_file_size': fileSize ?? 0,
        },
      );

      if (res is Map<String, dynamic> && res['found'] == true) {
        final materialJson = res['material'] as Map<String, dynamic>?;
        if (materialJson != null) {
          return LibraryMaterialModel.fromJson(materialJson);
        }
      }
      return null;
    } catch (e) {
      // If RPC check fails or not supported, fail open gracefully
      return null;
    }
  }

  @override
  Future<LibraryMaterialModel> uploadMaterial({
    required String title,
    String? description,
    String? folderId,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
    String? fileHash,
  }) async {
    try {
      final tenantId = await _resolveTenantId();

      // 1. Calculate fast hash without blocking UI event loop
      String? computedHash = fileHash;
      if (computedHash == null) {
        if (fileBytes.length <= 2 * 1024 * 1024) {
          computedHash = sha256.convert(fileBytes).toString();
        } else {
          // Fast sample hash (first 1MB) prevents UI freezing on large PDFs
          final sample = fileBytes.sublist(0, 1024 * 1024);
          computedHash = sha256.convert(sample).toString();
        }
      }

      // 2. Smart deduplication check
      final existing = await checkDuplicate(
        fileHash: computedHash,
        fileName: fileName,
        fileSize: fileBytes.length,
      );

      if (existing != null) {
        // Reuse existing file in library immediately!
        return existing;
      }

      // 3. Fast direct upload to Supabase Storage ('group-content' bucket)
      final cleanFileName = fileName.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'materials/$tenantId/${timestamp}_$cleanFileName';

      final bytes = fileBytes is Uint8List
          ? fileBytes
          : Uint8List.fromList(fileBytes);

      await _c.storage.from('group-content').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      // 4. Create record in material_library
      final payload = {
        'tenant_id': tenantId,
        'folder_id': folderId,
        'title': title.trim().isNotEmpty ? title.trim() : fileName,
        'description': description?.trim(),
        'file_name': fileName,
        'storage_path': storagePath,
        'file_size': fileBytes.length,
        'mime_type': mimeType,
        'storage_provider': 'supabase',
        'file_hash': computedHash,
        'assigned_lectures_count': 0,
      };

      final res = await _c
          .from('material_library')
          .insert(payload)
          .select()
          .single();

      return LibraryMaterialModel.fromJson(res);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'UPLOAD_MATERIAL_FAILED');
    }
  }

  @override
  Future<LibraryMaterialModel> updateMaterial({
    required String id,
    required String title,
    String? description,
    String? folderId,
  }) async {
    try {
      final updates = <String, dynamic>{
        'title': title.trim(),
        'description': description?.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (folderId != null) {
        updates['folder_id'] = folderId;
      }

      final res = await _c
          .from('material_library')
          .update(updates)
          .eq('id', id)
          .select()
          .single();

      return LibraryMaterialModel.fromJson(res);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'UPDATE_MATERIAL_FAILED');
    }
  }

  @override
  Future<LibraryMaterialModel> moveMaterial({
    required String id,
    String? targetFolderId,
  }) async {
    try {
      final res = await _c
          .from('material_library')
          .update({
            'folder_id': targetFolderId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select()
          .single();

      return LibraryMaterialModel.fromJson(res);
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'MOVE_MATERIAL_FAILED');
    }
  }

  @override
  Future<void> deleteMaterial(String id) async {
    try {
      final mat = await getMaterialById(id);

      // Delete record from DB
      await _c.from('material_library').delete().eq('id', id);

      // Best effort cleanup from storage provider
      if (mat.storageProvider == 'r2') {
        try {
          await _c.functions.invoke(
            'r2-storage',
            body: {
              'action': 'delete-files',
              'storage_paths': [mat.storagePath],
            },
          );
        } catch (_) {}
      } else {
        try {
          await _c.storage.from('group-content').remove([mat.storagePath]);
        } catch (_) {}
      }
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'DELETE_MATERIAL_FAILED');
    }
  }

  @override
  Future<String> getSignedUrl(
    String storagePath, {
    String? storageProvider,
    int expiresInSeconds = 3600,
  }) async {
    // 1. Try Cloudflare R2 if provider is explicitly r2
    if (storageProvider == 'r2') {
      try {
        final r2Res = await _c.functions.invoke(
          'r2-storage',
          body: {
            'action': 'get-download-url',
            'storage_path': storagePath,
          },
        );

        if (r2Res.status == 200 && r2Res.data is Map<String, dynamic>) {
          final data = r2Res.data as Map<String, dynamic>;
          final downloadUrl = data['download_url'] as String?;
          if (downloadUrl != null && downloadUrl.isNotEmpty) {
            return downloadUrl;
          }
        }
      } catch (_) {
        // Fallback to Supabase Storage if R2 download URL fails
      }
    }

    // 2. Supabase Storage fallback
    try {
      final signedUrl = await _c.storage
          .from('group-content')
          .createSignedUrl(storagePath, expiresInSeconds);
      return signedUrl;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'GET_SIGNED_URL_FAILED');
    }
  }

  @override
  Future<String> linkToLecture({
    required String libraryMaterialId,
    required String contentId,
    required String tenantId,
  }) async {
    try {
      final mat = await getMaterialById(libraryMaterialId);

      // Resolve contentId defensively: if caller passed a library_video_id, find its content_id
      String resolvedContentId = contentId;
      final contentCheck = await _c
          .from('content')
          .select('id')
          .eq('id', contentId)
          .maybeSingle();

      if (contentCheck == null) {
        final videoRecord = await _c
            .from('videos')
            .select('content_id')
            .eq('library_video_id', contentId)
            .maybeSingle();
        if (videoRecord != null && videoRecord['content_id'] != null) {
          resolvedContentId = videoRecord['content_id'] as String;
        }
      }

      final payload = {
        'tenant_id': tenantId,
        'content_id': resolvedContentId,
        'library_material_id': libraryMaterialId,
        'storage_path': mat.storagePath,
        'file_name': mat.fileName,
        'mime_type': mat.mimeType,
        'file_size': mat.fileSize,
        'storage_provider': mat.storageProvider,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

      final res = await _c.from('files').insert(payload).select('id').single();

      return res['id'] as String;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ServerException(e.toString(), code: 'LINK_TO_LECTURE_FAILED');
    }
  }
}
