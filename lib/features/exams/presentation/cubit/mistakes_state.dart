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

final class MistakesLoading extends MistakesState {
  const MistakesLoading();
}

final class MistakesLoaded extends MistakesState {
  final MistakeSummaryEntity summary;
  final List<MistakeQuestionEntity> questions;
  final String? selectedExamId;
  final bool onlyUnresolved;

  const MistakesLoaded({
    required this.summary,
    required this.questions,
    this.selectedExamId,
    this.onlyUnresolved = true,
  });

  MistakesLoaded copyWith({
    MistakeSummaryEntity? summary,
    List<MistakeQuestionEntity>? questions,
    String? selectedExamId,
    bool clearSelectedExam = false,
    bool? onlyUnresolved,
  }) {
    return MistakesLoaded(
      summary: summary ?? this.summary,
      questions: questions ?? this.questions,
      selectedExamId: clearSelectedExam ? null : (selectedExamId ?? this.selectedExamId),
      onlyUnresolved: onlyUnresolved ?? this.onlyUnresolved,
    );
  }

  @override
  List<Object?> get props => [summary, questions, selectedExamId, onlyUnresolved];
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
