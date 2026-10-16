import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/library_material_entity.dart';
import '../../domain/entities/material_folder_entity.dart';
import '../../domain/repositories/materials_library_repository.dart';
import '../datasources/materials_library_remote_datasource.dart';

class MaterialsLibraryRepositoryImpl implements MaterialsLibraryRepository {
  final MaterialsLibraryRemoteDataSource _remoteDataSource;

  MaterialsLibraryRepositoryImpl({
    required MaterialsLibraryRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  @override
  Future<Result<List<MaterialFolderEntity>>> getFolders({
    String? parentId,
  }) async {
    try {
      final folders = await _remoteDataSource.getFolders(parentId: parentId);
      return Result.success(folders);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<MaterialFolderEntity>>> getAllFolders() async {
    try {
      final folders = await _remoteDataSource.getAllFolders();
      return Result.success(folders);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<MaterialFolderEntity>> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
  }) async {
    try {
      final folder = await _remoteDataSource.createFolder(
        name: name,
        parentId: parentId,
        color: color,
        icon: icon,
      );
      return Result.success(folder);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<MaterialFolderEntity>> updateFolder({
    required String id,
    required String name,
    String? color,
    String? icon,
  }) async {
    try {
      final folder = await _remoteDataSource.updateFolder(
        id: id,
        name: name,
        color: color,
        icon: icon,
      );
      return Result.success(folder);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteFolder(String id) async {
    try {
      await _remoteDataSource.deleteFolder(id);
      return const Result.success(null);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<List<LibraryMaterialEntity>>> getMaterials({
    String? folderId,
    String? search,
    String? mimeTypeFilter,
    int page = 0,
    int pageSize = 30,
  }) async {
    try {
      final materials = await _remoteDataSource.getMaterials(
        folderId: folderId,
        search: search,
        mimeTypeFilter: mimeTypeFilter,
        page: page,
        pageSize: pageSize,
      );
      return Result.success(materials);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<LibraryMaterialEntity>> getMaterialById(String id) async {
    try {
      final material = await _remoteDataSource.getMaterialById(id);
      return Result.success(material);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<LibraryMaterialEntity?>> checkDuplicate({
    String? fileHash,
    String? fileName,
    int? fileSize,
  }) async {
    try {
      final duplicate = await _remoteDataSource.checkDuplicate(
        fileHash: fileHash,
        fileName: fileName,
        fileSize: fileSize,
      );
      return Result.success(duplicate);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<LibraryMaterialEntity>> uploadMaterial({
    required String title,
    String? description,
    String? folderId,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
    String? fileHash,
  }) async {
    try {
      final material = await _remoteDataSource.uploadMaterial(
        title: title,
        description: description,
        folderId: folderId,
        fileName: fileName,
        fileBytes: fileBytes,
        mimeType: mimeType,
        fileHash: fileHash,
      );
      return Result.success(material);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<LibraryMaterialEntity>> updateMaterial({
    required String id,
    required String title,
    String? description,
    String? folderId,
  }) async {
    try {
      final material = await _remoteDataSource.updateMaterial(
        id: id,
        title: title,
        description: description,
        folderId: folderId,
      );
      return Result.success(material);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<LibraryMaterialEntity>> moveMaterial({
    required String id,
    String? targetFolderId,
  }) async {
    try {
      final material = await _remoteDataSource.moveMaterial(
        id: id,
        targetFolderId: targetFolderId,
      );
      return Result.success(material);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<void>> deleteMaterial(String id) async {
    try {
      await _remoteDataSource.deleteMaterial(id);
      return const Result.success(null);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> getSignedUrl(
    String storagePath, {
    String? storageProvider,
    int expiresInSeconds = 3600,
  }) async {
    try {
      final url = await _remoteDataSource.getSignedUrl(
        storagePath,
        storageProvider: storageProvider,
        expiresInSeconds: expiresInSeconds,
      );
      return Result.success(url);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Result<String>> linkToLecture({
    required String libraryMaterialId,
    required String contentId,
    required String tenantId,
  }) async {
    try {
      final fileId = await _remoteDataSource.linkToLecture(
        libraryMaterialId: libraryMaterialId,
        contentId: contentId,
        tenantId: tenantId,
      );
      return Result.success(fileId);
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Result.failure(ServerFailure(e.toString()));
    }
  }
}
