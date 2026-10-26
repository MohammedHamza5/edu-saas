import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/mistakes_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/mistakes_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMistakesRepo implements ExamsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Pillar 3: Zero-Mistake Gauntlet & Rapid Sprint Unit Tests', () {
    late MistakesCubit cubit;

    final q1 = MistakeQuestionEntity(
      mistakeId: 'm1', questionId: 'q1', questionText: 'Q1', questionType: 'multiple_choice',
      points: 2, sortOrder: 1, isResolved: false, failureCount: 1,
      lastFailedAt: DateTime(2026, 10, 10), sourceExamId: 'ex1', sourceExamTitle: 'Exam 1',
      options: const [],
    );

    final q2 = MistakeQuestionEntity(
      mistakeId: 'm2', questionId: 'q2', questionText: 'Q2', questionType: 'multiple_choice',
      points: 10, sortOrder: 2, isResolved: false, failureCount: 4,
      lastFailedAt: DateTime(2026, 10, 20), sourceExamId: 'ex1', sourceExamTitle: 'Exam 1',
      options: const [],
    );

    final q3 = MistakeQuestionEntity(
      mistakeId: 'm3', questionId: 'q3', questionText: 'Q3', questionType: 'multiple_choice',
      points: 5, sortOrder: 3, isResolved: true, failureCount: 2,
      lastFailedAt: DateTime(2026, 10, 15), sourceExamId: 'ex1', sourceExamTitle: 'Exam 1',
      options: const [],
    );

    final q4 = MistakeQuestionEntity(
      mistakeId: 'm4', questionId: 'q4', questionText: 'Q4', questionType: 'multiple_choice',
      points: 8, sortOrder: 4, isResolved: false, failureCount: 2,
      lastFailedAt: DateTime(2026, 10, 18), sourceExamId: 'ex1', sourceExamTitle: 'Exam 1',
      options: const [],
    );

    const testSummary = MistakeSummaryEntity(
      totalMistakes: 4, unresolvedCount: 3, resolvedCount: 1, sources: [],
    );

    setUp(() {
      cubit = MistakesCubit(repository: _FakeMistakesRepo());
    });

    tearDown(() {
      cubit.close();
    });

    test('masteryRate calculates correct percentage or 1.0 for empty list', () {
      final state4 = MistakesLoaded(
        summary: testSummary, questions: [q1, q2, q3, q4],
        statusFilter: MistakeStatusFilter.all,
      );
      expect(state4.masteryRate, 0.25); // 1 resolved / 4 total

      const stateEmpty = MistakesLoaded(
        summary: MistakeSummaryEntity(totalMistakes: 0, unresolvedCount: 0, resolvedCount: 0, sources: []),
        questions: [], statusFilter: MistakeStatusFilter.all,
      );
      expect(stateEmpty.masteryRate, 1.0);
    });

    test('criticalCountInList counts only unresolved questions with failureCount >= 2', () {
      final state = MistakesLoaded(
        summary: testSummary, questions: [q1, q2, q3, q4],
        statusFilter: MistakeStatusFilter.all,
      );
      // q1: unresolved, count 1 (not critical)
      // q2: unresolved, count 4 (critical)
      // q3: resolved, count 2 (resolved, so not critical)
      // q4: unresolved, count 2 (critical)
      expect(state.criticalCountInList, 2);
    });

    test('Smart Sorting: mostFailed sorts by failureCount descending', () {
      final state = MistakesLoaded(
        summary: testSummary, questions: [q1, q2, q4],
        statusFilter: MistakeStatusFilter.all,
        sortOrder: MistakeSortOrder.mostFailed,
      );
      final sorted = state.filteredQuestions;
      expect(sorted[0].questionId, 'q2'); // count 4
      expect(sorted[1].questionId, 'q4'); // count 2
      expect(sorted[2].questionId, 'q1'); // count 1
    });

    test('Smart Sorting: newest sorts by lastFailedAt descending', () {
      final state = MistakesLoaded(
        summary: testSummary, questions: [q1, q2, q4],
        statusFilter: MistakeStatusFilter.all,
        sortOrder: MistakeSortOrder.newest,
      );
      final sorted = state.filteredQuestions;
      expect(sorted[0].questionId, 'q2'); // Oct 20
      expect(sorted[1].questionId, 'q4'); // Oct 18
      expect(sorted[2].questionId, 'q1'); // Oct 10
    });

    test('Smart Sorting: points sorts by points descending', () {
      final state = MistakesLoaded(
        summary: testSummary, questions: [q1, q2, q4],
        statusFilter: MistakeStatusFilter.all,
        sortOrder: MistakeSortOrder.points,
      );
      final sorted = state.filteredQuestions;
      expect(sorted[0].questionId, 'q2'); // 10 pts
      expect(sorted[1].questionId, 'q4'); // 8 pts
      expect(sorted[2].questionId, 'q1'); // 2 pts
    });

    test('MistakesCubit.setSortOrder emits updated sortOrder', () {
      final base = MistakesLoaded(
        summary: testSummary, questions: [q1, q2, q3, q4],
        statusFilter: MistakeStatusFilter.all,
        sortOrder: MistakeSortOrder.defaultOrder,
      );
      cubit.emit(base);

      cubit.setSortOrder(MistakeSortOrder.mostFailed);
      expect((cubit.state as MistakesLoaded).sortOrder, MistakeSortOrder.mostFailed);

      cubit.setSortOrder(MistakeSortOrder.points);
      expect((cubit.state as MistakesLoaded).sortOrder, MistakeSortOrder.points);
    });
  });
}
