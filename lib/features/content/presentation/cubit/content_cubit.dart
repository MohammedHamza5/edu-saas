import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/repositories/content_repository.dart';
import 'content_state.dart';

class ContentCubit extends Cubit<ContentState> {
  final ContentRepository _repository;
  String? _currentGroupId;
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _isStudent = false;

  ContentCubit({required ContentRepository repository})
    : _repository = repository,
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
    final chaptersKey = '${groupId}_chapters';

    if (forceRefresh) {
      AppCache.content.invalidatePrefix(groupId);
    } else {
      // ── Stale-While-Revalidate: Instant display from memory cache ──────────
      final cached = AppCache.content.getStale(cacheKey);
      final cachedChapters =
          AppCache.content.getStale(chaptersKey) as List<ChapterEntity>?;
      if (cached is List<ContentEntity>) {
        emit(
          ContentLoaded(
            items: cached,
            chapters: cachedChapters ?? const [],
            activeFilter: statusFilter,
            hasMore: cached.length >= _pageSize,
          ),
        );
        if (AppCache.content.has(cacheKey) &&
            cachedChapters != null &&
            AppCache.content.has(chaptersKey)) {
          return; // Fresh cache for both content and chapters, skip network
        }
      } else {
        emit(const ContentLoading());
      }
    }

    final filter = isStudent ? ContentStatus.published : statusFilter;
    final contentFuture = _repository.getGroupContent(
      groupId: groupId,
      statusFilter: filter,
      page: 0,
      pageSize: _pageSize,
    );
    final chaptersFuture = _repository.getGroupChapters(groupId);

    final results = await Future.wait([contentFuture, chaptersFuture]);
    final contentRes = results[0] as Result<List<ContentEntity>>;
    final chaptersRes = results[1] as Result<List<ChapterEntity>>;

    List<ChapterEntity> chapters = [];
    if (chaptersRes is Success<List<ChapterEntity>>) {
      chapters = chaptersRes.data;
      AppCache.content.put(chaptersKey, chapters);
    }

