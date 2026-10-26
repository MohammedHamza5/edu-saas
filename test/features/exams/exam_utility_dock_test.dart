import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/exams/presentation/widgets/desmos_embed_view.dart';
import 'package:edu_saas/features/exams/presentation/widgets/dock/exam_adaptive_tools_pane.dart';
import 'package:edu_saas/features/exams/presentation/widgets/dock/exam_dock_state.dart';
import 'package:edu_saas/features/exams/presentation/widgets/dock/exam_utility_dock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [
      Locale('en'),
      Locale('ar'),
    ],
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  group('ExamUtilityDock & Adaptive Tools Pane Tests', () {
    testWidgets('renders dock in calculator tab with mode selector and action buttons', (tester) async {
      ExamDockTab activeTab = ExamDockTab.calculator;
      DesmosCalculatorMode desmosMode = DesmosCalculatorMode.graphing;
      bool collapsed = false;
      bool detached = false;

      await tester.pumpWidget(
        _buildTestApp(
          SizedBox(
            width: 440,
            height: 600,
            child: ExamUtilityDock(
              activeTab: activeTab,
              onTabChanged: (t) => activeTab = t,
              desmosMode: desmosMode,
              onDesmosModeChanged: (m) => desmosMode = m,
              onCollapse: () => collapsed = true,
              onDetachToFloat: () => detached = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check tool tabs
      expect(find.text('Calculator'), findsOneWidget);
      expect(find.text('Reference Sheet'), findsOneWidget);

      // Check Desmos modes
      expect(find.text('Graphing'), findsOneWidget);
      expect(find.text('Scientific'), findsOneWidget);

      // Test Detach / Float button
      final detachBtn = find.byIcon(Icons.open_in_new_rounded);
      expect(detachBtn, findsOneWidget);
      await tester.tap(detachBtn);
      expect(detached, isTrue);

      // Test Collapse button
      final collapseBtn = find.byIcon(Icons.close_fullscreen_rounded);
      expect(collapseBtn, findsOneWidget);
      await tester.tap(collapseBtn);
      expect(collapsed, isTrue);
    });

    testWidgets('switching tab to formulas renders formula reference content', (tester) async {
      ExamDockTab activeTab = ExamDockTab.formulas;

      await tester.pumpWidget(
        _buildTestApp(
          SizedBox(
            width: 440,
            height: 600,
            child: ExamUtilityDock(
              activeTab: activeTab,
              onTabChanged: (t) => activeTab = t,
              desmosMode: DesmosCalculatorMode.graphing,
              onDesmosModeChanged: (_) {},
              onCollapse: () {},
              onDetachToFloat: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Formulas tab is visible
      expect(find.text('SAT Formulas'), findsOneWidget);
      expect(find.text('Desmos Hacks'), findsOneWidget);
      expect(find.text('Circles (الدائرة)'), findsOneWidget);
    });

    testWidgets('floating mode renders re-dock button and triggers onReDock', (tester) async {
      bool reDocked = false;

      await tester.pumpWidget(
        _buildTestApp(
          SizedBox(
            width: 440,
            height: 600,
            child: ExamUtilityDock(
              activeTab: ExamDockTab.calculator,
              onTabChanged: (_) {},
              desmosMode: DesmosCalculatorMode.graphing,
              onDesmosModeChanged: (_) {},
              onCollapse: () {},
              onDetachToFloat: () {},
              isFloating: true,
              onReDock: () => reDocked = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final reDockBtn = find.byIcon(Icons.vertical_split_rounded);
      expect(reDockBtn, findsOneWidget);
      await tester.tap(reDockBtn);
      expect(reDocked, isTrue);
    });

    testWidgets('ExamAdaptiveToolsPane renders docked on desktop and hidden offstage smoothly', (tester) async {
      ExamDockMode mode = ExamDockMode.docked;

      await tester.pumpWidget(
        _buildTestApp(
          Stack(
            children: [
              ExamAdaptiveToolsPane(
                dockMode: mode,
                activeTab: ExamDockTab.calculator,
                desmosMode: DesmosCalculatorMode.graphing,
                onDockModeChanged: (m) => mode = m,
                onTabChanged: (_) {},
                onDesmosModeChanged: (_) {},
                dockWidth: 400,
                isDesktop: true,
                parentSize: const Size(1200, 800),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially docked
      expect(find.text('Calculator'), findsOneWidget);
      expect(find.byType(ExamUtilityDock), findsOneWidget);

      // Now switch to hidden mode
      await tester.pumpWidget(
        _buildTestApp(
          Stack(
            children: [
              ExamAdaptiveToolsPane(
                dockMode: ExamDockMode.hidden,
                activeTab: ExamDockTab.calculator,
                desmosMode: DesmosCalculatorMode.graphing,
                onDockModeChanged: (m) => mode = m,
                onTabChanged: (_) {},
                onDesmosModeChanged: (_) {},
                dockWidth: 400,
                isDesktop: true,
                parentSize: const Size(1200, 800),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Preserved offstage!
      final offstageFinder = find.byWidgetPredicate(
        (widget) => widget is Offstage && widget.offstage == true,
      );
      expect(offstageFinder, findsOneWidget);
    });
  });
}
