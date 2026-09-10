import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/repositories/content_repository.dart';
import 'content_state.dart';

class ContentCubit extends Cubit<ContentState> {
  final ContentRepository _repository;
  String? _currentGroupId;

  ContentCubit({
    required ContentRepository repository,
  })  : _repository = repository,
        super(const ContentInitial());

  String? get currentGroupId => _currentGroupId;

  /// Loads content for a group.
  /// If [isStudent] is true, only published content is retrieved.
  Future<void> loadGroupContent(
    String groupId, {
    ContentStatus? statusFilter,
    bool isStudent = false,
  }) async {
    _currentGroupId = groupId;
    emit(const ContentLoading(message: 'جاري تحميل المحتوى التعليمي…'));

    final filter = isStudent ? ContentStatus.published : statusFilter;
    final result = await _repository.getGroupContent(
      groupId: groupId,
      statusFilter: filter,
    );

    switch (result) {
      case Success(:final data):
        emit(ContentLoaded(items: data, activeFilter: statusFilter));
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
    }
  }

  /// Sets status filter without re-fetching if items are already loaded
  void setFilter(ContentStatus? filter) {
    if (state is ContentLoaded) {
      final current = state as ContentLoaded;
      emit(current.copyWith(activeFilter: filter, clearFilter: filter == null));
    }
  }

  /// Creates a new content item
  Future<bool> createContent({
    required String groupId,
    required String title,
    String? description,
    required ContentType type,
    required ContentStatus status,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
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
    );

    switch (result) {
      case Success():
        await loadGroupContent(groupId);
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
  }) async {
    final result = await _repository.updateContent(
      contentId: contentId,
      title: title,
      description: description,
      type: type,
      status: status,
    );

    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          await loadGroupContent(_currentGroupId!);
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
          await loadGroupContent(_currentGroupId!);
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
          await loadGroupContent(_currentGroupId!);
        }
    }
  }

  /// Deletes a content item
  Future<void> deleteContent(String contentId) async {
    final result = await _repository.deleteContent(contentId);
    switch (result) {
      case Success():
        if (_currentGroupId != null) {
          await loadGroupContent(_currentGroupId!);
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
      case FailureResult(:final failure):
        emit(ContentError(failure.message));
        return null;
    }
  }
}
