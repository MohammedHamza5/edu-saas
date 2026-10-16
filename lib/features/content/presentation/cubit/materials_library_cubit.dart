import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/library_material_entity.dart';
import '../../domain/entities/material_folder_entity.dart';
import '../../domain/repositories/materials_library_repository.dart';
import 'materials_library_state.dart';

class MaterialsLibraryCubit extends Cubit<MaterialsLibraryState> {
  final MaterialsLibraryRepository _repository;

  MaterialsLibraryCubit({
    required MaterialsLibraryRepository repository,
  })  : _repository = repository,
        super(const MaterialsLibraryState());

  Future<void> loadFolder({
    MaterialFolderEntity? folder,
    bool forceRefresh = false,
  }) async {
    final nextBreadcrumbs = <MaterialFolderEntity>[];
    if (folder != null) {
      final existingIndex =
          state.breadcrumbs.indexWhere((b) => b.id == folder.id);
      if (existingIndex >= 0) {
        nextBreadcrumbs.addAll(state.breadcrumbs.sublist(0, existingIndex + 1));
      } else {
        nextBreadcrumbs.addAll(state.breadcrumbs);
        nextBreadcrumbs.add(folder);
      }
    }

    final cacheKey = AppCache.userKey(
      'mat_f_${folder?.id ?? "root"}_${state.mimeTypeFilter ?? "all"}',
    );

    if (!forceRefresh) {
      final cached = AppCache.materials.getStale(cacheKey);
      if (cached is ({
        List<MaterialFolderEntity> folders,
        List<LibraryMaterialEntity> materials,
      })) {
        emit(state.copyWith(
          status: MaterialsLibraryStatus.loaded,
          currentFolder: () => folder,
          breadcrumbs: nextBreadcrumbs,
          folders: cached.folders,
          materials: cached.materials,
          hasMoreMaterials: cached.materials.length >= 30,
          searchQuery: '',
          page: 0,
          errorMessage: () => null,
        ));
        if (AppCache.materials.has(cacheKey)) {
          return; // Instant 0ms return on fresh cache!
        }
      }
    }

    if (state.status != MaterialsLibraryStatus.loaded) {
      emit(state.copyWith(
        status: MaterialsLibraryStatus.loading,
        currentFolder: () => folder,
        breadcrumbs: nextBreadcrumbs,
        folders: const [],
        materials: const [],
        searchQuery: '',
        page: 0,
        errorMessage: () => null,
      ));
    }

    // Parallel fetch for instant loading
    final (foldersRes, materialsRes) = await (
      _repository.getFolders(parentId: folder?.id),
      _repository.getMaterials(
        folderId: folder?.id,
        page: 0,
        pageSize: 30,
        mimeTypeFilter: state.mimeTypeFilter,
      ),
    ).wait;

    if (foldersRes.isFailure || materialsRes.isFailure) {
      if (state.status != MaterialsLibraryStatus.loaded) {
        final error = foldersRes.failureOrNull?.message ??
            materialsRes.failureOrNull?.message ??
            'Failed to load library content';
        emit(state.copyWith(
          status: MaterialsLibraryStatus.error,
          errorMessage: () => error,
        ));
      }
      return;
    }

    final folders = foldersRes.dataOrNull ?? [];
    final materials = materialsRes.dataOrNull ?? [];

    AppCache.materials.put(cacheKey, (folders: folders, materials: materials));

    emit(state.copyWith(
      status: MaterialsLibraryStatus.loaded,
      folders: folders,
      materials: materials,
      hasMoreMaterials: materials.length >= 30,
      page: 0,
    ));
  }

  Future<void> navigateToBreadcrumb(int index) async {
    if (index < 0) {
      await loadFolder(folder: null);
      return;
    }
    if (index < state.breadcrumbs.length) {
      final target = state.breadcrumbs[index];
      await loadFolder(folder: target);
    }
  }

  Future<void> search(String query) async {
    final clean = query.trim();
    emit(state.copyWith(
      searchQuery: clean,
      page: 0,
      status: MaterialsLibraryStatus.loading,
    ));

    final materialsRes = await _repository.getMaterials(
      folderId: clean.isEmpty ? state.currentFolder?.id : null,
      search: clean.isNotEmpty ? clean : null,
      mimeTypeFilter: state.mimeTypeFilter,
      page: 0,
      pageSize: 40,
    );

    if (materialsRes.isFailure) {
      emit(state.copyWith(
        status: MaterialsLibraryStatus.error,
        errorMessage: () =>
            materialsRes.failureOrNull?.message ?? 'Search failed',
      ));
      return;
    }

    final materials = materialsRes.dataOrNull ?? [];
    emit(state.copyWith(
      status: MaterialsLibraryStatus.loaded,
      materials: materials,
      hasMoreMaterials: materials.length >= 40,
      page: 0,
    ));
  }

  Future<void> setFilter(String? mimeType) async {
    emit(state.copyWith(
      mimeTypeFilter: () => mimeType,
      status: MaterialsLibraryStatus.loading,
      page: 0,
    ));

    final materialsRes = await _repository.getMaterials(
      folderId: state.currentFolder?.id,
      search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
      mimeTypeFilter: mimeType,
      page: 0,
      pageSize: 30,
    );

    if (materialsRes.isFailure) {
      emit(state.copyWith(
        status: MaterialsLibraryStatus.error,
        errorMessage: () => materialsRes.failureOrNull?.message,
      ));
      return;
    }

    final materials = materialsRes.dataOrNull ?? [];
    emit(state.copyWith(
      status: MaterialsLibraryStatus.loaded,
      materials: materials,
      hasMoreMaterials: materials.length >= 30,
    ));
  }

