import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/saved_question_entity.dart';
import 'package:edu_saas/features/exams/domain/repositories/saved_questions_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/saved_questions_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/saved_questions_state.dart';
import 'package:edu_saas/features/exams/presentation/cubit/anki_drill_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/anki_drill_state.dart';

class _FakeSavedQuestionsRepo implements SavedQuestionsRepository {
  final Map<String, SavedQuestionEntity> _storage = {};

  @override
  Future<Result<List<SavedQuestionEntity>>> getSavedQuestions() async {
    return Result.success(_storage.values.toList());
  }

  @override
  Future<Result<bool>> isQuestionSaved(String questionId) async {
    return Result.success(_storage.containsKey(questionId));
  }

  @override
  Future<Result<bool>> removeSavedQuestion(String questionId) async {
    _storage.remove(questionId);
    return const Result.success(true);
  }

  @override
  Future<Result<SavedQuestionEntity>> saveQuestion(SavedQuestionEntity question) async {
    _storage[question.questionId] = question;
    return Result.success(question);
  }

  @override
  Future<Result<SavedQuestionEntity>> updateDifficultyRating({
    required String questionId,
    required QuestionDifficultyRating rating,
    bool? isMastered,
  }) async {
    final existing = _storage[questionId];
    if (existing != null) {
      final now = DateTime.now();
      final interval = rating.intervalDays;
      final masteredVal = isMastered ?? (rating == QuestionDifficultyRating.easy);
      final updated = existing.copyWith(
        difficultyRating: rating,
        reviewCount: existing.reviewCount + 1,
        lastReviewedAt: now,
        intervalDays: interval,
        isMastered: masteredVal,
        nextReviewAt: masteredVal ? null : now.add(Duration(days: interval)),
        clearNextReviewAt: masteredVal,
      );
      _storage[questionId] = updated;
      return Result.success(updated);
    }
    return const Result.failure(ServerFailure('Not found'));
  }

  @override
  Future<Result<SavedQuestionEntity>> updatePersonalNote({
    required String questionId,
    required String? note,
  }) async {
    final existing = _storage[questionId];
    if (existing != null) {
      final updated = existing.copyWith(personalNote: note);
      _storage[questionId] = updated;
      return Result.success(updated);
    }
    return const Result.failure(ServerFailure('Not found'));
  }

  @override
  Future<Result<SavedQuestionEntity>> markMastered({
    required String questionId,
    required bool isMastered,
  }) async {
    final existing = _storage[questionId];
    if (existing != null) {
      final updated = existing.copyWith(
        isMastered: isMastered,
        clearNextReviewAt: isMastered,
        nextReviewAt: isMastered ? null : (existing.nextReviewAt ?? DateTime.now()),
        difficultyRating: isMastered ? QuestionDifficultyRating.easy : existing.difficultyRating,
      );
      _storage[questionId] = updated;
      return Result.success(updated);
    }
    return const Result.failure(ServerFailure('Not found'));
  }
}

