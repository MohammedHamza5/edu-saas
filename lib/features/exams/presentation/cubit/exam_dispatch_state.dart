import 'package:equatable/equatable.dart';
import '../../domain/entities/exam_parent_dispatch_entity.dart';

enum ExamDispatchFilter {
  all,
  submitted,
  passed,
  needsAttention,
  notStarted,
  unnotified,
  notified,
  missingPhone,
}

enum ExamDispatchSort {
  highestScore,
  lowestScore,
  name,
  latestSubmitted,
}

abstract class ExamDispatchState extends Equatable {
  const ExamDispatchState();

  @override
  List<Object?> get props => [];
}

class ExamDispatchInitial extends ExamDispatchState {
  const ExamDispatchInitial();
}

class ExamDispatchLoading extends ExamDispatchState {
  const ExamDispatchLoading();
}

class ExamDispatchLoaded extends ExamDispatchState {
  final ExamParentDispatchRosterEntity roster;
  final Set<String> sentStudentIds;
  final ExamDispatchFilter activeFilter;
  final String searchQuery;
  final ExamDispatchSort activeSort;
  final bool isUpdatingPhone;

  const ExamDispatchLoaded({
    required this.roster,
    this.sentStudentIds = const {},
    this.activeFilter = ExamDispatchFilter.all,
    this.searchQuery = '',
    this.activeSort = ExamDispatchSort.highestScore,
    this.isUpdatingPhone = false,
  });

  List<ExamDispatchStudentEntity> get filteredStudents {
    var list = List<ExamDispatchStudentEntity>.from(roster.students);

    // 1. Text Search
    if (searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((s) {
        final nameMatch = s.studentName.toLowerCase().contains(q);
        final phoneMatch = s.parentPhone?.contains(q) == true ||
            s.studentPhone?.contains(q) == true;
        final groupMatch = s.groupName.toLowerCase().contains(q);
        return nameMatch || phoneMatch || groupMatch;
      }).toList();
    }

    // 2. Filter Tab
    switch (activeFilter) {
      case ExamDispatchFilter.all:
        break;
      case ExamDispatchFilter.submitted:
        list = list.where((s) => s.isSubmitted).toList();
        break;
      case ExamDispatchFilter.passed:
        list = list.where((s) => s.isSubmitted && s.isPassed).toList();
        break;
      case ExamDispatchFilter.needsAttention:
        list = list.where((s) => s.isSubmitted && !s.isPassed).toList();
        break;
      case ExamDispatchFilter.notStarted:
        list = list.where((s) => s.isNotStarted || s.isInProgress).toList();
        break;
      case ExamDispatchFilter.unnotified:
        list = list.where((s) => !sentStudentIds.contains(s.studentId)).toList();
        break;
      case ExamDispatchFilter.notified:
        list = list.where((s) => sentStudentIds.contains(s.studentId)).toList();
        break;
      case ExamDispatchFilter.missingPhone:
        list = list.where((s) => !s.hasParentPhone).toList();
        break;
    }

    // 3. Sorting
    list.sort((a, b) {
      switch (activeSort) {
        case ExamDispatchSort.highestScore:
          final scoreA = a.bestScore ?? -1;
          final scoreB = b.bestScore ?? -1;
          if (scoreA != scoreB) return scoreB.compareTo(scoreA);
          return a.studentName.compareTo(b.studentName);

        case ExamDispatchSort.lowestScore:
          final scoreA = a.bestScore ?? 9999;
          final scoreB = b.bestScore ?? 9999;
          if (scoreA != scoreB) return scoreA.compareTo(scoreB);
          return a.studentName.compareTo(b.studentName);

        case ExamDispatchSort.name:
          return a.studentName.compareTo(b.studentName);

        case ExamDispatchSort.latestSubmitted:
          final dateA = a.latestSubmittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final dateB = b.latestSubmittedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return dateB.compareTo(dateA);
      }
    });

    return list;
  }

  int get notifiedCount =>
      roster.students.where((s) => sentStudentIds.contains(s.studentId)).length;

  ExamDispatchLoaded copyWith({
    ExamParentDispatchRosterEntity? roster,
    Set<String>? sentStudentIds,
    ExamDispatchFilter? activeFilter,
    String? searchQuery,
    ExamDispatchSort? activeSort,
    bool? isUpdatingPhone,
  }) {
    return ExamDispatchLoaded(
      roster: roster ?? this.roster,
      sentStudentIds: sentStudentIds ?? this.sentStudentIds,
      activeFilter: activeFilter ?? this.activeFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      activeSort: activeSort ?? this.activeSort,
      isUpdatingPhone: isUpdatingPhone ?? this.isUpdatingPhone,
    );
  }

  @override
  List<Object?> get props => [
        roster,
        sentStudentIds,
        activeFilter,
        searchQuery,
        activeSort,
        isUpdatingPhone,
      ];
}

class ExamDispatchError extends ExamDispatchState {
  final String message;

  const ExamDispatchError(this.message);

  @override
  List<Object?> get props => [message];
}
