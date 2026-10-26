import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/exams/domain/entities/academic_momentum_entity.dart';
import 'package:edu_saas/features/exams/presentation/widgets/momentum/mastery_badges_sheet.dart';
import 'package:edu_saas/features/exams/presentation/widgets/momentum/student_academic_momentum_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _buildWrapper({required Widget child, Locale locale = const Locale('ar')}) {
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
  group('Pillar 4: StudentAcademicMomentumCard Multi-Device Responsive Tests', () {
    const widths = <String, double>{
      'Narrow Mobile (300px)': 300,
      'Standard Mobile (360px)': 360,
      'Tablet (768px)': 768,
      'Desktop (1440px)': 1440,
    };

    const momentumActive = AcademicMomentumEntity(
      currentStreakDays: 7,
      longestStreakDays: 14,
      isTodayActive: true,
      completedExamsCount: 5,
      averagePercentage: 88.5,
      predictedScoreLow: 710,
      predictedScoreHigh: 770,
      badges: [
        AcademicBadgeEntity(type: AcademicBadgeType.gauntletSlayer, isUnlocked: true),
        AcademicBadgeEntity(type: AcademicBadgeType.consistencyKing, isUnlocked: true),
        AcademicBadgeEntity(type: AcademicBadgeType.speedDemon, isUnlocked: false),
        AcademicBadgeEntity(type: AcademicBadgeType.highAchiever, isUnlocked: false),
      ],
    );

    const momentumInitial = AcademicMomentumEntity(
      currentStreakDays: 0,
      longestStreakDays: 0,
      isTodayActive: false,
      completedExamsCount: 1,
      averagePercentage: 75.0,
      badges: [
        AcademicBadgeEntity(type: AcademicBadgeType.gauntletSlayer, isUnlocked: false),
        AcademicBadgeEntity(type: AcademicBadgeType.consistencyKing, isUnlocked: false),
        AcademicBadgeEntity(type: AcademicBadgeType.speedDemon, isUnlocked: false),
        AcademicBadgeEntity(type: AcademicBadgeType.highAchiever, isUnlocked: false),
      ],
    );

    for (final entry in widths.entries) {
      testWidgets('Renders StudentAcademicMomentumCard on ${entry.key} without overflow', (tester) async {
        await tester.pumpWidget(
          _buildWrapper(
            child: SizedBox(
              width: entry.value,
              child: const StudentAcademicMomentumCard(momentum: momentumActive),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(StudentAcademicMomentumCard), findsOneWidget);
        expect(find.text('710 - 770'), findsOneWidget);
      });
    }

    testWidgets('Renders guidance message when prediction is pending in English (LTR)', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          locale: const Locale('en'),
          child: const SizedBox(
            width: 360,
            child: StudentAcademicMomentumCard(momentum: momentumInitial),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(StudentAcademicMomentumCard), findsOneWidget);
      expect(find.text('Complete 2+ exams to unlock your estimated SAT score range'), findsOneWidget);
    });

    testWidgets('Tapping view all badges opens MasteryBadgesSheet modal', (tester) async {
      await tester.pumpWidget(
        _buildWrapper(
          child: const SizedBox(
            width: 360,
            child: StudentAcademicMomentumCard(momentum: momentumActive),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final viewAllBtn = find.text('عرض الكل');
      expect(viewAllBtn, findsOneWidget);
      await tester.tap(viewAllBtn);
      await tester.pumpAndSettle();

      expect(find.byType(MasteryBadgesSheet), findsOneWidget);
      expect(find.text('قاهر الأخطاء'), findsWidgets);
    });
  });
}