void main() {
  group('Student Super-Arsenal: Saved Questions & Spaced Repetition Tests', () {
    late _FakeSavedQuestionsRepo repo;
    late SavedQuestionsCubit savedCubit;
    late AnkiDrillCubit ankiCubit;

    const optA = QuestionOptionEntity(id: 'opt1', questionId: 'q1', optionText: '42', sortOrder: 0, isCorrect: true);
    const optB = QuestionOptionEntity(id: 'opt2', questionId: 'q1', optionText: '24', sortOrder: 1, isCorrect: false);

    final q1 = SavedQuestionEntity(
      id: 'sq1',
      questionId: 'q1',
      examId: 'ex1',
      examTitle: 'SAT Math Test 1',
      questionText: 'Solve for x: 2x + 10 = 94',
      options: const [optA, optB],
      savedAt: DateTime(2026, 10, 1),
    );

    final q2 = SavedQuestionEntity(
      id: 'sq2',
      questionId: 'q2',
      examId: 'ex1',
      examTitle: 'SAT Math Test 1',
      questionText: 'What is the slope of line 3x - 4y = 12?',
      options: const [optA, optB],
      difficultyRating: QuestionDifficultyRating.hard,
      savedAt: DateTime(2026, 10, 2),
    );

    setUp(() {
      repo = _FakeSavedQuestionsRepo();
      savedCubit = SavedQuestionsCubit(repository: repo);
      ankiCubit = AnkiDrillCubit(repository: repo);
    });

    test('QuestionDifficultyRating: returns exact 1, 3, 6 days Leitner intervals', () {
      expect(QuestionDifficultyRating.hard.intervalDays, equals(1));
      expect(QuestionDifficultyRating.medium.intervalDays, equals(3));
      expect(QuestionDifficultyRating.easy.intervalDays, equals(6));
    });

    test('SavedQuestionEntity: correctly checks isDueToday and daysUntilReview', () {
      final now = DateTime.now();
      final dueQ = q1.copyWith(nextReviewAt: now.subtract(const Duration(hours: 2)));
      final upcomingQ = q1.copyWith(nextReviewAt: now.add(const Duration(days: 3)));
      final masteredQ = q1.copyWith(isMastered: true);

      expect(dueQ.isDueToday, isTrue);
      expect(upcomingQ.isDueToday, isFalse);
      expect(upcomingQ.daysUntilReview, inInclusiveRange(2, 3));
      expect(masteredQ.isDueToday, isFalse);
    });

    test('SavedQuestionsCubit: loads empty when no questions in vault', () async {
      await savedCubit.loadSavedQuestions();
      expect(savedCubit.state, isA<SavedQuestionsEmpty>());
    });

    test('SavedQuestionsCubit: saves, loads, filters by difficulty, and searches', () async {
      await repo.saveQuestion(q1);
      await repo.saveQuestion(q2);

      await savedCubit.loadSavedQuestions();
      expect(savedCubit.state, isA<SavedQuestionsLoaded>());

      final loaded = savedCubit.state as SavedQuestionsLoaded;
      expect(loaded.questions.length, equals(2));
      expect(loaded.hardCount, equals(1));
      expect(loaded.easyCount, equals(0));

      savedCubit.filterByDifficulty(QuestionDifficultyRating.hard);
      final filteredState = savedCubit.state as SavedQuestionsLoaded;
      expect(filteredState.filteredQuestions.length, equals(1));
      expect(filteredState.filteredQuestions.first.questionId, equals('q2'));

      savedCubit.searchQuestions('slope');
      final searchState = savedCubit.state as SavedQuestionsLoaded;
      expect(searchState.filteredQuestions.length, equals(1));
      expect(searchState.filteredQuestions.first.questionId, equals('q2'));

      await savedCubit.updateNote('q1', 'Remember standard slope-intercept form!');
      expect(repo._storage['q1']?.personalNote, contains('slope-intercept'));

      await savedCubit.removeQuestion('q2');
      expect(repo._storage.containsKey('q2'), isFalse);
    });

    test('Spaced Repetition: rating questions updates nextReviewAt by 1, 3, or 6 days', () async {
      await repo.saveQuestion(q1);
      await savedCubit.loadSavedQuestions();

      // Rate q1 as HARD -> interval 1 day
      await savedCubit.updateDifficulty('q1', QuestionDifficultyRating.hard);
      var state = savedCubit.state as SavedQuestionsLoaded;
      var q = state.questions.first;
      expect(q.difficultyRating, equals(QuestionDifficultyRating.hard));
      expect(q.intervalDays, equals(1));
      expect(q.nextReviewAt, isNotNull);
      expect(q.nextReviewAt!.isAfter(DateTime.now()), isTrue);
      expect(state.box1Count, equals(1));

      // Rate q1 as MEDIUM -> interval 3 days
      await savedCubit.updateDifficulty('q1', QuestionDifficultyRating.medium);
      state = savedCubit.state as SavedQuestionsLoaded;
      q = state.questions.first;
      expect(q.difficultyRating, equals(QuestionDifficultyRating.medium));
      expect(q.intervalDays, equals(3));
      expect(state.box2Count, equals(1));

      // Rate q1 as EASY -> interval 6 days
      await savedCubit.updateDifficulty('q1', QuestionDifficultyRating.easy, isMastered: false);
      state = savedCubit.state as SavedQuestionsLoaded;
      q = state.questions.first;
      expect(q.difficultyRating, equals(QuestionDifficultyRating.easy));
      expect(q.intervalDays, equals(6));
      expect(state.box3Count, equals(1));
    });

    test('AnkiDrillCubit: Active recall drill re-queues HARD questions until mastered', () async {
      ankiCubit.startDrill([q1, q2]);
      expect(ankiCubit.state, isA<AnkiDrillActive>());

      var state = ankiCubit.state as AnkiDrillActive;
      expect(state.currentQuestion.questionId, equals('q1'));
      expect(state.queueLength, equals(2));

      // 1. Student selects answer and reveals
      ankiCubit.selectOption('opt1');
      state = ankiCubit.state as AnkiDrillActive;
      expect(state.selectedOptionId, equals('opt1'));

      ankiCubit.checkAnswer();
      state = ankiCubit.state as AnkiDrillActive;
      expect(state.isRevealed, isTrue);
      expect(state.isCorrect, isTrue);

      // 2. Student rates as Easy -> mastered
      await ankiCubit.rateDifficultyAndAdvance(QuestionDifficultyRating.easy);
      state = ankiCubit.state as AnkiDrillActive;
      expect(state.currentQuestion.questionId, equals('q2'));
      expect(state.queueLength, equals(1));

      // 3. Student answers Q2, checks answer, and rates as HARD -> dynamically appended back to queue!
      ankiCubit.selectOption('opt2');
      ankiCubit.checkAnswer();
      await ankiCubit.rateDifficultyAndAdvance(QuestionDifficultyRating.hard);
      state = ankiCubit.state as AnkiDrillActive;
      expect(state.currentQuestion.questionId, equals('q2')); // Repeats Q2!
      expect(state.repeatedCount, equals(1));

      // 4. Student solves Q2 again, checks answer, and rates as Easy -> completes session!
      ankiCubit.selectOption('opt1');
      ankiCubit.checkAnswer();
      await ankiCubit.rateDifficultyAndAdvance(QuestionDifficultyRating.easy);
      expect(ankiCubit.state, isA<AnkiDrillCompleted>());

      final completed = ankiCubit.state as AnkiDrillCompleted;
      expect(completed.totalReviewed, equals(3));
      expect(completed.masteredCount, equals(2));
      expect(completed.repeatedCount, equals(1));
    });
  });
}
