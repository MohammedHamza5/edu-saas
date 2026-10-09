import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/browser_tab_guard.dart';
import '../../domain/entities/library_video_entity.dart';
import '../../domain/entities/video_folder_entity.dart';
import '../../domain/repositories/video_bank_repository.dart';
import 'video_bank_state.dart';

class VideoBankCubit extends Cubit<VideoBankState> {
  final VideoBankRepository _repository;
  Timer? _pollingTimer;

  // In-memory cache for ultra-fast, zero-latency folder navigation
  final Map<String?, ({List<VideoFolderEntity> folders, List<LibraryVideoEntity> videos})>
      _cache = {};
  List<VideoFolderEntity> _cachedAllFolders = [];

  VideoBankCubit({required VideoBankRepository repository})
      : _repository = repository,
        super(const VideoBankInitial());

  @override
  Future<void> close() {
    _pollingTimer?.cancel();
    disableTabCloseWarning();
    return super.close();
  }

  VideoBankLoaded? get currentLoadedState {
    if (state is VideoBankLoaded) return state as VideoBankLoaded;
    if (state is VideoBankError) return (state as VideoBankError).lastLoaded;
    return null;
  }

  /// Initial load or navigate to specific folder
  Future<void> loadFolder({
    String? folderId,
    List<VideoFolderEntity>? breadcrumbs,
    bool forceRefresh = false,
  }) async {
    final prev = currentLoadedState;

    // Only show full-screen skeleton on the very first cold load
    if (prev == null) {
      emit(const VideoBankLoading());
    } else {
      emit(prev.copyWith(isActionLoading: true));
    }

    // Resolve current folder entity if folderId is provided
    VideoFolderEntity? activeFolder;
    List<VideoFolderEntity> newBreadcrumbs = breadcrumbs ?? prev?.breadcrumbs ?? [];

    if (folderId != null) {
      if (newBreadcrumbs.isNotEmpty && newBreadcrumbs.last.id == folderId) {
        activeFolder = newBreadcrumbs.last;
      } else {
        activeFolder = _cachedAllFolders.where((f) => f.id == folderId).firstOrNull;
        if (activeFolder == null) {
          final allFoldersRes = await _repository.getAllFolders();
          if (allFoldersRes.isSuccess) {
            _cachedAllFolders = allFoldersRes.data;
            activeFolder = _cachedAllFolders.where((f) => f.id == folderId).firstOrNull;
            newBreadcrumbs = _rebuildBreadcrumbs(folderId, _cachedAllFolders);
          }
        } else {
          newBreadcrumbs = _rebuildBreadcrumbs(folderId, _cachedAllFolders);
        }
      }
    } else {
      newBreadcrumbs = [];
    }

    // Run folders and videos queries concurrently in parallel!
    final results = await Future.wait([
      _repository.getFolders(parentId: folderId),
      _repository.getVideos(folderId: folderId),
    ]);

    final foldersRes = results[0] as Result<List<VideoFolderEntity>>;
    final videosRes = results[1] as Result<List<LibraryVideoEntity>>;

    if (foldersRes.isFailure) {
      emit(
        VideoBankError(
          foldersRes.failureOrNull?.message ?? 'Failed to load folders',
          code: foldersRes.failureOrNull?.code,
          lastLoaded: prev?.copyWith(isActionLoading: false),
        ),
      );
      return;
    }

    if (videosRes.isFailure) {
      emit(
        VideoBankError(
          videosRes.failureOrNull?.message ?? 'Failed to load videos',
          code: videosRes.failureOrNull?.code,
          lastLoaded: prev?.copyWith(isActionLoading: false),
        ),
      );
      return;
    }

    final loadedFolders = foldersRes.data;
    final loadedVideos = videosRes.data;

    // Update in-memory cache
    _cache[folderId] = (folders: loadedFolders, videos: loadedVideos);

    emit(
      VideoBankLoaded(
        currentFolder: activeFolder,
        breadcrumbs: newBreadcrumbs,
        folders: loadedFolders,
        videos: loadedVideos,
        isActionLoading: false,
      ),
    );

    // If any video is processing, trigger polling
    final hasProcessing = loadedVideos.any((v) => v.isProcessing);
    if (hasProcessing) {
      _startStatusPolling();
    }
  }

