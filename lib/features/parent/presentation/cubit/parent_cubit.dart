import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/child_entity.dart';
import '../../domain/repositories/parent_repository.dart';
import 'parent_state.dart';

class ParentCubit extends Cubit<ParentState> {
  final ParentRepository _repository;

  ParentCubit({required ParentRepository repository})
    : _repository = repository,
      super(const ParentInitial());

  /// Loads the parent dashboard by fetching linked children and summary of the first child
  Future<void> loadParentDashboard() async {
    emit(const ParentLoading());

    final childrenResult = await _repository.getLinkedChildren();

    await childrenResult.when(
      onSuccess: (children) async {
        if (children.isEmpty) {
          emit(const ParentNoChildren());
          return;
        }

        final selectedChild = children.first;
        emit(
          ParentLoaded(
            children: children,
            selectedChild: selectedChild,
            isLoadingSummary: true,
          ),
        );

        await _loadSummaryForChild(selectedChild, children);
      },
      onFailure: (failure) async {
        emit(ParentError(failure.message));
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

    emit(
      currentState.copyWith(
        selectedChild: child,
        isLoadingSummary: true,
        summary: null,
      ),
    );

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
      );
    } else {
      await loadParentDashboard();
    }
  }

  Future<void> _loadSummaryForChild(
    ChildEntity child,
    List<ChildEntity> allChildren,
  ) async {
    final summaryResult = await _repository.getChildAcademicSummary(child.id);

    summaryResult.when(
      onSuccess: (summary) {
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
