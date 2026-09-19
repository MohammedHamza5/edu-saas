import 'package:equatable/equatable.dart';
import '../../domain/entities/content_entity.dart';

sealed class ContentState extends Equatable {
  const ContentState();

  @override
  List<Object?> get props => [];
}

class ContentInitial extends ContentState {
  const ContentInitial();
}

class ContentLoading extends ContentState {
  final String? message;
  const ContentLoading({this.message});

  @override
  List<Object?> get props => [message];
}

class ContentLoaded extends ContentState {
  final List<ContentEntity> items;
  final ContentStatus? activeFilter;
  final bool isReordering;
  final bool hasMore;
  final bool isLoadingMore;

  const ContentLoaded({
    required this.items,
    this.activeFilter,
    this.isReordering = false,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  /// Items filtered by current selected status
  List<ContentEntity> get filteredItems {
    if (activeFilter == null) return items;
    return items.where((item) => item.status == activeFilter).toList();
  }

  int get draftCount =>
      items.where((i) => i.status == ContentStatus.draft).length;
  int get publishedCount =>
      items.where((i) => i.status == ContentStatus.published).length;
  int get archivedCount =>
      items.where((i) => i.status == ContentStatus.archived).length;

  ContentLoaded copyWith({
    List<ContentEntity>? items,
    ContentStatus? activeFilter,
    bool clearFilter = false,
    bool? isReordering,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ContentLoaded(
      items: items ?? this.items,
      activeFilter: clearFilter ? null : (activeFilter ?? this.activeFilter),
      isReordering: isReordering ?? this.isReordering,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        items,
        activeFilter,
        isReordering,
        hasMore,
        isLoadingMore,
      ];
}

class ContentOperationSuccess extends ContentState {
  final String message;
  final String? openedUrl;

  const ContentOperationSuccess(this.message, {this.openedUrl});

  @override
  List<Object?> get props => [message, openedUrl];
}

class ContentError extends ContentState {
  final String message;
  const ContentError(this.message);

  @override
  List<Object?> get props => [message];
}