    switch (contentRes) {
      case Success(:final data):
        AppCache.content.put(cacheKey, data);
        emit(
          ContentLoaded(
            items: data,
            chapters: chapters,
            activeFilter: statusFilter,
            hasMore: data.length == _pageSize,
            isLoadingMore: false,
          ),
        );
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
    if (!currentState.hasMore ||
        currentState.isLoadingMore ||
        _currentGroupId == null) {
      return;
    }

    emit(currentState.copyWith(isLoadingMore: true));
    final nextPage = _currentPage + 1;
    final filter = _isStudent
        ? ContentStatus.published
        : currentState.activeFilter;

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
        final cacheKey =
            '${_currentGroupId}_${currentState.activeFilter?.name ?? 'all'}_$_isStudent';
        AppCache.content.put(cacheKey, allItems);
        emit(
          currentState.copyWith(
            items: allItems,
            hasMore: data.length == _pageSize,
            isLoadingMore: false,
          ),
        );
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
        emit(ContentLoaded(items: data, hasMore: false));
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
    }
  }

  /// Assigns content to one or more groups
  Future<bool> assignContentToGroups({
    required String contentId,
    required List<String> groupIds,
    List<Map<String, dynamic>>? groupConfigs,
  }) async {
    final result = await _repository.assignContentToGroups(
      contentId: contentId,
      groupIds: groupIds,
      groupConfigs: groupConfigs,
    );
    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        } else if (groupIds.isNotEmpty) {
          await loadGroupContent(groupIds.first, forceRefresh: true);
        } else {
          await loadCentralVideoBank(forceRefresh: true);
        }
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  Future<bool> assignBatchContentToGroup({
    required String groupId,
    required List<Map<String, dynamic>> items,
  }) async {
    final result = await _repository.assignBatchContentToGroup(
      groupId: groupId,
      items: items,
    );
    switch (result) {
      case Success():
        await loadGroupContent(groupId, forceRefresh: true);
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Uploads a file (R2 or fallback) and creates a record in the files table.
  /// Returns the newly created file_id.
  Future<String?> uploadAndCreateFileRecord({
    required String tenantId,
    required String contentId,
    required String fileName,
    required String mimeType,
    required List<int> fileBytes,
    required String storagePath,
  }) async {
    final result = await _repository.uploadAndCreateFileRecord(
      tenantId: tenantId,
      contentId: contentId,
      fileName: fileName,
      mimeType: mimeType,
      fileBytes: fileBytes,
      storagePath: storagePath,
    );
    switch (result) {
      case Success(:final data):
        return data;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return null;
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

  /// Reorders visible lessons and updates both memory state and server order
  Future<void> reorderLessonItems({
    required int oldIndex,
    required int newIndex,
    required List<ContentEntity> visibleLessons,
  }) async {
    if (state is! ContentLoaded) return;
    final current = state as ContentLoaded;

    final lessons = List<ContentEntity>.from(visibleLessons);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 ||
        oldIndex >= lessons.length ||
        newIndex < 0 ||
        newIndex >= lessons.length) {
      return;
    }

    final item = lessons.removeAt(oldIndex);
    lessons.insert(newIndex, item);

    // Build the new ordering map from the reordered visible lessons
    final orderedIds = lessons.map((e) => e.id).toList();
    final idToOrder = <String, int>{};
    for (int i = 0; i < orderedIds.length; i++) {
      idToOrder[orderedIds[i]] = i;
    }

    // Apply the new order to current.items and sort accordingly
    final updatedList = current.items.map((it) {
      if (idToOrder.containsKey(it.id)) {
        return it.copyWith(sortOrder: idToOrder[it.id]!);
      }
      return it;
    }).toList();

    updatedList.sort((a, b) {
      final s = a.sortOrder.compareTo(b.sortOrder);
      if (s != 0) return s;
      return a.createdAt.compareTo(b.createdAt);
    });

    // Optimistically update UI order immediately
    emit(current.copyWith(items: updatedList, isReordering: true));

    final result = await _repository.reorderContentItems(
      contentIdsInOrder: orderedIds,
      groupId: _currentGroupId,
    );

    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          AppCache.content.invalidatePrefix(_currentGroupId!);
        }
        emit(current.copyWith(items: updatedList, isReordering: false));
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        if (_currentGroupId != null) {
          AppCache.content.invalidatePrefix(_currentGroupId!);
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        }
    }
  }

  /// Reorders items after a drag-and-drop in ReorderableListView
  Future<void> reorderItems(int oldIndex, int newIndex) async {
    if (state is! ContentLoaded) return;
    final current = state as ContentLoaded;
    final videos =
        current.items.where((i) => i.type == ContentType.video).toList();
    if (videos.isNotEmpty &&
        oldIndex < videos.length &&
        newIndex <= videos.length) {
      await reorderLessonItems(
        oldIndex: oldIndex,
        newIndex: newIndex,
        visibleLessons: videos,
      );
      return;
    }

    final list = List<ContentEntity>.from(current.items);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex < 0 ||
        oldIndex >= list.length ||
        newIndex < 0 ||
        newIndex >= list.length) {
      return;
    }
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);

    // Optimistically update UI order immediately
    emit(current.copyWith(items: list, isReordering: true));

    final ids = list.map((e) => e.id).toList();
    final result = await _repository.reorderContentItems(
      contentIdsInOrder: ids,
      groupId: _currentGroupId,
    );

    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          AppCache.content.invalidatePrefix(_currentGroupId!);
        }
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

  /// Toggles visibility of a single lesson in the group
  Future<bool> toggleLessonVisibility({
    required String contentId,
    required bool isPublished,
    String? groupId,
  }) async {
    final targetGroupId = groupId ?? _currentGroupId;
    if (targetGroupId == null) return false;

    // Optimistic UI update if in ContentLoaded state
    final currentState = state;
    if (currentState is ContentLoaded) {
      final updatedList = currentState.items.map((item) {
        if (item.id == contentId) {
          return item.copyWith(isPublishedInGroup: isPublished);
        }
        return item;
      }).toList();
      emit(currentState.copyWith(items: updatedList));
    }

    final result = await _repository.toggleLessonVisibility(
      contentId: contentId,
      groupId: targetGroupId,
      isPublished: isPublished,
    );

    switch (result) {
      case Success():
        AppCache.content.invalidatePrefix(targetGroupId);
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        if (targetGroupId == _currentGroupId) {
          await loadGroupContent(targetGroupId, forceRefresh: true);
        }
        return false;
    }
  }

  /// Bulk toggles visibility of all lessons in the group
  Future<bool> toggleAllLessonsVisibility({
    required bool isPublished,
    String? groupId,
  }) async {
    final targetGroupId = groupId ?? _currentGroupId;
    if (targetGroupId == null) return false;

    // Optimistic UI update if in ContentLoaded state
    final currentState = state;
    if (currentState is ContentLoaded) {
      final updatedList = currentState.items.map((item) {
        return item.copyWith(isPublishedInGroup: isPublished);
      }).toList();
      emit(currentState.copyWith(items: updatedList));
    }

    final result = await _repository.toggleAllLessonsVisibility(
      groupId: targetGroupId,
      isPublished: isPublished,
    );

    switch (result) {
      case Success():
        AppCache.content.invalidatePrefix(targetGroupId);
        await loadGroupContent(targetGroupId, forceRefresh: true);
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        if (targetGroupId == _currentGroupId) {
          await loadGroupContent(targetGroupId, forceRefresh: true);
        }
        return false;
    }
  }

  bool _isCreatingChapter = false;

  /// Creates a new chapter for the active group
  Future<ChapterEntity?> createChapter({
    required String groupId,
    required String title,
    bool isPublished = true,
  }) async {
    if (_isCreatingChapter) return null;
    _isCreatingChapter = true;
    try {
      final result = await _repository.createChapter(
        groupId: groupId,
        title: title,
        isPublished: isPublished,
      );
      switch (result) {
        case Success(:final data):
          await loadGroupContent(groupId, forceRefresh: true);
          return data;
        case FailureResult(:final failure):
          emit(ContentError(failure.message));
          return null;
      }
    } finally {
      _isCreatingChapter = false;
    }
  }

  /// Toggles chapter visibility (published/draft)
  Future<bool> toggleChapterVisibility({
    required String chapterId,
    required bool isPublished,
  }) async {
    final result = await _repository.toggleChapterVisibility(
      chapterId: chapterId,
      isPublished: isPublished,
    );
    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        }
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Renames an existing chapter
  Future<bool> updateChapter({
    required String chapterId,
    required String title,
  }) async {
    final result = await _repository.updateChapter(
      chapterId: chapterId,
      title: title,
    );
    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        }
        return true;
      case FailureResult(:final failure):
        if (state is! ContentLoaded) {
          emit(ContentError(failure.message));
        }
        return false;
    }
  }

  /// Deletes a chapter (unlinks its lessons back to general)
  Future<bool> deleteChapter(String chapterId) async {
    final result = await _repository.deleteChapter(chapterId);
    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          await loadGroupContent(_currentGroupId!, forceRefresh: true);
        }
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Assigns or unassigns a lesson to a chapter
  Future<bool> setLessonChapter({
    required String contentId,
    required String groupId,
    String? chapterId,
  }) async {
    final result = await _repository.setLessonChapter(
      contentId: contentId,
      groupId: groupId,
      chapterId: chapterId,
    );
    switch (result) {
      case Success():
        await loadGroupContent(groupId, forceRefresh: true);
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Removes a lesson from a group
  Future<bool> removeLessonFromGroup({
    required String contentId,
    required String groupId,
  }) async {
    final result = await _repository.removeLessonFromGroup(
      contentId: contentId,
      groupId: groupId,
    );
    switch (result) {
      case Success():
        await loadGroupContent(groupId, forceRefresh: true);
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Reorders lessons within a chapter
  Future<bool> reorderChapterLessons({
    required String groupId,
    required List<String> contentIdsInOrder,
  }) async {
    final result = await _repository.reorderChapterLessons(
      groupId: groupId,
      contentIdsInOrder: contentIdsInOrder,
    );
    switch (result) {
      case Success():
        await loadGroupContent(groupId, forceRefresh: true);
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return false;
    }
  }

  /// Reorders chapters within a course/group
  Future<bool> reorderCourseChapters({
    required String groupId,
    required List<String> chapterIdsInOrder,
  }) async {
    final currentState = state;
    if (currentState is ContentLoaded) {
      // Optimistic reorder of chapters in UI
      final chapterMap = {for (final c in currentState.chapters) c.id: c};
      final reordered = <ChapterEntity>[];
      for (final id in chapterIdsInOrder) {
        final ch = chapterMap[id];
        if (ch != null) {
          reordered.add(ch);
        }
      }
      for (final c in currentState.chapters) {
        if (!chapterIdsInOrder.contains(c.id)) {
          reordered.add(c);
        }
      }
      emit(currentState.copyWith(chapters: reordered));
    }

    final result = await _repository.reorderCourseChapters(
      groupId: groupId,
      chapterIdsInOrder: chapterIdsInOrder,
    );
    switch (result) {
      case Success():
        AppCache.content.invalidatePrefix(groupId);
        await loadGroupContent(groupId, forceRefresh: true);
        return true;
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        await loadGroupContent(groupId, forceRefresh: true);
        return false;
    }
  }
}

