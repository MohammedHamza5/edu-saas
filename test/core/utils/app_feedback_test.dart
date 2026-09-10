import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/utils/app_feedback.dart';

Widget buildTestScaffold(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('AppFeedback Tests', () {
    testWidgets('showError displays floating snackbar with error info', (tester) async {
      await tester.pumpWidget(
        buildTestScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppFeedback.showError(
                  context,
                  const NetworkFailure('Failed to connect'),
                );
              },
              child: const Text('Trigger Error'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Error'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('showSuccess displays green success snackbar', (tester) async {
      await tester.pumpWidget(
        buildTestScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppFeedback.showSuccess(
                  context,
                  'Operation completed successfully',
                );
              },
              child: const Text('Trigger Success'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Success'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Operation completed successfully'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('showWarning displays amber warning snackbar', (tester) async {
      await tester.pumpWidget(
        buildTestScaffold(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                AppFeedback.showWarning(
                  context,
                  'Warning notice details',
                );
              },
              child: const Text('Trigger Warning'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Warning'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Warning notice details'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
