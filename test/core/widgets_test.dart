import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/widgets/app_badge.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/core/widgets/app_card.dart';
import 'package:edu_saas/core/widgets/app_empty_view.dart';
import 'package:edu_saas/core/widgets/app_error_view.dart';
import 'package:edu_saas/core/widgets/app_loading_view.dart';
import 'package:edu_saas/core/widgets/app_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('Design System Widgets Test', () {
    testWidgets('AppButton triggers callback and handles loading state', (tester) async {
      var clicked = false;
      await tester.pumpWidget(
        createTestWidget(
          AppButton(
            text: 'Submit',
            onPressed: () => clicked = true,
          ),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
      await tester.tap(find.text('Submit'));
      expect(clicked, true);
      await tester.pump(const Duration(milliseconds: 600));

      // Loading state
      await tester.pumpWidget(
        createTestWidget(
          AppButton(
            text: 'Submit',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(AppLoadingView), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('AppTextField toggles password visibility', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const AppTextField(
            isPassword: true,
            labelText: 'Password',
          ),
        ),
      );

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('AppCard renders title and child content', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const AppCard(
            title: 'Card Header',
            child: Text('Card Content'),
          ),
        ),
      );

      expect(find.text('Card Header'), findsOneWidget);
      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('AppBadge renders correct label', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const AppBadge(
            label: 'Active',
            variant: AppBadgeVariant.active,
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('AppErrorView renders message and triggers retry', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        createTestWidget(
          AppErrorView(
            message: 'Failed to connect',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Failed to connect'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(retried, true);
      await tester.pump(const Duration(milliseconds: 600));
    });

    testWidgets('AppEmptyView renders message', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const AppEmptyView(
            message: 'No items found',
          ),
        ),
      );

      expect(find.text('No items found'), findsOneWidget);
    });

    testWidgets('AppLoadingView renders spinner and skeleton styles cleanly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const AppLoadingView(message: 'Please wait...'),
        ),
      );
      expect(find.text('Please wait...'), findsOneWidget);

      await tester.pumpWidget(
        createTestWidget(
          const AppLoadingView(style: AppLoadingStyle.skeletonCard),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AppButton provides click cursor when enabled and basic when disabled', (tester) async {
      // Enabled button -> SystemMouseCursors.click
      await tester.pumpWidget(
        createTestWidget(
          AppButton(
            text: 'Save',
            onPressed: () {},
          ),
        ),
      );

      final enabledMouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: find.byType(AppButton), matching: find.byType(MouseRegion)),
      );
      expect(enabledMouseRegion.cursor, SystemMouseCursors.click);

      // Disabled button (onPressed: null) -> SystemMouseCursors.basic
      await tester.pumpWidget(
        createTestWidget(
          const AppButton(
            text: 'Save',
            onPressed: null,
          ),
        ),
      );

      final disabledMouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: find.byType(AppButton), matching: find.byType(MouseRegion)),
      );
      expect(disabledMouseRegion.cursor, SystemMouseCursors.basic);
    });

    testWidgets('AppCard provides click cursor when onTap is set, defers cursor when null', (tester) async {
      // Clickable card -> SystemMouseCursors.click
      await tester.pumpWidget(
        createTestWidget(
          AppCard(
            onTap: () {},
            child: const Text('Interactive Card'),
          ),
        ),
      );

      final clickableMouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: find.byType(AppCard), matching: find.byType(MouseRegion)).first,
      );
      expect(clickableMouseRegion.cursor, SystemMouseCursors.click);

      // Non-clickable card -> MouseCursor.defer (to allow child buttons/inputs to handle cursors)
      await tester.pumpWidget(
        createTestWidget(
          const AppCard(
            child: Text('Static Card'),
          ),
        ),
      );

      final staticMouseRegion = tester.widget<MouseRegion>(
        find.descendant(of: find.byType(AppCard), matching: find.byType(MouseRegion)).first,
      );
      expect(staticMouseRegion.cursor, MouseCursor.defer);
    });
  });
}
