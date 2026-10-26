import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/exams/domain/entities/scratchpad_entity.dart';
import 'package:edu_saas/features/exams/presentation/widgets/exam_formula_sheet_modal.dart';
import 'package:edu_saas/features/exams/presentation/widgets/scratchpad/scratchpad_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildWrapper({
  required Widget child,
  Locale locale = const Locale('ar'),
}) {
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
  group('ScratchpadToolbar Multi-Device UI & Interaction Tests', () {
    const widths = <String, double>{
      'Narrow Mobile (300px)': 300,
      'Standard Mobile (360px)': 360,
      'Tablet / Desktop (768px)': 768,
    };

    for (final entry in widths.entries) {
      testWidgets('Renders ScratchpadToolbar on ${entry.key} without overflow', (tester) async {
        await tester.pumpWidget(
          _buildWrapper(
            child: SizedBox(
              width: entry.value,
              child: ScratchpadToolbar(
                activeTool: DrawingTool.pen,
                activeColor: const Color(0xFF1E293B),
                isGridBackground: false,
                canUndo: true,
                onToolChanged: (_) {},
                onColorChanged: (_) {},
                onToggleBackground: () {},
                onUndo: () {},
                onClear: () {},
                onClose: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ScratchpadToolbar), findsOneWidget);
      });
    }

    testWidgets('Tapping tool buttons fires onToolChanged callback', (tester) async {
      DrawingTool? selectedTool;
      Color? selectedColor;
      bool bgToggled = false;

      await tester.pumpWidget(
        _buildWrapper(
          child: ScratchpadToolbar(
            activeTool: DrawingTool.pen,
            activeColor: const Color(0xFF1E293B),
            isGridBackground: false,
            canUndo: true,
            onToolChanged: (t) => selectedTool = t,
            onColorChanged: (c) => selectedColor = c,
            onToggleBackground: () => bgToggled = true,
            onUndo: () {},
            onClear: () {},
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap highlighter tool
      await tester.tap(find.byIcon(Icons.brush_outlined));
      await tester.pumpAndSettle();
      expect(selectedTool, equals(DrawingTool.highlighter));

      // Tap grid toggle button
      await tester.tap(find.byIcon(Icons.layers_clear_outlined));
      await tester.pumpAndSettle();
      expect(bgToggled, isTrue);

      // Tap blue color circle
      final colorInkWells = find.byType(InkWell);
      if (colorInkWells.evaluate().length > 3) {
        await tester.tap(colorInkWells.at(3));
        await tester.pumpAndSettle();
        expect(selectedColor, isNotNull);
      }
    });
  });

  group('ExamFormulaSheetModal Multi-Device Responsive UI Tests', () {
    const deviceSizes = <String, Size>{
      'Compact Mobile (320x640)': Size(320, 640),
      'Standard Mobile (390x844)': Size(390, 844),
      'iPad Portrait (768x1024)': Size(768, 1024),
      'Desktop Laptop (1440x900)': Size(1440, 900),
    };

    for (final entry in deviceSizes.entries) {
      testWidgets('Renders ExamFormulaSheetModal on ${entry.key} without overflow', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_buildWrapper(child: const ExamFormulaSheetModal()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ExamFormulaSheetModal), findsOneWidget);
        expect(find.textContaining('Circles'), findsOneWidget);
      });
    }

    testWidgets('Switching tabs to Desmos Hacks renders tips cleanly in LTR English', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _buildWrapper(
          locale: const Locale('en'),
          child: const ExamFormulaSheetModal(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Desmos Tab
      await tester.tap(find.byIcon(Icons.calculate_outlined));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Linear Regression'), findsOneWidget);
    });
  });
}
