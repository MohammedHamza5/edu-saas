import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/data/models/mistake_models.dart';
import 'package:edu_saas/features/exams/presentation/cubit/mistakes_state.dart';

void main() {
  group('Mistakes Bank Unit Tests', () {
    test('MistakeQuestionEntity correctly identifies skipped vs wrong answers', () {
      const skippedQuestion = MistakeQuestionEntity(
        mistakeId: 'm1',
        questionId: 'q1',
        questionText: 'What is 2+2?',
        questionType: 'single_choice',
        points: 5,
        sortOrder: 1,
        isResolved: false,
        failureCount: 1,
        sourceExamId: 'exam1',
        sourceExamTitle: 'Math Exam',
        lastSelectedOptionId: null, // skipped
        options: [],
      );

      const wrongQuestion = MistakeQuestionEntity(
        mistakeId: 'm2',
        questionId: 'q2',
        questionText: 'What is 3+3?',
        questionType: 'single_choice',
        points: 5,
        sortOrder: 2,
        isResolved: false,
        failureCount: 2,
        sourceExamId: 'exam1',
        sourceExamTitle: 'Math Exam',
        lastSelectedOptionId: 'opt_b', // chosen wrong
        selectedOptionText: 'Option B (wrong)',
        options: [],
      );

      expect(skippedQuestion.isSkipped, isTrue);
      expect(skippedQuestion.isWrongAnswer, isFalse);

      expect(wrongQuestion.isSkipped, isFalse);
      expect(wrongQuestion.isWrongAnswer, isTrue);
      expect(wrongQuestion.selectedOptionText, equals('Option B (wrong)'));
    });

    test('MistakeSummaryModel parses breakdown fields with safe defaults', () {
      final json = {
        'total_mistakes': 10,
        'unresolved_count': 6,
        'resolved_count': 4,
        'unresolved_wrong_count': 4,
        'unresolved_skipped_count': 2,
        'sources': <dynamic>[],
      };

      final summary = MistakeSummaryModel.fromJson(json);

      expect(summary.totalMistakes, equals(10));
      expect(summary.unresolvedCount, equals(6));
      expect(summary.resolvedCount, equals(4));
      expect(summary.unresolvedWrongCount, equals(4));
      expect(summary.unresolvedSkippedCount, equals(2));
    });

    test('MistakesLoaded filters by type and search query accurately', () {
      const qWrong = MistakeQuestionEntity(
        mistakeId: 'm1',
        questionId: 'q1',
        questionText: 'Calculate the derivative of f(x)',
        questionType: 'single_choice',
        points: 5,
        sortOrder: 1,
        isResolved: false,
        failureCount: 1,
        sourceExamId: 'e1',
        sourceExamTitle: 'Calculus 101',
        lastSelectedOptionId: 'opt_1',
        options: [],
      );

      const qSkipped = MistakeQuestionEntity(
        mistakeId: 'm2',
        questionId: 'q2',
        questionText: 'Find the limit as x approaches zero',
        questionType: 'single_choice',
        points: 5,
        sortOrder: 2,
        isResolved: false,
        failureCount: 1,
        sourceExamId: 'e1',
        sourceExamTitle: 'Calculus 101',
        lastSelectedOptionId: null,
        options: [],
      );

      const stateAll = MistakesLoaded(
        summary: MistakeSummaryEntity(
          totalMistakes: 2,
          unresolvedCount: 2,
          resolvedCount: 0,
          sources: [],
        ),
        questions: [qWrong, qSkipped],
        typeFilter: MistakeTypeFilter.all,
      );

      expect(stateAll.filteredQuestions.length, equals(2));
      expect(stateAll.wrongCountInList, equals(1));
      expect(stateAll.skippedCountInList, equals(1));

      // Filter only wrong answers
      final stateWrongOnly = stateAll.copyWith(typeFilter: MistakeTypeFilter.wrongOnly);
      expect(stateWrongOnly.filteredQuestions.length, equals(1));
      expect(stateWrongOnly.filteredQuestions.first.questionId, equals('q1'));

      // Filter only skipped questions
      final stateSkippedOnly = stateAll.copyWith(typeFilter: MistakeTypeFilter.skippedOnly);
      expect(stateSkippedOnly.filteredQuestions.length, equals(1));
      expect(stateSkippedOnly.filteredQuestions.first.questionId, equals('q2'));

      // Search query filter
      final stateSearch = stateAll.copyWith(searchQuery: 'derivative');
      expect(stateSearch.filteredQuestions.length, equals(1));
      expect(stateSearch.filteredQuestions.first.questionId, equals('q1'));
    });

    test('MistakesLoaded filters by MistakeStatusFilter (unresolved, resolved, all) accurately', () {
      const qUnresolved = MistakeQuestionEntity(
        mistakeId: 'm1',
        questionId: 'q1',
        questionText: 'Question 1',
        questionType: 'single_choice',
        points: 5,
        sortOrder: 1,
        isResolved: false,
        failureCount: 2,
        sourceExamId: 'e1',
        sourceExamTitle: 'Algebra',
        lastSelectedOptionId: 'opt_1',
        options: [],
      );

      const qResolved = MistakeQuestionEntity(
        mistakeId: 'm2',
        questionId: 'q2',
        questionText: 'Question 2',
        questionType: 'single_choice',
        points: 5,
        sortOrder: 2,
        isResolved: true,
        failureCount: 1,
        sourceExamId: 'e1',
        sourceExamTitle: 'Algebra',
        lastSelectedOptionId: 'opt_2',
        options: [],
      );

      const state = MistakesLoaded(
        summary: MistakeSummaryEntity(
          totalMistakes: 2,
          unresolvedCount: 1,
          resolvedCount: 1,
          sources: [],
        ),
        questions: [qUnresolved, qResolved],
        statusFilter: MistakeStatusFilter.unresolved,
      );

      // Default: unresolved only
      expect(state.filteredQuestions.length, equals(1));
      expect(state.filteredQuestions.first.questionId, equals('q1'));
      expect(state.unresolvedCountInList, equals(1));
      expect(state.resolvedCountInList, equals(1));
      expect(state.totalCountInList, equals(2));

      // Switch to resolved
      final stateResolved = state.copyWith(statusFilter: MistakeStatusFilter.resolved);
      expect(stateResolved.filteredQuestions.length, equals(1));
      expect(stateResolved.filteredQuestions.first.questionId, equals('q2'));

      // Switch to all
      final stateAllStatus = state.copyWith(statusFilter: MistakeStatusFilter.all);
      expect(stateAllStatus.filteredQuestions.length, equals(2));
    });
  });
}
