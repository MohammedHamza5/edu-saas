import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/features/exams/data/models/mistake_models.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/mistakes_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/mistakes_state.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExamsRepositoryForMistakes implements ExamsRepository {
  String? lastUpdatedMistakeId;
  String? lastUpdatedReason;

  @override
  Future<Result<bool>> updateMistakeReflection({
    required String mistakeId,
    required String? reflectionReason,
  }) async {
    lastUpdatedMistakeId = mistakeId;
    lastUpdatedReason = reflectionReason;
    return const Success(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Pacing & Mistake Taxonomy Unit Tests', () {
    test('MistakeSummaryModel parses taxonomy breakdown from JSON accurately', () {
      final json = {
        'total_mistakes': 15,
        'unresolved_count': 10,
        'resolved_count': 5,
        'concept_gap_count': 4,
        'careless_error_count': 3,
        'misread_question_count': 2,
        'time_pressure_count': 1,
        'sources': <dynamic>[],
      };
      final model = MistakeSummaryModel.fromJson(json);
      expect(model.totalMistakes, equals(15));
      expect(model.conceptGapCount, equals(4));
      expect(model.carelessErrorCount, equals(3));
      expect(model.misreadQuestionCount, equals(2));
      expect(model.timePressureCount, equals(1));
    });

    test('MistakeQuestionEntity copyWith properly updates reflectionReason', () {
      const q = MistakeQuestionEntity(
        mistakeId: 'm-1',
        questionId: 'q-1',
        questionText: 'Simplify 3x + 4x',
        questionType: 'multiple_choice',
        points: 5,
        sortOrder: 1,
        isResolved: false,
        failureCount: 1,
        sourceExamId: 'exam-1',
        sourceExamTitle: 'Algebra 1',
        options: [],
      );
      expect(q.reflectionReason, isNull);
      final updated = q.copyWith(reflectionReason: 'careless_error');
      expect(updated.reflectionReason, equals('careless_error'));
      expect(updated.mistakeId, equals('m-1'));
    });

    test('MistakesLoaded filters questions by MistakeReasonFilter accurately', () {
      const qConcept = MistakeQuestionEntity(
        mistakeId: 'm-1', questionId: 'q-1', questionText: 'Q1',
        questionType: 'multiple_choice', points: 5, sortOrder: 1,
        isResolved: false, failureCount: 1, sourceExamId: 'e-1',
        sourceExamTitle: 'SAT', reflectionReason: 'concept_gap', options: [],
      );

      const qCareless = MistakeQuestionEntity(
        mistakeId: 'm-2', questionId: 'q-2', questionText: 'Q2',
        questionType: 'multiple_choice', points: 5, sortOrder: 2,
        isResolved: false, failureCount: 1, sourceExamId: 'e-1',
        sourceExamTitle: 'SAT', reflectionReason: 'careless_error', options: [],
      );

      const qUnclassified = MistakeQuestionEntity(
        mistakeId: 'm-3', questionId: 'q-3', questionText: 'Q3',
        questionType: 'multiple_choice', points: 5, sortOrder: 3,
        isResolved: false, failureCount: 1, sourceExamId: 'e-1',
        sourceExamTitle: 'SAT', reflectionReason: null, options: [],
      );

      const baseState = MistakesLoaded(
        summary: MistakeSummaryEntity(
          totalMistakes: 3,
          unresolvedCount: 3,
          resolvedCount: 0,
          conceptGapCount: 1,
          carelessErrorCount: 1,
          sources: [],
        ),
        questions: [qConcept, qCareless, qUnclassified],
        reasonFilter: MistakeReasonFilter.all,
      );

      expect(baseState.filteredQuestions.length, equals(3));

      final conceptState = baseState.copyWith(reasonFilter: MistakeReasonFilter.conceptGap);
      expect(conceptState.filteredQuestions.length, equals(1));
      expect(conceptState.filteredQuestions.first.questionId, equals('q-1'));

      final carelessState = baseState.copyWith(reasonFilter: MistakeReasonFilter.carelessError);
      expect(carelessState.filteredQuestions.length, equals(1));
      expect(carelessState.filteredQuestions.first.questionId, equals('q-2'));

      final unclassifiedState = baseState.copyWith(reasonFilter: MistakeReasonFilter.unclassified);
      expect(unclassifiedState.filteredQuestions.length, equals(1));
      expect(unclassifiedState.filteredQuestions.first.questionId, equals('q-3'));
    });

    test('MistakesCubit updateReflection optimistically updates state and calls repository', () async {
      final fakeRepo = _FakeExamsRepositoryForMistakes();
      final cubit = MistakesCubit(repository: fakeRepo);

      const q = MistakeQuestionEntity(
        mistakeId: 'm-100',
        questionId: 'q-100',
        questionText: 'What is 5!',
        questionType: 'multiple_choice',
        points: 5,
        sortOrder: 1,
        isResolved: false,
        failureCount: 1,
        sourceExamId: 'e-1',
        sourceExamTitle: 'Math',
        reflectionReason: null,
        options: [],
      );

      cubit.emit(const MistakesLoaded(
        summary: MistakeSummaryEntity(
          totalMistakes: 1,
          unresolvedCount: 1,
          resolvedCount: 0,
          sources: [],
        ),
        questions: [q],
      ));

      await cubit.updateReflection(mistakeId: 'm-100', reason: 'time_pressure');

      expect(fakeRepo.lastUpdatedMistakeId, equals('m-100'));
      expect(fakeRepo.lastUpdatedReason, equals('time_pressure'));

      final state = cubit.state as MistakesLoaded;
      expect(state.questions.first.reflectionReason, equals('time_pressure'));
      expect(state.summary.timePressureCount, equals(1));
    });

    test('ExamAttemptEntity retains questionTimes and flaggedGuesses correctly', () {
      final attempt = ExamAttemptEntity(
        id: 'attempt-1',
        examId: 'e-1',
        examVersionId: 'ver-1',
        studentId: 'stud-1',
        startedAt: DateTime.now(),
        score: 85,
        percentage: 85.0,
        submittedAt: DateTime.now(),
        questionTimes: const {'q-1': 45, 'q-2': 110, 'q-3': 25},
        flaggedGuesses: const {'q-2'},
      );

      expect(attempt.questionTimes['q-1'], equals(45));
      expect(attempt.questionTimes['q-2'], equals(110));
      expect(attempt.flaggedGuesses.contains('q-2'), isTrue);
      expect(attempt.flaggedGuesses.contains('q-1'), isFalse);
    });
  });
}
