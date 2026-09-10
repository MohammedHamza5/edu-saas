import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/utils/whatsapp_report_generator.dart';
import 'package:edu_saas/features/dashboard/presentation/widgets/teacher_action_radar.dart';
import 'package:edu_saas/features/dashboard/presentation/widgets/sat_domain_mastery_card.dart';
import 'package:edu_saas/features/exams/presentation/widgets/sat_exam_tools_sheet.dart';
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import 'package:edu_saas/features/students/domain/entities/student_entity.dart';

void main() {
  group('Dr. Antounios Platform Specialized Widgets Tests', () {
    test('WhatsAppReportGenerator formats message correctly with student stats', () {
      final message = WhatsAppReportGenerator.generateStudentWeeklyReport(
        studentName: 'يوسف أحمد',
        groupName: 'Digital SAT Master (Target 800)',
        attendanceRate: 1.0,
        videoWatchRate: 0.95,
        completedAssignments: 4,
        totalAssignments: 4,
        mockExamScore: 760,
      );

      expect(message, contains('يوسف أحمد'));
      expect(message, contains('د. أنطونيوس أشرف'));
      expect(message, contains('Digital SAT Master (Target 800)'));
      expect(message, contains('100%'));
      expect(message, contains('95%'));
      expect(message, contains('760 / 800'));
    });

    testWidgets('TeacherActionRadar renders 4 action cards and 5 cohorts cleanly', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final dummyStudents = [
        const StudentEntity(
          id: 's-1',
          tenantId: 't-1',
          fullName: 'علي محمود',
          email: 'ali@example.com',
          status: 'active',
        ),
      ];

      final dummyGroups = [
        const GroupEntity(
          id: 'g-1',
          tenantId: 't-1',
          name: 'Digital SAT Master',
          level: 'Grade 11-12',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TeacherActionRadar(
                students: dummyStudents,
                groups: dummyGroups,
                pendingCount: 2,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('رادار المتابعة'), findsOneWidget);
      expect(find.text('مشاهدات الحصة'), findsOneWidget);
      expect(find.text('تسليم الـ Drill'), findsOneWidget);
      expect(find.text('إنذار السكور'), findsOneWidget);
      expect(find.text('طلبات الانضمام'), findsOneWidget);
      expect(find.textContaining('المجموعات التدريبية المعتمدة'), findsOneWidget);
      expect(find.textContaining('Digital SAT Master (Target 800)'), findsOneWidget);
      expect(find.textContaining('EST I & EST II Intensive'), findsOneWidget);
      expect(find.textContaining('ACT Math Sprint Drills'), findsOneWidget);
    });

    testWidgets('SatDomainMasteryCard displays 4 College Board domains and Target 800', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: SatDomainMasteryCard(
                projectedScore: 740,
                targetScore: 800,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Heart of Algebra'), findsOneWidget);
      expect(find.text('Advanced Math'), findsOneWidget);
      expect(find.text('Problem-Solving & Data Analysis'), findsOneWidget);
      expect(find.text('Geometry & Trigonometry'), findsOneWidget);
      expect(find.text('740'), findsOneWidget);
      expect(find.text('/ 800'), findsOneWidget);
    });

    testWidgets('SatExamToolsSheet reference modal opens and displays formulas', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => SatExamToolsSheet.showReferenceSheet(context),
                  child: const Text('Open Formulas'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Formulas'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Reference Sheet'), findsOneWidget);
      expect(find.textContaining('A = π r²'), findsOneWidget);
      expect(find.textContaining('a² + b² = c²'), findsOneWidget);
    });

    testWidgets('SatExamToolsSheet calculator dialog opens and calculates', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () => SatExamToolsSheet.showCalculator(context),
                  child: const Text('Open Calc'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Calc'));
      await tester.pumpAndSettle();

      expect(find.text('حاسبة الـ SAT المدمجة'), findsOneWidget);
      // Press 7 + 8 = 15
      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('8'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('='));
      await tester.pumpAndSettle();

      expect(find.text('15'), findsOneWidget);
    });
  });
}
