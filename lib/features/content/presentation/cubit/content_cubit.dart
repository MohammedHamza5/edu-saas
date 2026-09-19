import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/repositories/content_repository.dart';
import 'content_state.dart';

class ContentCubit extends Cubit<ContentState> {
  final ContentRepository _repository;
  String? _currentGroupId;
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _isStudent = false;

  ContentCubit({
    required ContentRepository repository,
  })  : _repository = repository,
        super(const ContentInitial());

  String? get currentGroupId => _currentGroupId;

  /// Loads content for a group with instant SWR caching.
  /// If [isStudent] is true, only published content is retrieved.
  Future<void> loadGroupContent(
    String groupId, {
    ContentStatus? statusFilter,
    bool isStudent = false,
    bool forceRefresh = false,
  }) async {
    _currentGroupId = groupId;
    _currentPage = 0;
    _isStudent = isStudent;
    final cacheKey = '${groupId}_${statusFilter?.name ?? 'all'}_$isStudent';

    if (forceRefresh) {
      AppCache.content.invalidatePrefix(groupId);
    } else {
      // ── Stale-While-Revalidate: Instant display from memory cache ──────────
      final cached = AppCache.content.getStale(cacheKey);
      if (cached is List<ContentEntity>) {
        emit(ContentLoaded(
          items: cached,
          activeFilter: statusFilter,
          hasMore: cached.length >= _pageSize,
        ));
        if (AppCache.content.has(cacheKey)) return; // Fresh cache, skip network
      } else {
        emit(const ContentLoading());
      }
    }

    final filter = isStudent ? ContentStatus.published : statusFilter;
    final result = await _repository.getGroupContent(
      groupId: groupId,
      statusFilter: filter,
      page: 0,
      pageSize: _pageSize,
    );

    switch (result) {
      case Success(:final data):
        AppCache.content.put(cacheKey, data);
        emit(ContentLoaded(
          items: data,
          activeFilter: statusFilter,
          hasMore: data.length == _pageSize,
          isLoadingMore: false,
        ));
      case FailureResult(:final failure):
        if (state is! ContentLoaded) {
          emit(ContentError(failure.message));
        }
    }
  }

  /// Loads next page of content items on scroll (Infinite Scroll)
  Future<void> loadMoreContent() async {
    final currentState = state;
    if (currentState is! ContentLoaded) return;
    if (!currentState.hasMore || currentState.isLoadingMore || _currentGroupId == null) return;

    emit(currentState.copyWith(isLoadingMore: true));
    final nextPage = _currentPage + 1;
    final filter = _isStudent ? ContentStatus.published : currentState.activeFilter;

    final result = await _repository.getGroupContent(
      groupId: _currentGroupId!,
      statusFilter: filter,
      page: nextPage,
      pageSize: _pageSize,
    );

    if (isClosed) return;

    switch (result) {
      case Success(:final data):
        _currentPage = nextPage;
        final allItems = [...currentState.items, ...data];
        final cacheKey = '${_currentGroupId}_${currentState.activeFilter?.name ?? 'all'}_$_isStudent';
        AppCache.content.put(cacheKey, allItems);
        emit(currentState.copyWith(
          items: allItems,
          hasMore: data.length == _pageSize,
          isLoadingMore: false,
        ));
      case FailureResult():
        emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  /// Sets status filter without re-fetching if items are already loaded
  void setFilter(ContentStatus? filter) {
    if (state is ContentLoaded) {
      final current = state as ContentLoaded;
      emit(current.copyWith(activeFilter: filter, clearFilter: filter == null));
    }
  }

  /// Creates a new content item (groupId optional for Bank)
  Future<bool> createContent({
    String? groupId,
    required String title,
    String? description,
    required ContentType type,
    required ContentStatus status,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  }) async {
    final result = await _repository.createContent(
      groupId: groupId,
      title: title,
      description: description,
      type: type,
      status: status,
      fileName: fileName,
      storagePath: storagePath,
      mimeType: mimeType,
      fileSize: fileSize,
      fileBytes: fileBytes,
      associatedExamId: associatedExamId,
      prerequisiteExamId: prerequisiteExamId,
    );

    switch (result) {
      case Success():
        if (groupId != null) {
          AppCache.content.invalidatePrefix(groupId);
          await loadGroupContent(groupId, forceRefresh: true);
        } else {
          await loadCentralVideoBank(forceRefresh: true);
        }
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Updates existing content
  Future<bool> updateContent({
    required String contentId,
    String? title,
    String? description,
    ContentType? type,
    ContentStatus? status,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  }) async {
    final result = await _repository.updateContent(
      contentId: contentId,
      title: title,
      description: description,
      type: type,
      status: status,
      fileName: fileName,
      storagePath: storagePath,
      mimeType: mimeType,
      fileSize: fileSize,
      fileBytes: fileBytes,
      associatedExamId: associatedExamId,
      prerequisiteExamId: prerequisiteExamId,
    );

    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          AppCache.content.invalidatePrefix(_currentGroupId!);
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        } else {
          await loadCentralVideoBank(forceRefresh: true);
        }
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Loads the Central Video Bank
  Future<void> loadCentralVideoBank({bool forceRefresh = false}) async {
    _currentGroupId = null;
    emit(const ContentLoading());
    final result = await _repository.getCentralVideoBank();
    switch (result) {
      case Success(:final data):
        emit(ContentLoaded(
          items: data,
          hasMore: false,
        ));
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
    }
  }

  /// Assigns content to one or more groups
  Future<bool> assignContentToGroups({
    required String contentId,
    required List<String> groupIds,
  }) async {
    final result = await _repository.assignContentToGroups(
      contentId: contentId,
      groupIds: groupIds,
    );
    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        } else {
          await loadCentralVideoBank(forceRefresh: true);
        }
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Links a quiz/exam to a lesson
  Future<bool> linkLessonExam({
    required String contentId,
    required String examId,
  }) async {
    final result = await _repository.linkLessonExam(
      contentId: contentId,
      examId: examId,
    );
    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        } else {
          await loadCentralVideoBank(forceRefresh: true);
        }
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Changes status: e.g. publish draft or archive
  Future<void> updateStatus({
    required String contentId,
    required ContentStatus status,
  }) async {
    final result = await _repository.updateContentStatus(
      contentId: contentId,
      status: status,
    );

    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          AppCache.content.invalidatePrefix(_currentGroupId!);
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        }
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
    }
  }

  /// Reorders items after a drag-and-drop in ReorderableListView
  Future<void> reorderItems(int oldIndex, int newIndex) async {
    if (state is! ContentLoaded) return;
    final current = state as ContentLoaded;

    final list = List<ContentEntity>.from(current.items);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Optimistically update UI order immediately
    emit(current.copyWith(items: list, isReordering: true));

    final ids = list.map((e) => e.id).toList();
    final result = await _repository.reorderContentItems(contentIdsInOrder: ids);

    switch (result) {
      case Success():
        emit(current.copyWith(items: list, isReordering: false));
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        if (_currentGroupId != null) {
          AppCache.content.invalidatePrefix(_currentGroupId!);
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        }
    }
  }

  /// Deletes a content item
  Future<void> deleteContent(String contentId) async {
    final result = await _repository.deleteContent(contentId);
    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          AppCache.content.invalidatePrefix(_currentGroupId!);
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        }
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
    }
  }

  /// Fetches a signed URL for opening an attached file
  Future<String?> getSignedUrl(String storagePath) async {
    final result = await _repository.getSignedFileUrl(storagePath: storagePath);
    switch (result) {
      case Success(:final data):
        return data;
      case FailureResult():
        return null;
    }
  }
}
