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
      'shows AppErrorView on download failure and retries successfully',
      (tester) async {
        var attemptCount = 0;
        final retryCompleter = Completer<void>();

        Future<void> loadLibrary() async {
          attemptCount++;
          if (attemptCount == 1) {
            throw Exception('Failed to fetch script chunk');
          }
          return retryCompleter.future;
        }

        await tester.pumpWidget(
          buildHarness(
            loadLibrary: loadLibrary,
            builder: () => const Text('Recovered Screen'),
          ),
        );
        await tester.pumpAndSettle();

        // Should show AppErrorView
        expect(find.byType(AppErrorView), findsOneWidget);
        expect(find.text('Recovered Screen'), findsNothing);

        // Tap retry
        final retryBtn = find.text('إعادة المحاولة');
        if (retryBtn.evaluate().isNotEmpty) {
          await tester.tap(retryBtn);
        } else {
          // Fallback find button by icon or type
          final anyRetry = find.byType(ElevatedButton);
          if (anyRetry.evaluate().isNotEmpty) {
            await tester.tap(anyRetry.first);
          }
        }
        await tester.pump();

        // Now attemptCount is 2, completer completes
        expect(attemptCount, 2);
        retryCompleter.complete();
        await tester.pumpAndSettle();

        // Target screen is now visible
        expect(find.text('Recovered Screen'), findsOneWidget);
      },
    );
  });
}
