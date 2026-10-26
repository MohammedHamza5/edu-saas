import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/exams/domain/entities/mistake_entities.dart';
import 'package:edu_saas/features/exams/presentation/cubit/mistakes_state.dart';
import 'package:edu_saas/features/exams/presentation/widgets/mistake_sort_bar.dart';
import 'package:edu_saas/features/exams/presentation/widgets/zero_mistake_gauntlet_card.dart';
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
  group('Pillar 3: Zero-Mistake Gauntlet Multi-Device Responsive UI Tests', () {
    const widths = <String, double>{
      'Narrow Mobile (300px)': 300,
      'Standard Mobile (360px)': 360,
      'Tablet (768px)': 768,
      'Desktop (1440px)': 1440,
    };

    const q1 = MistakeQuestionEntity(
      mistakeId: 'm1', questionId: 'q1', questionText: 'Q1', questionType: 'multiple_choice',
      points: 2, sortOrder: 1, isResolved: false, failureCount: 3,
      sourceExamId: 'ex1', sourceExamTitle: 'Exam 1', options: [],
    );
    const q2 = MistakeQuestionEntity(
      mistakeId: 'm2', questionId: 'q2', questionText: 'Q2', questionType: 'multiple_choice',
      points: 4, sortOrder: 2, isResolved: true, failureCount: 1,
      sourceExamId: 'ex1', sourceExamTitle: 'Exam 1', options: [],
    );

    const testState = MistakesLoaded(
      summary: MistakeSummaryEntity(totalMistakes: 2, unresolvedCount: 1, resolvedCount: 1, sources: []),
      questions: [q1, q2],
      statusFilter: MistakeStatusFilter.all,
      sortOrder: MistakeSortOrder.defaultOrder,
    );

    for (final entry in widths.entries) {
      testWidgets('Renders ZeroMistakeGauntletCard on ${entry.key} without overflow', (tester) async {
        await tester.pumpWidget(
          _buildWrapper(
            child: SizedBox(
              width: entry.value,
              child: const ZeroMistakeGauntletCard(state: testState),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ZeroMistakeGauntletCard), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('Renders MistakeSortBar on ${entry.key} without overflow', (tester) async {
        MistakeSortOrder active = MistakeSortOrder.defaultOrder;
        await tester.pumpWidget(
          _buildWrapper(
            child: SizedBox(
              width: entry.value,
              child: MistakeSortBar(
                activeSort: active,
                onSortChanged: (s) => active = s,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(MistakeSortBar), findsOneWidget);
      });
    }

    testWidgets('MistakeSortBar chip tap invokes callback with correct sort order', (tester) async {
      MistakeSortOrder selected = MistakeSortOrder.defaultOrder;
      await tester.pumpWidget(
        _buildWrapper(
          child: MistakeSortBar(
            activeSort: selected,
            onSortChanged: (s) => selected = s,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mostFailedChip = find.byType(FilterChip).at(1);
      await tester.tap(mostFailedChip);
      await tester.pumpAndSettle();

      expect(selected, MistakeSortOrder.mostFailed);
    });

    testWidgets('ZeroMistakeGauntletCard hides when all mistakes are resolved (0 unresolved)', (tester) async {
      const masteredState = MistakesLoaded(
        summary: MistakeSummaryEntity(totalMistakes: 1, unresolvedCount: 0, resolvedCount: 1, sources: []),
        questions: [q2],
        statusFilter: MistakeStatusFilter.all,
      );

      await tester.pumpWidget(
        _buildWrapper(
          child: const ZeroMistakeGauntletCard(state: masteredState),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // When 0 unresolved mistakes, card gracefully collapses
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('Renders ZeroMistakeGauntletCard with partial mastery cleanly', (tester) async {
      const partialState = MistakesLoaded(
        summary: MistakeSummaryEntity(totalMistakes: 2, unresolvedCount: 1, resolvedCount: 1, sources: []),
        questions: [q1, q2],
        statusFilter: MistakeStatusFilter.all,
      );

      await tester.pumpWidget(
        _buildWrapper(
          child: const ZeroMistakeGauntletCard(state: partialState),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(ZeroMistakeGauntletCard), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });
  });
}
