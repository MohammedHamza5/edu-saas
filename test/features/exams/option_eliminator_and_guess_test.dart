import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/exams_state.dart';
import 'package:edu_saas/features/exams/presentation/widgets/question_option_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeRepoForTactics implements ExamsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapTile({required Widget child, double width = 360}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ar'), Locale('en')],
    locale: const Locale('ar'),
    home: Scaffold(
      body: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  const sampleOption = QuestionOptionEntity(
    id: 'opt-x',
    questionId: 'q-1',
    optionText: 'x = (-b ± √(b² - 4ac)) / 2a (صيغة القانون العام لحل المعادلة التربيعية)',
    isCorrect: false,
  );

  group('QuestionOptionTile Option Eliminator & Multi-Device UI Tests', () {
    const testWidths = <String, double>{
      'Narrow Mobile (300px)': 300,
      'Standard Mobile (360px)': 360,
      'Tablet (768px)': 768,
    };

    for (final entry in testWidths.entries) {
      testWidgets('Renders QuestionOptionTile on ${entry.key} without overflow', (tester) async {
        await tester.pumpWidget(
          _wrapTile(
            width: entry.value,
            child: const QuestionOptionTile(
              option: sampleOption,
              index: 0,
              isEliminated: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(QuestionOptionTile), findsOneWidget);
      });
    }

    testWidgets('Tapping eliminate button fires onEliminate callback', (tester) async {
      bool eliminatedTapped = false;

      await tester.pumpWidget(
        _wrapTile(
          child: QuestionOptionTile(
            option: sampleOption,
            index: 0,
            onEliminate: () => eliminatedTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final eliminateBtn = find.byIcon(Icons.close_rounded);
      expect(eliminateBtn, findsOneWidget);

      await tester.tap(eliminateBtn);
      await tester.pumpAndSettle();

      expect(eliminatedTapped, isTrue);
    });

    testWidgets('isEliminated true renders strikethrough icon and strikethrough decoration', (tester) async {
      await tester.pumpWidget(
        _wrapTile(
          child: const QuestionOptionTile(
            option: sampleOption,
            index: 0,
            isEliminated: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final textWidget = tester.widget<Text>(find.text(sampleOption.optionText));
      expect(textWidget.style?.decoration, equals(TextDecoration.lineThrough));
    });
  });

  group('ExamsCubit Tactical Eliminator & Guess Unit Tests', () {
    late ExamsCubit cubit;
    final now = DateTime.now();

    final testExam = ExamEntity(
      id: 'e1', contentId: 'c1', tenantId: 't1', groupId: 'g1', title: 'Math',
      durationMinutes: 30, maxScore: 50, passingScore: 25,
      createdAt: now, updatedAt: now,
    );

    setUp(() {
      cubit = ExamsCubit(repository: _FakeRepoForTactics());
    });

    tearDown(() {
      cubit.close();
    });

    test('toggleFlagGuess accurately toggles question flag', () {
      const q1 = ExamQuestionEntity(
        id: 'q-1', examVersionId: 'v1', questionText: 'Q1',
        questionType: QuestionType.multipleChoice, points: 5, sortOrder: 0,
        options: [],
      );
      final baseState = ExamTakingState(
        exam: testExam,
        attempt: ExamAttemptEntity(
          id: 'att-1', examId: 'e1', examVersionId: 'v1', studentId: 's1',
          startedAt: now,
        ),
        questions: const [q1],
        currentQuestionIndex: 0,
        remainingSeconds: 1800,
      );

      cubit.emit(baseState);

      // Flag question 1
      cubit.toggleFlagGuess('q-1');
      var state = cubit.state as ExamTakingState;
      expect(state.flaggedGuesses.contains('q-1'), isTrue);
      expect(state.isCurrentQuestionFlaggedAsGuess, isTrue);

      // Unflag question 1
      cubit.toggleFlagGuess('q-1');
      state = cubit.state as ExamTakingState;
      expect(state.flaggedGuesses.contains('q-1'), isFalse);
      expect(state.isCurrentQuestionFlaggedAsGuess, isFalse);
    });

    test('toggleEliminateOption toggles option strike-through in eliminatedOptions', () {
      const q1 = ExamQuestionEntity(
        id: 'q-1', examVersionId: 'v1', questionText: 'Q1',
        questionType: QuestionType.multipleChoice, points: 5, sortOrder: 0,
        options: [],
      );
      final baseState = ExamTakingState(
        exam: testExam,
        attempt: ExamAttemptEntity(
          id: 'att-1', examId: 'e1', examVersionId: 'v1', studentId: 's1',
          startedAt: now,
        ),
        questions: const [q1],
        currentQuestionIndex: 0,
        remainingSeconds: 1800,
      );

      cubit.emit(baseState);

      // Eliminate option A for question 1
      cubit.toggleEliminateOption('q-1', 'opt-a');
      var state = cubit.state as ExamTakingState;
      expect(state.isOptionEliminated('q-1', 'opt-a'), isTrue);
      expect(state.isOptionEliminated('q-1', 'opt-b'), isFalse);

      // Eliminate option B for question 1
      cubit.toggleEliminateOption('q-1', 'opt-b');
      state = cubit.state as ExamTakingState;
      expect(state.isOptionEliminated('q-1', 'opt-a'), isTrue);
      expect(state.isOptionEliminated('q-1', 'opt-b'), isTrue);

      // Un-eliminate option A
      cubit.toggleEliminateOption('q-1', 'opt-a');
      state = cubit.state as ExamTakingState;
      expect(state.isOptionEliminated('q-1', 'opt-a'), isFalse);
      expect(state.isOptionEliminated('q-1', 'opt-b'), isTrue);
    });
  });
}
