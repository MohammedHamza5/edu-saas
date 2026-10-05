import 'package:equatable/equatable.dart';
import '../../domain/entities/library_video_entity.dart';
import '../../domain/entities/video_folder_entity.dart';

sealed class VideoBankState extends Equatable {
  const VideoBankState();

  @override
  List<Object?> get props => [];
}

class VideoBankInitial extends VideoBankState {
  const VideoBankInitial();
}

class VideoBankLoading extends VideoBankState {
  const VideoBankLoading();
}

class VideoBankLoaded extends VideoBankState {
  final VideoFolderEntity? currentFolder;
  final List<VideoFolderEntity> breadcrumbs;
  final List<VideoFolderEntity> folders;
  final List<LibraryVideoEntity> videos;
  final String searchQuery;
  final double? uploadProgress;
  final String? uploadingTitle;
  final bool isActionLoading;

  const VideoBankLoaded({
    this.currentFolder,
    this.breadcrumbs = const [],
    this.folders = const [],
    this.videos = const [],
    this.searchQuery = '',
    this.uploadProgress,
    this.uploadingTitle,
    this.isActionLoading = false,
  });

  bool get isUploading => uploadProgress != null;

  int get totalItems => folders.length + videos.length;

  VideoBankLoaded copyWith({
    VideoFolderEntity? Function()? currentFolder,
    List<VideoFolderEntity>? breadcrumbs,
    List<VideoFolderEntity>? folders,
    List<LibraryVideoEntity>? videos,
    String? searchQuery,
    double? Function()? uploadProgress,
    String? Function()? uploadingTitle,
    bool? isActionLoading,
  }) {
    return VideoBankLoaded(
      currentFolder:
          currentFolder != null ? currentFolder() : this.currentFolder,
      breadcrumbs: breadcrumbs ?? this.breadcrumbs,
      folders: folders ?? this.folders,
      videos: videos ?? this.videos,
      searchQuery: searchQuery ?? this.searchQuery,
      uploadProgress:
          uploadProgress != null ? uploadProgress() : this.uploadProgress,
      uploadingTitle:
          uploadingTitle != null ? uploadingTitle() : this.uploadingTitle,
      isActionLoading: isActionLoading ?? this.isActionLoading,
    );
  }

  @override
  List<Object?> get props => [
    currentFolder,
    breadcrumbs,
    folders,
    videos,
    searchQuery,
    uploadProgress,
    uploadingTitle,
    isActionLoading,
  ];
}

class VideoBankError extends VideoBankState {
  final String message;
  final String? code;
  final VideoBankLoaded? lastLoaded;

  const VideoBankError(this.message, {this.code, this.lastLoaded});

  @override
  List<Object?> get props => [message, code, lastLoaded];
}
