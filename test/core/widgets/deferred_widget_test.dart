import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/widgets/app_error_view.dart';
import 'package:edu_saas/core/widgets/app_loading_view.dart';
import 'package:edu_saas/core/widgets/deferred_widget.dart';

void main() {
  group('DeferredWidget Tests', () {
    Widget buildHarness({
      required Future<void> Function() loadLibrary,
      required Widget Function() builder,
      Widget? placeholder,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: DeferredWidget(
          loadLibrary: loadLibrary,
          builder: builder,
          placeholder: placeholder,
        ),
      );
    }

    testWidgets('shows loading view while loading, then renders child widget', (
      tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        buildHarness(
          loadLibrary: () => completer.future,
          builder: () => const Text('Target Deferred Screen'),
        ),
      );

      // Initially loading
      expect(find.byType(AppLoadingView), findsOneWidget);
      expect(find.text('Target Deferred Screen'), findsNothing);

      // Complete chunk download
      completer.complete();
      await tester.pumpAndSettle();

      // Now target is visible
      expect(find.byType(AppLoadingView), findsNothing);
      expect(find.text('Target Deferred Screen'), findsOneWidget);
    });

    testWidgets('shows custom placeholder if provided while loading', (
      tester,
    ) async {
      final completer = Completer<void>();

      await tester.pumpWidget(
        buildHarness(
          loadLibrary: () => completer.future,
          builder: () => const Text('Target Screen'),
          placeholder: const Text('Custom Shimmer Placeholder'),
        ),
      );

      expect(find.text('Custom Shimmer Placeholder'), findsOneWidget);
      expect(find.text('Target Screen'), findsNothing);

      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('Custom Shimmer Placeholder'), findsNothing);
      expect(find.text('Target Screen'), findsOneWidget);
    });

    testWidgets(
      'recovers silently without showing AppErrorView when initial attempt fails but retry succeeds',
      (tester) async {
        var attemptCount = 0;

        Future<void> loadLibrary() async {
          attemptCount++;
          if (attemptCount == 1) {
            throw Exception('Transient socket error');
          }
        }

        await tester.pumpWidget(
          buildHarness(
            loadLibrary: loadLibrary,
            builder: () => const Text('Silently Recovered Screen'),
          ),
        );

        // Allow retry timer to fire and settle
        await tester.pumpAndSettle(const Duration(milliseconds: 500));

        // User should NEVER see AppErrorView because retry recovered silently
        expect(find.byType(AppErrorView), findsNothing);
        expect(find.text('Silently Recovered Screen'), findsOneWidget);
        expect(attemptCount, 2);
      },
    );

    testWidgets(
      'shows AppErrorView when all 3 retries are exhausted, then recovers on manual retry',
      (tester) async {
        var attemptCount = 0;
        final manualRetryCompleter = Completer<void>();

        Future<void> loadLibrary() async {
          attemptCount++;
          if (attemptCount <= 3) {
            throw Exception('Persistent fetch error');
          }
          return manualRetryCompleter.future;
        }

        await tester.pumpWidget(
          buildHarness(
            loadLibrary: loadLibrary,
            builder: () => const Text('Recovered After Manual Retry'),
          ),
        );

        // Allow all 3 automated retries to elapse with backoff
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // After 3 failed attempts, AppErrorView MUST be displayed
        expect(find.byType(AppErrorView), findsOneWidget);
        expect(find.text('Recovered After Manual Retry'), findsNothing);
        expect(attemptCount, 3);

        // Tap manual retry
        final retryBtn = find.text('إعادة المحاولة');
        if (retryBtn.evaluate().isNotEmpty) {
          await tester.tap(retryBtn);
        } else {
          final anyRetry = find.byType(ElevatedButton);
          if (anyRetry.evaluate().isNotEmpty) {
            await tester.tap(anyRetry.first);
          }
        }
        await tester.pump();

        // Attempt 4 is made, manualRetryCompleter completes
        expect(attemptCount, 4);
        manualRetryCompleter.complete();
        await tester.pumpAndSettle();

        // Target screen is now visible
        expect(find.byType(AppErrorView), findsNothing);
        expect(find.text('Recovered After Manual Retry'), findsOneWidget);
      },
    );
  });
}