  Future<void> loadMoreMaterials() async {
    if (!state.hasMoreMaterials || state.isLoading) return;

    final nextPage = state.page + 1;
    final materialsRes = await _repository.getMaterials(
      folderId: state.searchQuery.isEmpty ? state.currentFolder?.id : null,
      search: state.searchQuery.isNotEmpty ? state.searchQuery : null,
      mimeTypeFilter: state.mimeTypeFilter,
      page: nextPage,
      pageSize: 30,
    );

    if (materialsRes.isSuccess) {
      final newItems = materialsRes.dataOrNull ?? [];
      emit(state.copyWith(
        materials: [...state.materials, ...newItems],
        hasMoreMaterials: newItems.length >= 30,
        page: nextPage,
      ));
    }
  }

  Future<bool> createFolder(
    String name, {
    String? color,
    String? icon,
  }) async {
    final res = await _repository.createFolder(
      name: name,
      parentId: state.currentFolder?.id,
      color: color,
      icon: icon,
    );

    if (res.isSuccess && res.dataOrNull != null) {
      AppCache.materials.clear();
      emit(state.copyWith(
        folders: [res.dataOrNull!, ...state.folders],
      ));
      return true;
    }
    return false;
  }

  Future<bool> updateFolder(
    String id,
    String name, {
    String? color,
    String? icon,
  }) async {
    final res = await _repository.updateFolder(
      id: id,
      name: name,
      color: color,
      icon: icon,
    );

    if (res.isSuccess && res.dataOrNull != null) {
      AppCache.materials.clear();
      final updated = res.dataOrNull!;
      final updatedFolders = state.folders.map((f) {
        return f.id == id ? updated : f;
      }).toList();

      emit(state.copyWith(folders: updatedFolders));
      return true;
    }
    return false;
  }

  Future<bool> deleteFolder(String id) async {
    final res = await _repository.deleteFolder(id);
    if (res.isSuccess) {
      AppCache.materials.clear();
      emit(state.copyWith(
        folders: state.folders.where((f) => f.id != id).toList(),
      ));
      return true;
    }
    return false;
  }

  void updateUploadStatus({
    required bool isUploading,
    double progress = 0.0,
    String? fileName,
    int totalFiles = 0,
    int currentIndex = 0,
    String? error,
  }) {
    emit(state.copyWith(
      isUploading: isUploading,
      uploadProgress: progress,
      uploadingFileName: () => fileName,
      uploadTotalFiles: totalFiles,
      uploadCurrentIndex: currentIndex,
      lastUploadError: () => error,
    ));
  }

  Future<LibraryMaterialEntity?> uploadMaterial({
    required String title,
    String? description,
    required String fileName,
    required List<int> fileBytes,
    required String mimeType,
    String? fileHash,
  }) async {
    final res = await _repository.uploadMaterial(
      title: title,
      description: description,
      folderId: state.currentFolder?.id,
      fileName: fileName,
      fileBytes: fileBytes,
      mimeType: mimeType,
      fileHash: fileHash,
    );

    if (res.isSuccess && res.dataOrNull != null) {
      AppCache.materials.clear();
      final item = res.dataOrNull!;
      final existingIndex = state.materials.indexWhere((m) => m.id == item.id);
      if (existingIndex >= 0) {
        final updated = List<LibraryMaterialEntity>.from(state.materials);
        updated[existingIndex] = item;
        emit(state.copyWith(materials: updated));
      } else {
        emit(state.copyWith(materials: [item, ...state.materials]));
      }
      return item;
    }
    return null;
  }

  Future<LibraryMaterialEntity?> checkDuplicate({
    String? fileHash,
    String? fileName,
    int? fileSize,
  }) async {
    final res = await _repository.checkDuplicate(
      fileHash: fileHash,
      fileName: fileName,
      fileSize: fileSize,
    );
    return res.dataOrNull;
  }

  Future<bool> updateMaterial(
    String id,
    String title, {
    String? description,
  }) async {
    final res = await _repository.updateMaterial(
      id: id,
      title: title,
      description: description,
      folderId: state.currentFolder?.id,
    );

    if (res.isSuccess && res.dataOrNull != null) {
      AppCache.materials.clear();
      final updated = res.dataOrNull!;
      final updatedList =
          state.materials.map((m) => m.id == id ? updated : m).toList();
      emit(state.copyWith(materials: updatedList));
      return true;
    }
    return false;
  }

  Future<bool> moveMaterial(String id, String? targetFolderId) async {
    final res = await _repository.moveMaterial(
      id: id,
      targetFolderId: targetFolderId,
    );

    if (res.isSuccess) {
      AppCache.materials.clear();
      if (targetFolderId != state.currentFolder?.id) {
        emit(state.copyWith(
          materials: state.materials.where((m) => m.id != id).toList(),
        ));
      }
      return true;
    }
    return false;
  }

  Future<bool> deleteMaterial(String id) async {
    final res = await _repository.deleteMaterial(id);
    if (res.isSuccess) {
      AppCache.materials.clear();
      emit(state.copyWith(
        materials: state.materials.where((m) => m.id != id).toList(),
      ));
      return true;
    }
    return false;
  }
}