  /// Silently refresh folder contents in the background without clearing the UI
  Future<void> _silentRefresh(
    String? folderId,
    List<VideoFolderEntity> breadcrumbs,
  ) async {
    try {
      final results = await Future.wait([
        _repository.getFolders(parentId: folderId),
        _repository.getVideos(folderId: folderId),
      ]);
      final fRes = results[0] as Result<List<VideoFolderEntity>>;
      final vRes = results[1] as Result<List<LibraryVideoEntity>>;

      if (fRes.isSuccess && vRes.isSuccess && !isClosed) {
        final fList = fRes.data;
        final vList = vRes.data;
        _cache[folderId] = (folders: fList, videos: vList);

        final cur = currentLoadedState;
        if (cur != null && cur.currentFolder?.id == folderId) {
          emit(
            cur.copyWith(
              folders: fList,
              videos: vList,
              isActionLoading: false,
            ),
          );
        }
        if (vList.any((v) => v.isProcessing)) {
          _startStatusPolling();
        }
      }
    } catch (_) {
      // Background silent refresh ignores errors
    }
  }

  List<VideoFolderEntity> _rebuildBreadcrumbs(
    String targetId,
    List<VideoFolderEntity> all,
  ) {
    final trail = <VideoFolderEntity>[];
    String? currId = targetId;

    while (currId != null) {
      final f = all.where((element) => element.id == currId).firstOrNull;
      if (f == null) break;
      trail.insert(0, f);
      currId = f.parentId;
    }
    return trail;
  }

  /// Enter a subfolder with instantaneous cached transition
  Future<void> openFolder(VideoFolderEntity folder) async {
    final prev = currentLoadedState;
    final currentTrail = List<VideoFolderEntity>.from(prev?.breadcrumbs ?? []);
    if (!currentTrail.any((f) => f.id == folder.id)) {
      currentTrail.add(folder);
    }

    // 1. Instant transition if cached
    if (_cache.containsKey(folder.id) && prev != null) {
      final cached = _cache[folder.id]!;
      emit(
        prev.copyWith(
          currentFolder: () => folder,
          breadcrumbs: currentTrail,
          folders: cached.folders,
          videos: cached.videos,
          searchQuery: '',
          isActionLoading: false,
        ),
      );
      if (cached.videos.any((v) => v.isProcessing)) {
        _startStatusPolling();
      }
      // Silently refresh in background
      unawaited(_silentRefresh(folder.id, currentTrail));
      return;
    }

    // 2. If not cached, transition immediately with loading indicator
    if (prev != null) {
      emit(
        prev.copyWith(
          currentFolder: () => folder,
          breadcrumbs: currentTrail,
          folders: const [],
          videos: const [],
          searchQuery: '',
          isActionLoading: true,
        ),
      );
    }

    await loadFolder(folderId: folder.id, breadcrumbs: currentTrail);
  }

  /// Go up one folder level with instantaneous cached transition
  Future<void> navigateUp() async {
    final prev = currentLoadedState;
    if (prev == null || prev.breadcrumbs.isEmpty) return;

    final updatedTrail = List<VideoFolderEntity>.from(prev.breadcrumbs);
    updatedTrail.removeLast();

    final parentFolder = updatedTrail.isNotEmpty ? updatedTrail.last : null;
    final parentFolderId = parentFolder?.id;

    // 1. Instant transition if cached
    if (_cache.containsKey(parentFolderId)) {
      final cached = _cache[parentFolderId]!;
      emit(
        prev.copyWith(
          currentFolder: () => parentFolder,
          breadcrumbs: updatedTrail,
          folders: cached.folders,
          videos: cached.videos,
          isActionLoading: false,
        ),
      );
      unawaited(_silentRefresh(parentFolderId, updatedTrail));
      return;
    }

    // 2. Transition immediately with indicator
    emit(
      prev.copyWith(
        currentFolder: () => parentFolder,
        breadcrumbs: updatedTrail,
        folders: const [],
        videos: const [],
        isActionLoading: true,
      ),
    );

    await loadFolder(folderId: parentFolderId, breadcrumbs: updatedTrail);
  }

