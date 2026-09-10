import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/widgets/app_logo.dart';
import 'package:edu_saas/core/widgets/math_background.dart';
import 'package:edu_saas/core/widgets/math_loading_indicator.dart';
import 'package:edu_saas/core/widgets/app_loading_view.dart';

void main() {
  group('Aesthetic Design Widgets Tests', () {
    testWidgets('AppLogo renders without error (icon only)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: AppLogo(size: 80),
            ),
          ),
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('AppLogo renders platform name when showName is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: AppLogo(
                size: 90,
                showName: true,
                platformName: 'EduSaaS Math',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(AppLogo), findsOneWidget);
      expect(find.text('EduSaaS Math'), findsOneWidget);
    });

    testWidgets('MathBackground paints grid and symbols without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: MathBackground(),
          ),
        ),
      );

      expect(find.byType(MathBackground), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(MathBackground),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('MathLoadingIndicator renders and animates curve with tracer dot', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: MathLoadingIndicator(
              size: 100,
              message: 'جاري التحميل الأكاديمي...',
            ),
          ),
        ),
      );

      expect(find.byType(MathLoadingIndicator), findsOneWidget);
      expect(find.text('جاري التحميل الأكاديمي...'), findsOneWidget);

      // Advance animation timer
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('AppLoadingView supports mathCurve style seamlessly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: AppLoadingView(
              style: AppLoadingStyle.mathCurve,
              message: 'جاري معالجة البيانات...',
            ),
          ),
        ),
      );

      expect(find.byType(AppLoadingView), findsOneWidget);
      expect(find.byType(MathLoadingIndicator), findsOneWidget);
      expect(find.text('جاري معالجة البيانات...'), findsOneWidget);
    });
  });
}
