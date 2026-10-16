import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/exams/presentation/widgets/floating_desmos_calculator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _createTestWidget(Widget child) {
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
    home: Scaffold(
      body: Stack(
        children: [child],
      ),
    ),
  );
}

void main() {
  group('FloatingDesmosCalculator Widget Tests', () {
    testWidgets('renders Desmos calculator in graphing mode by default', (tester) async {
      bool closed = false;

      await tester.pumpWidget(
        _createTestWidget(
          FloatingDesmosCalculator(
            onClose: () => closed = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title for graphing mode
      expect(find.text('Desmos Graphing Calculator'), findsOneWidget);
      expect(find.text('Graphing'), findsOneWidget);
      expect(find.text('Scientific'), findsOneWidget);

      // Verify close button triggers callback
      final closeButton = find.byIcon(Icons.close_rounded);
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      expect(closed, isTrue);
    });

    testWidgets('switching to scientific mode updates title and mode', (tester) async {
      await tester.pumpWidget(
        _createTestWidget(
          FloatingDesmosCalculator(
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Scientific mode
      await tester.tap(find.text('Scientific'));
      await tester.pumpAndSettle();

      expect(find.text('Desmos Scientific Calculator'), findsOneWidget);
    });

    testWidgets('minimize button collapses calculator and expand restores it', (tester) async {
      await tester.pumpWidget(
        _createTestWidget(
          FloatingDesmosCalculator(
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap minimize icon
      final minimizeIcon = find.byIcon(Icons.unfold_less_rounded);
      expect(minimizeIcon, findsOneWidget);
      await tester.tap(minimizeIcon);
      await tester.pumpAndSettle();

      // In minimized state, mode switcher buttons are hidden
      expect(find.text('Graphing'), findsNothing);
      expect(find.text('Scientific'), findsNothing);

      // Tap expand icon to restore
      final expandIcon = find.byIcon(Icons.unfold_more_rounded);
      expect(expandIcon, findsOneWidget);
      await tester.tap(expandIcon);
      await tester.pumpAndSettle();

      // Mode switcher buttons restored
      expect(find.text('Graphing'), findsOneWidget);
      expect(find.text('Scientific'), findsOneWidget);
    });

    testWidgets('maximize button toggles full-screen size and restore restores normal size', (tester) async {
      await tester.pumpWidget(
        _createTestWidget(
          FloatingDesmosCalculator(
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Maximize icon
      final maximizeIcon = find.byIcon(Icons.fullscreen_rounded);
      expect(maximizeIcon, findsOneWidget);
      await tester.tap(maximizeIcon);
      await tester.pumpAndSettle();

      // Now should show fullscreen exit icon
      final restoreIcon = find.byIcon(Icons.fullscreen_exit_rounded);
      expect(restoreIcon, findsOneWidget);
      await tester.tap(restoreIcon);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
    });

    testWidgets('isVisible false sets Offstage offstage to true preserving DOM', (tester) async {
      await tester.pumpWidget(
        _createTestWidget(
          FloatingDesmosCalculator(
            isVisible: false,
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final offstage = tester.widget<Offstage>(
        find
            .descendant(
              of: find.byType(FloatingDesmosCalculator),
              matching: find.byType(Offstage),
            )
            .first,
      );
      expect(offstage.offstage, isTrue);
    });

    testWidgets('dragging header updates position smoothly', (tester) async {
      await tester.pumpWidget(
        _createTestWidget(
          FloatingDesmosCalculator(
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dragHandle = find.byIcon(Icons.drag_indicator_rounded);
      expect(dragHandle, findsOneWidget);

      await tester.drag(dragHandle, const Offset(-100, 50));
      await tester.pumpAndSettle();
    });

    testWidgets(
      'renders cleanly and maximizes on small screens (<380px) without ArgumentError (FLUTTER-8/9)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          _createTestWidget(
            FloatingDesmosCalculator(
              onClose: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final maximizeBtn = find.byIcon(Icons.fullscreen_rounded);
        expect(maximizeBtn, findsOneWidget);
        await tester.tap(maximizeBtn);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
