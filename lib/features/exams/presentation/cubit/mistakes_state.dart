import 'package:equatable/equatable.dart';
import '../../domain/entities/mistake_entities.dart';

sealed class MistakesState extends Equatable {
  const MistakesState();

  @override
  List<Object?> get props => [];
}

final class MistakesInitial extends MistakesState {
  const MistakesInitial();
}

enum MistakeStatusFilter {
  unresolved,
  resolved,
  all,
}

enum MistakeTypeFilter {
  all,
  wrongOnly,
  skippedOnly,
}

enum MistakeReasonFilter {
  all,
  conceptGap,
  carelessError,
  misreadQuestion,
  timePressure,
  unclassified,
}

enum MistakeSortOrder {
  defaultOrder,
  mostFailed,
  newest,
  points,
}

final class MistakesLoading extends MistakesState {
  const MistakesLoading();
}

final class MistakesLoaded extends MistakesState {
  final MistakeSummaryEntity summary;
  final List<MistakeQuestionEntity> questions;
  final String? selectedExamId;
  final MistakeStatusFilter statusFilter;
  final MistakeTypeFilter typeFilter;
  final MistakeReasonFilter reasonFilter;
  final MistakeSortOrder sortOrder;
  final String searchQuery;

  const MistakesLoaded({
    required this.summary,
    required this.questions,
    this.selectedExamId,
    MistakeStatusFilter? statusFilter,
    bool? onlyUnresolved,
    this.typeFilter = MistakeTypeFilter.all,
    this.reasonFilter = MistakeReasonFilter.all,
    this.sortOrder = MistakeSortOrder.defaultOrder,
    this.searchQuery = '',
  }) : statusFilter = statusFilter ??
            (onlyUnresolved != null
                ? (onlyUnresolved
                    ? MistakeStatusFilter.unresolved
                    : MistakeStatusFilter.all)
                : MistakeStatusFilter.unresolved);

  bool get onlyUnresolved => statusFilter == MistakeStatusFilter.unresolved;

  /// Instant filtered projection based on status filter, type filter, reason filter, and search query.
  List<MistakeQuestionEntity> get filteredQuestions {
    final list = questions.where((q) {
      // 1. Status Filter
      if (statusFilter == MistakeStatusFilter.unresolved && q.isResolved) {
        return false;
      }
      if (statusFilter == MistakeStatusFilter.resolved && !q.isResolved) {
        return false;
      }

      // 2. Type Filter
      if (typeFilter == MistakeTypeFilter.wrongOnly && q.isSkipped) {
        return false;
      }
      if (typeFilter == MistakeTypeFilter.skippedOnly && !q.isSkipped) {
        return false;
      }

      // 3. Reason Filter
      if (reasonFilter != MistakeReasonFilter.all) {
        switch (reasonFilter) {
          case MistakeReasonFilter.conceptGap:
            if (q.reflectionReason != 'concept_gap') return false;
            break;
          case MistakeReasonFilter.carelessError:
            if (q.reflectionReason != 'careless_error') return false;
            break;
          case MistakeReasonFilter.misreadQuestion:
            if (q.reflectionReason != 'misread_question') return false;
            break;
          case MistakeReasonFilter.timePressure:
            if (q.reflectionReason != 'time_pressure') return false;
            break;
          case MistakeReasonFilter.unclassified:
            if (q.reflectionReason != null && q.reflectionReason!.isNotEmpty) {
              return false;
            }
            break;
          case MistakeReasonFilter.all:
            break;
        }
      }

      // 4. Search Query
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final textMatches = q.questionText.toLowerCase().contains(query);
        final examMatches = q.sourceExamTitle.toLowerCase().contains(query);
        final lessonMatches =
            q.lessonTitle?.toLowerCase().contains(query) ?? false;
        if (!textMatches && !examMatches && !lessonMatches) {
          return false;
        }
      }
      return true;
    }).toList();

    switch (sortOrder) {
      case MistakeSortOrder.mostFailed:
        list.sort((a, b) => b.failureCount.compareTo(a.failureCount));
        break;
      case MistakeSortOrder.newest:
        list.sort((a, b) {
          final aDate = a.lastFailedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.lastFailedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });
        break;
      case MistakeSortOrder.points:
        list.sort((a, b) => b.points.compareTo(a.points));
        break;
      case MistakeSortOrder.defaultOrder:
        break;
    }

    return list;
  }

  double get masteryRate =>
      totalCountInList > 0 ? (resolvedCountInList / totalCountInList) : 1.0;

  int get criticalCountInList =>
      questions.where((q) => !q.isResolved && q.failureCount >= 2).length;

  int get unresolvedCountInList =>
      questions.where((q) => !q.isResolved).length;

  int get resolvedCountInList =>
      questions.where((q) => q.isResolved).length;

  int get totalCountInList => questions.length;

  int get wrongCountInList =>
      questions.where((q) => q.isWrongAnswer).length;

  int get skippedCountInList =>
      questions.where((q) => q.isSkipped).length;

  int get unresolvedWrongCountInList =>
      questions.where((q) => !q.isResolved && q.isWrongAnswer).length;

  int get unresolvedSkippedCountInList =>
      questions.where((q) => !q.isResolved && q.isSkipped).length;

  MistakesLoaded copyWith({
    MistakeSummaryEntity? summary,
    List<MistakeQuestionEntity>? questions,
    String? selectedExamId,
    bool clearSelectedExam = false,
    MistakeStatusFilter? statusFilter,
    bool? onlyUnresolved,
    MistakeTypeFilter? typeFilter,
    MistakeReasonFilter? reasonFilter,
    MistakeSortOrder? sortOrder,
    String? searchQuery,
  }) {
    return MistakesLoaded(
      summary: summary ?? this.summary,
      questions: questions ?? this.questions,
      selectedExamId: clearSelectedExam
          ? null
          : (selectedExamId ?? this.selectedExamId),
      statusFilter: statusFilter ??
          (onlyUnresolved != null
              ? (onlyUnresolved
                  ? MistakeStatusFilter.unresolved
                  : MistakeStatusFilter.all)
              : this.statusFilter),
      typeFilter: typeFilter ?? this.typeFilter,
      reasonFilter: reasonFilter ?? this.reasonFilter,
      sortOrder: sortOrder ?? this.sortOrder,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        summary,
        questions,
        selectedExamId,
        statusFilter,
        typeFilter,
        reasonFilter,
        sortOrder,
        searchQuery,
      ];
}

final class MistakesError extends MistakesState {
  final String message;

  const MistakesError(this.message);

  @override
  List<Object?> get props => [message];
}

final class MistakesPracticeSubmitting extends MistakesState {
  const MistakesPracticeSubmitting();
}

final class MistakesPracticeCompleted extends MistakesState {
  final MistakePracticeResultEntity result;

  const MistakesPracticeCompleted(this.result);

  @override
  List<Object?> get props => [result];
}
