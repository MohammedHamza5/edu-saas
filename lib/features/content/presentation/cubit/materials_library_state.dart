import 'package:equatable/equatable.dart';
import '../../domain/entities/library_material_entity.dart';
import '../../domain/entities/material_folder_entity.dart';

enum MaterialsLibraryStatus { initial, loading, loaded, error }

class MaterialsLibraryState extends Equatable {
  final MaterialsLibraryStatus status;
  final List<MaterialFolderEntity> folders;
  final List<LibraryMaterialEntity> materials;
  final MaterialFolderEntity? currentFolder;
  final List<MaterialFolderEntity> breadcrumbs;
  final String searchQuery;
  final String? mimeTypeFilter;
  final bool isUploading;
  final double uploadProgress;
  final String? uploadingFileName;
  final int uploadTotalFiles;
  final int uploadCurrentIndex;
  final String? lastUploadError;
  final String? errorMessage;
  final bool hasMoreMaterials;
  final int page;

  const MaterialsLibraryState({
    this.status = MaterialsLibraryStatus.initial,
    this.folders = const [],
    this.materials = const [],
    this.currentFolder,
    this.breadcrumbs = const [],
    this.searchQuery = '',
    this.mimeTypeFilter,
    this.isUploading = false,
    this.uploadProgress = 0.0,
    this.uploadingFileName,
    this.uploadTotalFiles = 0,
    this.uploadCurrentIndex = 0,
    this.lastUploadError,
    this.errorMessage,
    this.hasMoreMaterials = false,
    this.page = 0,
  });

  bool get isLoading => status == MaterialsLibraryStatus.loading;
  bool get isLoaded => status == MaterialsLibraryStatus.loaded;
  bool get hasError => status == MaterialsLibraryStatus.error;
  bool get isEmpty =>
      isLoaded &&
      folders.isEmpty &&
      materials.isEmpty &&
      searchQuery.trim().isEmpty;

  MaterialsLibraryState copyWith({
    MaterialsLibraryStatus? status,
    List<MaterialFolderEntity>? folders,
    List<LibraryMaterialEntity>? materials,
    MaterialFolderEntity? Function()? currentFolder,
    List<MaterialFolderEntity>? breadcrumbs,
    String? searchQuery,
    String? Function()? mimeTypeFilter,
    bool? isUploading,
    double? uploadProgress,
    String? Function()? uploadingFileName,
    int? uploadTotalFiles,
    int? uploadCurrentIndex,
    String? Function()? lastUploadError,
    String? Function()? errorMessage,
    bool? hasMoreMaterials,
    int? page,
  }) {
    return MaterialsLibraryState(
      status: status ?? this.status,
      folders: folders ?? this.folders,
      materials: materials ?? this.materials,
      currentFolder:
          currentFolder != null ? currentFolder() : this.currentFolder,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      searchQuery: searchQuery ?? this.searchQuery,
      mimeTypeFilter:
          mimeTypeFilter != null ? mimeTypeFilter() : this.mimeTypeFilter,
      isUploading: isUploading ?? this.isUploading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      uploadingFileName: uploadingFileName != null
          ? uploadingFileName()
          : this.uploadingFileName,
      uploadTotalFiles: uploadTotalFiles ?? this.uploadTotalFiles,
      uploadCurrentIndex: uploadCurrentIndex ?? this.uploadCurrentIndex,
      lastUploadError:
          lastUploadError != null ? lastUploadError() : this.lastUploadError,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
      hasMoreMaterials: hasMoreMaterials ?? this.hasMoreMaterials,
      page: page ?? this.page,
    );
  }

  @override
  List<Object?> get props => [
        status,
        folders,
        materials,
        currentFolder,
        breadcrumbs,
        searchQuery,
        mimeTypeFilter,
        isUploading,
        uploadProgress,
        uploadingFileName,
        uploadTotalFiles,
        uploadCurrentIndex,
        lastUploadError,
        errorMessage,
        hasMoreMaterials,
        page,
      ];
}
