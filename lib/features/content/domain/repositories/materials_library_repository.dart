import '../../../../core/errors/result.dart';
import '../entities/library_material_entity.dart';
import '../entities/material_folder_entity.dart';

abstract interface class MaterialsLibraryRepository {
  /// Fetches folders at a specific hierarchy level (parentId null = root folders)
  Future<Result<List<MaterialFolderEntity>>> getFolders({String? parentId});

  /// Fetches all folders in the tenant (used for folder picker/moving items)
  Future<Result<List<MaterialFolderEntity>>> getAllFolders();

  /// Creates a new material folder
  Future<Result<MaterialFolderEntity>> createFolder({
    required String name,
    String? parentId,
    String? color,
    String? icon,
  });

  /// Updates folder name, color, or icon
  Future<Result<MaterialFolderEntity>> updateFolder({
    required String id,
    required String name,
    String? color,
    String? icon,
  });

  /// Deletes a folder and cascades to subfolders (materials in it have folder_id set to null)
  Future<Result<void>> deleteFolder(String id);

  /// Fetches library materials with optional folder filter, search, and pagination
  Future<Result<List<LibraryMaterialEntity>>> getMaterials({
    String? folderId,
    String? search,
    String? mimeTypeFilter,
    int page = 0,
    int pageSize = 30,
  });

  /// Fetches a single library material by ID
  Future<Result<LibraryMaterialEntity>> getMaterialById(String id);

  /// Smart check for duplicate material using SHA-256 hash or file_name + file_size
  Future<Result<LibraryMaterialEntity?>> checkDuplicate({
    String? fileHash,
    String? fileName,
    int? fileSize,
  });

  /// Uploads binary file to storage, creates material_library record, and returns entity
  Future<Result<LibraryMaterialEntity>> uploadMaterial({
    required String title,
    String? description,
    String? folderId,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
    String? fileHash,
  });

  /// Updates material metadata (title, description, folderId)
  Future<Result<LibraryMaterialEntity>> updateMaterial({
    required String id,
    required String title,
    String? description,
    String? folderId,
  });

  /// Moves a material into a different folder or root
  Future<Result<LibraryMaterialEntity>> moveMaterial({
    required String id,
    String? targetFolderId,
  });

  /// Deletes a material from the library and optionally storage
  Future<Result<void>> deleteMaterial(String id);

  /// Generates a signed URL for viewing/downloading the file
  Future<Result<String>> getSignedUrl(
    String storagePath, {
    String? storageProvider,
    int expiresInSeconds = 3600,
  });

  /// Atomically links a library material to a lecture/content item
  Future<Result<String>> linkToLecture({
    required String libraryMaterialId,
    required String contentId,
    required String tenantId,
  });
}
