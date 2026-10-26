import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/domain/repositories/exams_repository.dart';
import 'package:edu_saas/features/exams/presentation/cubit/mistakes_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/mistakes_state.dart';
import 'package:edu_saas/features/exams/presentation/widgets/exam_pacing_radar_card.dart';
import 'package:edu_saas/features/exams/presentation/widgets/mistake_reflection_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeExamsRepo implements ExamsRepository {
  String? updatedReason;

  @override
  Future<Result<bool>> updateMistakeReflection({
    required String mistakeId,
    required String? reflectionReason,
  }) async {
    updatedReason = reflectionReason;
    return const Success(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _buildTestWrapper({
  required Widget child,
  Locale locale = const Locale('ar'),
  MistakesCubit? mistakesCubit,
}) {
  final content = Scaffold(body: SingleChildScrollView(child: child));
  return MaterialApp(
    theme: AppTheme.lightTheme,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ar'), Locale('en')],
    home: mistakesCubit != null
        ? BlocProvider<MistakesCubit>.value(
            value: mistakesCubit,
            child: content,
          )
        : content,
  );
}

void main() {
  const deviceSizes = <String, Size>{
    'Compact Mobile (320x640)': Size(320, 640),
    'Standard Mobile (390x844)': Size(390, 844),
    'iPad Portrait (768x1024)': Size(768, 1024),
    'Desktop Laptop (1440x900)': Size(1440, 900),
  };

  final sampleAttempt = ExamAttemptEntity(
    id: 'att-1', examId: 'exam-1', examVersionId: 'ver-1', studentId: 'stud-1',
    startedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    submittedAt: DateTime.now(), score: 85, percentage: 85.0,
    questionTimes: const {'q-1': 15, 'q-2': 50, 'q-3': 140, 'q-4': 60},
    flaggedGuesses: const {'q-2'},
  );

  const sampleQuestions = [
    ExamQuestionEntity(
      id: 'q-1', examVersionId: 'v1', questionText: 'Q1',
      questionType: QuestionType.multipleChoice, points: 5, sortOrder: 0,
      options: [QuestionOptionEntity(id: 'opt-1', questionId: 'q-1', optionText: 'A', isCorrect: true)],
    ),
    ExamQuestionEntity(
      id: 'q-2', examVersionId: 'v1', questionText: 'Q2',
      questionType: QuestionType.multipleChoice, points: 5, sortOrder: 1,
      options: [QuestionOptionEntity(id: 'opt-2', questionId: 'q-2', optionText: 'B', isCorrect: true)],
    ),
  ];

  const sampleMistake = MistakeQuestionEntity(
    mistakeId: 'm-1', questionId: 'q-1', questionText: 'Evaluate sqrt(64)',
    questionType: 'multiple_choice', points: 5, sortOrder: 1, isResolved: false,
    failureCount: 1, sourceExamId: 'exam-1', sourceExamTitle: 'Algebra',
    reflectionReason: null, options: [],
  );

  group('ExamPacingRadarCard Multi-Device Responsive UI Tests', () {
    for (final entry in deviceSizes.entries) {
      testWidgets('Renders ExamPacingRadarCard on ${entry.key} without overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _buildTestWrapper(
            child: ExamPacingRadarCard(
              questionTimes: sampleAttempt.questionTimes,
              flaggedGuesses: sampleAttempt.flaggedGuesses,
              totalQuestions: sampleQuestions.length,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ExamPacingRadarCard), findsOneWidget);
      });
    }

    testWidgets('Renders in English (LTR) mode with lucky guess badge cleanly', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildTestWrapper(
          locale: const Locale('en'),
          child: ExamPacingRadarCard(
            questionTimes: sampleAttempt.questionTimes,
            flaggedGuesses: sampleAttempt.flaggedGuesses,
            totalQuestions: sampleQuestions.length,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Speed'), findsWidgets);
    });
  });

  group('MistakeReflectionSelector Multi-Device & Interaction Tests', () {
    final selectorWidths = <String, double>{
      'Narrow Mobile (300px)': 300,
      'Standard Mobile (360px)': 360,
      'Tablet / Desktop (768px)': 768,
    };

    for (final entry in selectorWidths.entries) {
      testWidgets('Renders MistakeReflectionSelector on ${entry.key} without overflow', (tester) async {
        final cubit = MistakesCubit(repository: _FakeExamsRepo());
        addTearDown(cubit.close);

        await tester.pumpWidget(
          _buildTestWrapper(
            mistakesCubit: cubit,
            child: SizedBox(
              width: entry.value,
              child: const MistakeReflectionSelector(question: sampleMistake),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MistakeReflectionSelector), findsOneWidget);
      });
    }

    testWidgets('Tapping reflection reason triggers updateReflection', (tester) async {
      final fakeRepo = _FakeExamsRepo();
      final cubit = MistakesCubit(repository: fakeRepo);
      addTearDown(cubit.close);

      cubit.emit(const MistakesLoaded(
        summary: MistakeSummaryEntity(
          totalMistakes: 1,
          unresolvedCount: 1,
          resolvedCount: 0,
          sources: [],
        ),
        questions: [sampleMistake],
      ));

      await tester.pumpWidget(
        _buildTestWrapper(
          mistakesCubit: cubit,
          child: const MistakeReflectionSelector(question: sampleMistake),
        ),
      );
      await tester.pumpAndSettle();

      // Tap first reason option (Concept Gap)
      final firstOption = find.byType(InkWell).first;
      await tester.tap(firstOption);
      await tester.pumpAndSettle();

      expect(fakeRepo.updatedReason, equals('concept_gap'));
    });
  });
}