  /// Jump to a breadcrumb level
  Future<void> navigateToBreadcrumb(int index) async {
    final prev = currentLoadedState;
    if (prev == null) return;

    if (index < 0) {
      // Root level
      if (_cache.containsKey(null)) {
        final cached = _cache[null]!;
        emit(
          prev.copyWith(
            currentFolder: () => null,
            breadcrumbs: const [],
            folders: cached.folders,
            videos: cached.videos,
            isActionLoading: false,
          ),
        );
        unawaited(_silentRefresh(null, const []));
        return;
      }
      await loadFolder(folderId: null, breadcrumbs: const []);
      return;
    }

    if (index < prev.breadcrumbs.length) {
      final updatedTrail = prev.breadcrumbs.sublist(0, index + 1);
      final target = updatedTrail.last;

      if (_cache.containsKey(target.id)) {
        final cached = _cache[target.id]!;
        emit(
          prev.copyWith(
            currentFolder: () => target,
            breadcrumbs: updatedTrail,
            folders: cached.folders,
            videos: cached.videos,
            isActionLoading: false,
          ),
        );
        unawaited(_silentRefresh(target.id, updatedTrail));
        return;
      }

      await loadFolder(folderId: target.id, breadcrumbs: updatedTrail);
    }
  }

  /// Search across all videos
  Future<void> search(String query) async {
    final prev = currentLoadedState;
    if (prev == null) return;

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      // Restore current folder contents from cache
      if (_cache.containsKey(prev.currentFolder?.id)) {
        final cached = _cache[prev.currentFolder?.id]!;
        emit(
          prev.copyWith(
            searchQuery: '',
            videos: cached.videos,
            folders: cached.folders,
            isActionLoading: false,
          ),
        );
      } else {
        await loadFolder(
          folderId: prev.currentFolder?.id,
          breadcrumbs: prev.breadcrumbs,
        );
      }
      return;
    }

    emit(prev.copyWith(searchQuery: trimmed, isActionLoading: true));

    // Ensure all folders are cached for folder search
    if (_cachedAllFolders.isEmpty) {
      final allFoldersRes = await _repository.getAllFolders();
      if (allFoldersRes.isSuccess) {
        _cachedAllFolders = allFoldersRes.data;
      }
    }

    final queryLower = trimmed.toLowerCase();
    final matchingFolders = _cachedAllFolders
        .where((f) => f.name.toLowerCase().contains(queryLower))
        .toList();

