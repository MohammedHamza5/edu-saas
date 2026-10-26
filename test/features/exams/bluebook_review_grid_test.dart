import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/features/exams/presentation/widgets/bluebook/bluebook_question_cell.dart';
import 'package:edu_saas/features/exams/presentation/widgets/bluebook/bluebook_review_grid_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildWrapper({required Widget child, Locale locale = const Locale('ar')}) {
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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('Bluebook Question Cell & Review Grid Matrix Tests', () {
    testWidgets('BluebookQuestionCell renders correct status and handles tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        _buildWrapper(
          child: BluebookQuestionCell(
            index: 4,
            isCurrent: true,
            isAnswered: true,
            isFlagged: true,
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
      expect(find.byIcon(Icons.flag_rounded), findsOneWidget);

      await tester.tap(find.byType(BluebookQuestionCell));
      expect(tapped, isTrue);
    });

    testWidgets('BluebookReviewGridModal renders matrix and selects question', (tester) async {
      int? selectedQuestion;

      await tester.pumpWidget(
        _buildWrapper(
          child: BluebookReviewGridModal(
            totalQuestions: 10,
            currentQuestionIndex: 2,
            answeredIndices: const {0, 1, 2},
            flaggedIndices: const {1},
            onQuestionSelected: (idx) => selectedQuestion = idx,
            onConfirmFinish: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 1; i <= 10; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      await tester.tap(find.text('7'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(selectedQuestion, equals(6));
    });

    testWidgets('BluebookReviewGridModal alerts on unanswered questions before submit', (tester) async {
      bool submitted = false;

      await tester.pumpWidget(
        _buildWrapper(
          child: BluebookReviewGridModal(
            totalQuestions: 5,
            currentQuestionIndex: 0,
            answeredIndices: const {0, 1},
            flaggedIndices: const {},
            onQuestionSelected: (_) {},
            onConfirmFinish: () => submitted = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap finish button -> shows warning AlertDialog because 3 questions are unanswered
      await tester.tap(find.byType(AppButton).first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(submitted, isFalse);
    });

    for (final entry in {
      'Narrow Mobile (300px)': const Size(300, 600),
      'Standard Mobile (360px)': const Size(360, 740),
      'Tablet (768px)': const Size(768, 1024),
      'Desktop (1440px)': const Size(1440, 900),
    }.entries) {
      testWidgets('BluebookReviewGridModal renders without overflow on ${entry.key}', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _buildWrapper(
            child: BluebookReviewGridModal(
              totalQuestions: 22,
              currentQuestionIndex: 0,
              answeredIndices: const {0, 1, 2, 3, 4},
              flaggedIndices: const {2},
              onQuestionSelected: (_) {},
              onConfirmFinish: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(BluebookReviewGridModal), findsOneWidget);
      });
    }
  });
}
