import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/error_mapper.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/core/widgets/app_error_view.dart';

Widget buildTestableWidget(Widget child, {Locale locale = const Locale('ar')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('AppErrorView Tests', () {
    testWidgets('renders full view with title, message, and hint', (tester) async {
      final error = ErrorMapper.resolve(
        const NetworkFailure('Network connection error', code: 'NET_OFFLINE'),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          AppErrorView(
            error: error,
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should display localized Arabic offline title
      expect(find.text('لا يوجد اتصال بالإنترنت'), findsOneWidget);
      // Should display guidance box
      expect(find.text('ما يمكنك فعله:'), findsOneWidget);
      // Should display retry button
      expect(find.byType(AppButton), findsOneWidget);
      // Should display error code badge
      expect(find.textContaining('NET_OFFLINE'), findsOneWidget);
    });

    testWidgets('renders compact view correctly', (tester) async {
      final error = ErrorMapper.resolve(
        const VideoNotReadyFailure('Transcoding video', code: 'VID_001'),
      );

      await tester.pumpWidget(
        buildTestableWidget(
          AppErrorView(
            error: error,
            isCompact: true,
            onRetry: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الفيديو قيد المعالجة'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('triggers secondary action button when provided', (tester) async {
      var secondaryTriggered = false;

      await tester.pumpWidget(
        buildTestableWidget(
          AppErrorView(
            error: const SessionExpiredFailure('Session has expired'),
            onSecondaryAction: () => secondaryTriggered = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find secondary button (تسجيل الدخول مجدداً)
      final buttons = find.byType(AppButton);
      expect(buttons, findsOneWidget);

      await tester.tap(buttons.first);
      await tester.pump();

      expect(secondaryTriggered, isTrue);
    });
  });
}