    final searchRes = await _repository.getVideos(search: trimmed);
    if (searchRes.isSuccess) {
      emit(
        prev.copyWith(
          searchQuery: trimmed,
          videos: searchRes.data,
          folders: matchingFolders,
          isActionLoading: false,
        ),
      );
    } else {
      emit(
        prev.copyWith(
          searchQuery: trimmed,
          folders: matchingFolders,
          isActionLoading: false,
        ),
      );
    }
  }

  /// Create folder with optimistic instant UI update (zero screen reload)
  Future<bool> createFolder(String name, {String? color}) async {
    final prev = currentLoadedState;
    if (prev == null) return false;

    emit(prev.copyWith(isActionLoading: true));
    final result = await _repository.createFolder(
      name: name,
      parentId: prev.currentFolder?.id,
      color: color,
    );

    if (result.isSuccess) {
      final newFolder = result.data;
      final updatedFolders = [newFolder, ...prev.folders]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      _cachedAllFolders.add(newFolder);
      _cache[prev.currentFolder?.id] = (
        folders: updatedFolders,
        videos: prev.videos,
      );

      emit(
        prev.copyWith(
          folders: updatedFolders,
          isActionLoading: false,
        ),
      );

      // Silently refresh in background
      unawaited(_silentRefresh(prev.currentFolder?.id, prev.breadcrumbs));
      return true;
    } else {
      emit(
        VideoBankError(
          result.failureOrNull?.message ?? 'Failed to create folder',
          code: result.failureOrNull?.code,
          lastLoaded: prev.copyWith(isActionLoading: false),
        ),
      );
      return false;
    }
  }

  /// Rename folder with optimistic UI update
  Future<bool> renameFolder(String folderId, String newName) async {
    final prev = currentLoadedState;
    if (prev == null) return false;

    // Optimistically update
    final updatedFolders = prev.folders.map((f) {
      if (f.id == folderId) {
        return f.copyWith(
          name: newName.trim(),
          updatedAt: DateTime.now(),
        );
      }
      return f;
    }).toList();

    _cache[prev.currentFolder?.id] = (
      folders: updatedFolders,
      videos: prev.videos,
    );

    emit(prev.copyWith(folders: updatedFolders, isActionLoading: true));
    final result = await _repository.updateFolder(id: folderId, name: newName);

    if (result.isSuccess) {
      emit(prev.copyWith(folders: updatedFolders, isActionLoading: false));
      unawaited(_silentRefresh(prev.currentFolder?.id, prev.breadcrumbs));
      return true;
    } else {
      emit(
        VideoBankError(
          result.failureOrNull?.message ?? 'Failed to rename folder',
          code: result.failureOrNull?.code,
          lastLoaded: prev.copyWith(isActionLoading: false),
        ),
      );
      return false;
    }
  }

  /// Update folder color with optimistic UI update
  Future<bool> updateFolderColor(String folderId, String? color) async {
    final prev = currentLoadedState;
    if (prev == null) return false;

    final updatedFolders = prev.folders.map((f) {
      if (f.id == folderId) {
        return f.copyWith(color: color);
      }
      return f;
    }).toList();

    _cache[prev.currentFolder?.id] = (
      folders: updatedFolders,
      videos: prev.videos,
    );

    emit(prev.copyWith(folders: updatedFolders, isActionLoading: true));
    final result =
        await _repository.updateFolderColor(id: folderId, color: color);

    if (result.isSuccess) {
      emit(prev.copyWith(folders: updatedFolders, isActionLoading: false));
      unawaited(_silentRefresh(prev.currentFolder?.id, prev.breadcrumbs));
      return true;
    } else {
      emit(
        VideoBankError(
          result.failureOrNull?.message ?? 'Failed to update folder color',
          code: result.failureOrNull?.code,
          lastLoaded: prev.copyWith(isActionLoading: false),
        ),
      );
      return false;
    }
  }

  /// Delete folder with optimistic UI update
  Future<bool> deleteFolder(String folderId) async {
    final prev = currentLoadedState;
    if (prev == null) return false;

    final updatedFolders = prev.folders.where((f) => f.id != folderId).toList();
    _cache[prev.currentFolder?.id] = (
      folders: updatedFolders,
      videos: prev.videos,
    );
    _cache.remove(folderId);

    emit(prev.copyWith(folders: updatedFolders, isActionLoading: true));
    final result = await _repository.deleteFolder(folderId);

    if (result.isSuccess) {
      emit(prev.copyWith(folders: updatedFolders, isActionLoading: false));
      unawaited(_silentRefresh(prev.currentFolder?.id, prev.breadcrumbs));
      return true;
    } else {
      emit(
        VideoBankError(
          result.failureOrNull?.message ?? 'Failed to delete folder',
          code: result.failureOrNull?.code,
          lastLoaded: prev.copyWith(isActionLoading: false),
        ),
      );
      return false;
    }
  }

  /// Upload video to current folder
  Future<bool> uploadVideo({
    required String title,
    String? description,
    required List<int> videoBytes,
  }) async {
    final prev = currentLoadedState;
    if (prev == null) return false;

    emit(
      prev.copyWith(
        uploadProgress: () => 0.01,
        uploadingTitle: () => title,
      ),
    );

    enableTabCloseWarning(
      'يوجد فيديو قيد الرفع حالياً. إغلاق المنصة أو تحديثها سيؤدي إلى إلغاء عملية الرفع.',
    );

    final result = await _repository.uploadVideo(
      title: title,
      description: description,
      folderId: prev.currentFolder?.id,
      videoBytes: videoBytes,
      onProgress: (sent, total) {
        if (total > 0) {
          final p = sent / total;
          final current = currentLoadedState;
          if (current != null) {
            emit(
              current.copyWith(
                uploadProgress: () => p.clamp(0.0, 0.99),
                uploadingTitle: () => title,
              ),
            );
          }
        }
      },
    );

    disableTabCloseWarning();

    if (result.isSuccess) {
      final current = currentLoadedState ?? prev;
      emit(
        current.copyWith(
          uploadProgress: () => null,
          uploadingTitle: () => null,
        ),
      );

      // Invalidate cache and reload silently
      _cache.remove(prev.currentFolder?.id);
      await loadFolder(
        folderId: prev.currentFolder?.id,
        breadcrumbs: prev.breadcrumbs,
      );

      _startStatusPolling();
      return true;
    } else {
      final current = currentLoadedState ?? prev;
      final code = result.failureOrNull?.code;
      if (code == 'UPLOAD_CANCELLED') {
        emit(
          current.copyWith(
            uploadProgress: () => null,
            uploadingTitle: () => null,
          ),
        );
        return false;
      }

      emit(
        VideoBankError(
          result.failureOrNull?.message ?? 'Failed to upload video',
          code: code,
          lastLoaded: current.copyWith(
            uploadProgress: () => null,
            uploadingTitle: () => null,
          ),
        ),
      );
      return false;
    }
  }

  /// Cancels any currently active binary video upload stream
  void cancelUpload() {
    _repository.cancelActiveUpload();
    disableTabCloseWarning();
    final current = currentLoadedState;
    if (current != null) {
      emit(
        current.copyWith(
          uploadProgress: () => null,
          uploadingTitle: () => null,
        ),
      );
    }
  }

  /// Delete video with optimistic UI update
  Future<bool> deleteVideo(String videoId) async {
    final prev = currentLoadedState;
    if (prev == null) return false;

    final updatedVideos = prev.videos.where((v) => v.id != videoId).toList();
    _cache[prev.currentFolder?.id] = (
      folders: prev.folders,
      videos: updatedVideos,
    );

    emit(prev.copyWith(videos: updatedVideos, isActionLoading: true));
    final result = await _repository.deleteVideo(videoId);

    if (result.isSuccess) {
      emit(prev.copyWith(videos: updatedVideos, isActionLoading: false));
      unawaited(_silentRefresh(prev.currentFolder?.id, prev.breadcrumbs));
      return true;
    } else {
      emit(
        VideoBankError(
          result.failureOrNull?.message ?? 'Failed to delete video',
          code: result.failureOrNull?.code,
          lastLoaded: prev.copyWith(isActionLoading: false),
        ),
      );
      return false;
    }
  }

  /// Move video with optimistic UI update
  Future<bool> moveVideo({
    required String videoId,
    String? targetFolderId,
  }) async {
    final prev = currentLoadedState;
    if (prev == null) return false;

    final updatedVideos = prev.videos.where((v) => v.id != videoId).toList();
    _cache[prev.currentFolder?.id] = (
      folders: prev.folders,
      videos: updatedVideos,
    );
    // Invalidate target folder's cache so it reflects the moved video
    _cache.remove(targetFolderId);

    emit(prev.copyWith(videos: updatedVideos, isActionLoading: true));
    final result = await _repository.moveVideo(
      id: videoId,
      targetFolderId: targetFolderId,
    );

    if (result.isSuccess) {
      emit(prev.copyWith(videos: updatedVideos, isActionLoading: false));
      unawaited(_silentRefresh(prev.currentFolder?.id, prev.breadcrumbs));
      return true;
    } else {
      emit(
        VideoBankError(
          result.failureOrNull?.message ?? 'Failed to move video',
          code: result.failureOrNull?.code,
          lastLoaded: prev.copyWith(isActionLoading: false),
        ),
      );
      return false;
    }
  }

  /// Rename video with optimistic UI update
  Future<bool> renameVideo({
    required String videoId,
    required String newTitle,
    String? newDescription,
  }) async {
    final prev = currentLoadedState;
    if (prev == null) return false;

    final updatedVideos = prev.videos.map((v) {
      if (v.id == videoId) {
        return LibraryVideoEntity(
          id: v.id,
          tenantId: v.tenantId,
          folderId: v.folderId,
          title: newTitle.trim(),
          description: newDescription ?? v.description,
          provider: v.provider,
          providerVideoId: v.providerVideoId,
          thumbnailUrl: v.thumbnailUrl,
          duration: v.duration,
          status: v.status,
          playbackUrl: v.playbackUrl,
          createdAt: v.createdAt,
          updatedAt: DateTime.now(),
          assignedLecturesCount: v.assignedLecturesCount,
          assignedGroupNames: v.assignedGroupNames,
        );
      }
      return v;
    }).toList();

    _cache[prev.currentFolder?.id] = (
      folders: prev.folders,
      videos: updatedVideos,
    );

    emit(prev.copyWith(videos: updatedVideos, isActionLoading: true));
    final result = await _repository.updateVideo(
      id: videoId,
      title: newTitle,
      description: newDescription,
    );

    if (result.isSuccess) {
      emit(prev.copyWith(videos: updatedVideos, isActionLoading: false));
      unawaited(_silentRefresh(prev.currentFolder?.id, prev.breadcrumbs));
      return true;
    } else {
      emit(
        VideoBankError(
          result.failureOrNull?.message ?? 'Failed to update video',
          code: result.failureOrNull?.code,
          lastLoaded: prev.copyWith(isActionLoading: false),
        ),
      );
      return false;
    }
  }

  /// Get temporary signed tokenized playback URL
  Future<String?> getPlaybackUrl(String libraryVideoId) async {
    final result = await _repository.getPlaybackUrl(libraryVideoId);
    return result.dataOrNull;
  }

  /// Manually sync video encoding status with Bunny and refresh UI
  Future<bool> syncVideo(String libraryVideoId) async {
    final result = await _repository.syncVideoStatus(libraryVideoId);
    if (result.isSuccess) {
      final updated = result.data;
      final prev = currentLoadedState;
      if (prev != null) {
        final newVideos = prev.videos.map((v) => v.id == updated.id ? updated : v).toList();
        _cache[prev.currentFolder?.id] = (folders: prev.folders, videos: newVideos);
        emit(prev.copyWith(videos: newVideos));
      }
      return true;
    }
    return false;
  }

  void _startStatusPolling() {
    _pollingTimer?.cancel();
    int polls = 0;

    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      polls++;
      final prev = currentLoadedState;
      if (prev == null || isClosed) {
        timer.cancel();
        return;
      }

      final processingVideos = prev.videos.where((v) => v.isProcessing).toList();
      if (processingVideos.isEmpty || polls > 60) {
        timer.cancel();
        return;
      }

      for (final v in processingVideos) {
        await _repository.syncVideoStatus(v.id);
      }

      // Refresh list silently
      final refreshedVideosRes = await _repository.getVideos(
        folderId: prev.currentFolder?.id,
        search: prev.searchQuery.isNotEmpty ? prev.searchQuery : null,
      );

      if (refreshedVideosRes.isSuccess && !isClosed) {
        final current = currentLoadedState;
        if (current != null) {
          emit(current.copyWith(videos: refreshedVideosRes.data));
        }
      }
    });
  }

  /// Assign an entire folder to a course as a chapter with all ready videos
  Future<Result<Map<String, dynamic>>> assignFolderAsChapter({
    required String folderId,
    required String groupId,
    String? chapterTitle,
  }) async {
    final prev = currentLoadedState;
    if (prev != null) {
      emit(prev.copyWith(isActionLoading: true));
    }
    final result = await _repository.assignFolderAsChapter(
      folderId: folderId,
      groupId: groupId,
      chapterTitle: chapterTitle,
    );
    if (prev != null && !isClosed) {
      emit(prev.copyWith(isActionLoading: false));
    }
    return result;
  }
}
