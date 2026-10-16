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

enum MistakeTypeFilter {
  all,
  wrongOnly,
  skippedOnly,
}

final class MistakesLoading extends MistakesState {
  const MistakesLoading();
}

final class MistakesLoaded extends MistakesState {
  final MistakeSummaryEntity summary;
  final List<MistakeQuestionEntity> questions;
  final String? selectedExamId;
  final bool onlyUnresolved;
  final MistakeTypeFilter typeFilter;
  final String searchQuery;

  const MistakesLoaded({
    required this.summary,
    required this.questions,
    this.selectedExamId,
    this.onlyUnresolved = true,
    this.typeFilter = MistakeTypeFilter.all,
    this.searchQuery = '',
  });

  /// Instant filtered projection based on type filter and search query.
  List<MistakeQuestionEntity> get filteredQuestions {
    return questions.where((q) {
      if (typeFilter == MistakeTypeFilter.wrongOnly && q.isSkipped) {
        return false;
      }
      if (typeFilter == MistakeTypeFilter.skippedOnly && !q.isSkipped) {
        return false;
      }
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
  }

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
    bool? onlyUnresolved,
    MistakeTypeFilter? typeFilter,
    String? searchQuery,
  }) {
    return MistakesLoaded(
      summary: summary ?? this.summary,
      questions: questions ?? this.questions,
      selectedExamId: clearSelectedExam
          ? null
          : (selectedExamId ?? this.selectedExamId),
      onlyUnresolved: onlyUnresolved ?? this.onlyUnresolved,
      typeFilter: typeFilter ?? this.typeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [
        summary,
        questions,
        selectedExamId,
        onlyUnresolved,
        typeFilter,
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
