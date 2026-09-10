import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/router/app_route_observer.dart';
import 'package:edu_saas/core/utils/ui_error_tracker.dart';
import 'package:edu_saas/core/widgets/app_ui_error_widget.dart';

void main() {
  group('UiErrorTracker Tests', () {
    test('Correctly diagnoses RenderFlex vertical overflow', () {
      AppRouteObserver.currentRoute = '/teacher';

      final details = FlutterErrorDetails(
        exception: FlutterError(
          'A RenderFlex overflowed by 42.5 pixels on the bottom.',
        ),
        stack: StackTrace.fromString(
          '#0 package:edu_saas/features/dashboard/presentation/pages/teacher_dashboard_page.dart:120:15 in _TeacherDashboardPageState.build\n'
          '#1 package:flutter/src/widgets/framework.dart:450:12 in ComponentElement.performRebuild',
        ),
        context: ErrorDescription('while laying out a RenderFlex'),
      );

      final report = UiErrorTracker.analyze(details);

      expect(report.isOverflow, true);
      expect(report.overflowPixels, 42.5);
      expect(report.overflowDirection, 'bottom');
      expect(report.category, contains('RenderFlex Overflow'));
      expect(report.activeRoute, '/teacher');
      expect(report.culpritWidget, contains('TeacherDashboardPage'));
      expect(report.fileLocation, contains('teacher_dashboard_page.dart'));
      expect(report.quickSolution, contains('SingleChildScrollView'));

      final box = report.toFormattedConsoleBox();
      expect(box, contains('🚨 [UI ENGINE ERROR DETECTED]'));
      expect(box, contains('42.5px'));
      expect(box, contains('TeacherDashboardPage'));
    });

    test('Correctly diagnoses Null check failure with exact file and line', () {
      AppRouteObserver.currentRoute = '/student/exams';

      final details = FlutterErrorDetails(
        exception: TypeError(), // Null check operator used on a null value
        stack: StackTrace.fromString(
          '#0 package:edu_saas/features/exams/presentation/pages/student_exams_page.dart:88:22 in StudentExamsPage.build\n'
          '#1 package:flutter/src/widgets/framework.dart:500:10 in ComponentElement.performRebuild',
        ),
        context: ErrorDescription('building StudentExamsPage'),
      );

      final report = UiErrorTracker.analyze(details);

      expect(report.isOverflow, false);
      expect(report.culpritWidget, 'StudentExamsPage');
      expect(report.fileLocation, contains('student_exams_page.dart:88:22'));
      expect(report.activeRoute, '/student/exams');
      expect(report.widgetTreePath, contains('StudentExamsPage'));
    });

    testWidgets('AppUiErrorWidget renders developer diagnostic card in test', (tester) async {
      final details = FlutterErrorDetails(
        exception: Exception('Division by zero in formula calculation'),
        stack: StackTrace.fromString(
          '#0 package:edu_saas/core/widgets/academic_hero_banner.dart:45:10 in AcademicHeroBanner.build',
        ),
        context: ErrorDescription('building AcademicHeroBanner'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppUiErrorWidget(details: details),
          ),
        ),
      );

      expect(find.text('UI ERROR'), findsOneWidget);
      expect(find.text('AcademicHeroBanner'), findsOneWidget);
      expect(find.textContaining('academic_hero_banner.dart'), findsOneWidget);
      expect(find.text('View Widget Tree Path'), findsOneWidget);

      // Tap to expand tree
      await tester.tap(find.text('View Widget Tree Path'));
      await tester.pumpAndSettle();

      expect(find.text('Hide Widget Tree'), findsOneWidget);
      expect(find.textContaining('AcademicHeroBanner'), findsWidgets);
    });
  });
}
