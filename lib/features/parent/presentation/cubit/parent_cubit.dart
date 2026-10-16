import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../domain/entities/child_entity.dart';
import '../../domain/repositories/parent_repository.dart';
import 'parent_state.dart';

class ParentCubit extends Cubit<ParentState> {
  final ParentRepository _repository;

  ParentCubit({required ParentRepository repository})
    : _repository = repository,
      super(const ParentInitial());

  /// Loads the parent dashboard by fetching linked children and summary of the first child
  Future<void> loadParentDashboard({bool forceRefresh = false}) async {
    final cacheKeyChildren = AppCache.userKey('parent_children');
    if (!forceRefresh) {
      final cachedChildren =
          AppCache.parent.get(cacheKeyChildren) as List<ChildEntity>?;
      if (cachedChildren != null && cachedChildren.isNotEmpty) {
        final firstChild = cachedChildren.first;
        final summaryKey = AppCache.userKey('parent_summary_${firstChild.id}');
        final cachedSummary =
            AppCache.parent.get(summaryKey) as ChildAcademicSummary?;
        emit(
          ParentLoaded(
            children: cachedChildren,
            selectedChild: firstChild,
            summary: cachedSummary,
            isLoadingSummary: cachedSummary == null,
          ),
        );
      } else {
        emit(const ParentLoading());
      }
    } else {
      emit(const ParentLoading());
    }

    final childrenResult = await _repository.getLinkedChildren();

    await childrenResult.when(
      onSuccess: (children) async {
        if (children.isEmpty) {
          emit(const ParentNoChildren());
          return;
        }

        AppCache.parent.put(cacheKeyChildren, children);
        final selectedChild = children.first;
        emit(
          ParentLoaded(
            children: children,
            selectedChild: selectedChild,
            isLoadingSummary: true,
          ),
        );

        await _loadSummaryForChild(
          selectedChild,
          children,
          forceRefresh: forceRefresh,
        );
      },
      onFailure: (failure) async {
        if (state is! ParentLoaded) {
          emit(ParentError(failure.message));
        }
      },
    );
  }

  /// Switches the currently viewed child (P-02 Child Selector)
  Future<void> selectChild(ChildEntity child) async {
    final currentState = state;
    if (currentState is! ParentLoaded) return;
    if (currentState.selectedChild.id == child.id &&
        currentState.summary != null) {
      return;
    }

    final summaryKey = AppCache.userKey('parent_summary_${child.id}');
    final cachedSummary =
        AppCache.parent.get(summaryKey) as ChildAcademicSummary?;

    if (cachedSummary != null) {
      emit(
        currentState.copyWith(
          selectedChild: child,
          summary: cachedSummary,
          isLoadingSummary: false,
        ),
      );
    } else {
      emit(
        currentState.copyWith(
          selectedChild: child,
          isLoadingSummary: true,
          clearSummary: true,
        ),
      );
    }

    await _loadSummaryForChild(child, currentState.children);
  }

  /// Refreshes the currently selected child's academic data
  Future<void> refresh() async {
    final currentState = state;
    if (currentState is ParentLoaded) {
      emit(currentState.copyWith(isLoadingSummary: true));
      await _loadSummaryForChild(
        currentState.selectedChild,
        currentState.children,
        forceRefresh: true,
      );
    } else {
      await loadParentDashboard(forceRefresh: true);
    }
  }

  Future<void> _loadSummaryForChild(
    ChildEntity child,
    List<ChildEntity> allChildren, {
    bool forceRefresh = false,
  }) async {
    final summaryKey = AppCache.userKey('parent_summary_${child.id}');

    final summaryResult = await _repository.getChildAcademicSummary(child.id);

    summaryResult.when(
      onSuccess: (summary) {
        AppCache.parent.put(summaryKey, summary);
        emit(
          ParentLoaded(
            children: allChildren,
            selectedChild: child,
            summary: summary,
            isLoadingSummary: false,
          ),
        );
      },
      onFailure: (failure) {
        final current = state;
        if (current is ParentLoaded && current.summary != null) {
          return;
        }
        emit(
          ParentLoaded(
            children: allChildren,
            selectedChild: child,
            summary: null,
            isLoadingSummary: false,
            errorMessage: failure.message,
          ),
        );
      },
    );
  }
}
