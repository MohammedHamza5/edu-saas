import 'package:equatable/equatable.dart';
import '../../domain/entities/child_entity.dart';

sealed class ParentState extends Equatable {
  const ParentState();

  @override
  List<Object?> get props => [];
}

final class ParentInitial extends ParentState {
  const ParentInitial();
}

final class ParentLoading extends ParentState {
  const ParentLoading();
}

final class ParentNoChildren extends ParentState {
  const ParentNoChildren();
}

final class ParentLoaded extends ParentState {
  final List<ChildEntity> children;
  final ChildEntity selectedChild;
  final ChildAcademicSummary? summary;
  final bool isLoadingSummary;
  final String? errorMessage;

  const ParentLoaded({
    required this.children,
    required this.selectedChild,
    this.summary,
    this.isLoadingSummary = false,
    this.errorMessage,
  });

  ParentLoaded copyWith({
    List<ChildEntity>? children,
    ChildEntity? selectedChild,
    ChildAcademicSummary? summary,
    bool? isLoadingSummary,
    String? errorMessage,
  }) {
    return ParentLoaded(
      children: children ?? this.children,
      selectedChild: selectedChild ?? this.selectedChild,
      summary: summary ?? this.summary,
      isLoadingSummary: isLoadingSummary ?? this.isLoadingSummary,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    children,
    selectedChild,
    summary,
    isLoadingSummary,
    errorMessage,
  ];
}

final class ParentError extends ParentState {
  final String message;

  const ParentError(this.message);

  @override
  List<Object?> get props => [message];
}
