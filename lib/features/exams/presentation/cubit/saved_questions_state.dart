import 'package:equatable/equatable.dart';
import '../../domain/entities/saved_question_entity.dart';

enum VaultFilterType {
  all,
  dueToday,
  upcoming,
  mastered,
  needsReview,
}

abstract class SavedQuestionsState extends Equatable {
  const SavedQuestionsState();

  @override
  List<Object?> get props => [];
}

class SavedQuestionsInitial extends SavedQuestionsState {
  const SavedQuestionsInitial();
}

class SavedQuestionsLoading extends SavedQuestionsState {
  const SavedQuestionsLoading();
}

class SavedQuestionsEmpty extends SavedQuestionsState {
  const SavedQuestionsEmpty();
}

class SavedQuestionsLoaded extends SavedQuestionsState {
  final List<SavedQuestionEntity> questions;
  final VaultFilterType activeFilter;
  final QuestionDifficultyRating? activeDifficultyFilter;
  final String searchQuery;

  const SavedQuestionsLoaded({
    required this.questions,
    this.activeFilter = VaultFilterType.all,
    this.activeDifficultyFilter,
    this.searchQuery = '',
  });

  List<SavedQuestionEntity> get dueTodayQuestions =>
      questions.where((q) => q.isDueToday).toList();

  List<SavedQuestionEntity> get upcomingQuestions => questions
      .where((q) => !q.isMastered && q.nextReviewAt != null && q.nextReviewAt!.isAfter(DateTime.now()))
      .toList();

  List<SavedQuestionEntity> get masteredQuestions =>
      questions.where((q) => q.isMastered).toList();

  List<SavedQuestionEntity> get filteredQuestions {
    return questions.where((q) {
      if (activeFilter == VaultFilterType.dueToday && !q.isDueToday) {
        return false;
      }
      if (activeFilter == VaultFilterType.upcoming &&
          (q.isMastered || q.nextReviewAt == null || !q.nextReviewAt!.isAfter(DateTime.now()))) {
        return false;
      }
      if (activeFilter == VaultFilterType.mastered && !q.isMastered) {
        return false;
      }
      if (activeFilter == VaultFilterType.needsReview && q.isMastered) {
        return false;
      }
      if (activeDifficultyFilter != null && q.difficultyRating != activeDifficultyFilter) {
        return false;
      }
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final textMatches = q.questionText.toLowerCase().contains(query);
        final noteMatches = (q.personalNote ?? '').toLowerCase().contains(query);
        final examMatches = q.examTitle.toLowerCase().contains(query);
        if (!textMatches && !noteMatches && !examMatches) return false;
      }
      return true;
    }).toList();
  }

  int get dueTodayCount => dueTodayQuestions.length;
  int get upcomingCount => upcomingQuestions.length;
  int get masteredCount => masteredQuestions.length;
  int get needsReviewCount => questions.where((q) => !q.isMastered).length;

  int get box1Count =>
      questions.where((q) => !q.isMastered && q.difficultyRating == QuestionDifficultyRating.hard).length;
  int get box2Count =>
      questions.where((q) => !q.isMastered && q.difficultyRating == QuestionDifficultyRating.medium).length;
  int get box3Count =>
      questions.where((q) => !q.isMastered && q.difficultyRating == QuestionDifficultyRating.easy).length;

  int get easyCount => questions.where((q) => q.difficultyRating == QuestionDifficultyRating.easy).length;
  int get mediumCount => questions.where((q) => q.difficultyRating == QuestionDifficultyRating.medium).length;
  int get hardCount => questions.where((q) => q.difficultyRating == QuestionDifficultyRating.hard).length;

  SavedQuestionsLoaded copyWith({
    List<SavedQuestionEntity>? questions,
    VaultFilterType? activeFilter,
    QuestionDifficultyRating? activeDifficultyFilter,
    bool clearDifficultyFilter = false,
    String? searchQuery,
  }) {
    return SavedQuestionsLoaded(
      questions: questions ?? this.questions,
      activeFilter: activeFilter ?? this.activeFilter,
      activeDifficultyFilter: clearDifficultyFilter
          ? null
          : (activeDifficultyFilter ?? this.activeDifficultyFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [questions, activeFilter, activeDifficultyFilter, searchQuery];
}

class SavedQuestionsError extends SavedQuestionsState {
  final String message;

  const SavedQuestionsError(this.message);

  @override
  List<Object?> get props => [message];
}
