import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/content/domain/entities/content_entity.dart';
import 'package:edu_saas/features/content/presentation/widgets/content_item_card.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';

void main() {
  group('Sequential Gated Learning & Video Bank Domain Tests', () {
    test('Lesson with unpassed prerequisite exam is locked', () {
      final lesson2 = ContentEntity(
        id: 'lesson-2',
        tenantId: 'tenant-1',
        groupId: 'group-1',
        title: 'Lesson 2: Advanced Quadratics',
        type: ContentType.video,
        status: ContentStatus.published,
        sortOrder: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        prerequisiteExamId: 'exam-lesson-1',
        prerequisiteExamTitle: 'Lesson 1 Quiz',
        prerequisitePassingScore: 70,
        isLocked: true,
      );

      expect(lesson2.isLocked, isTrue);
      expect(lesson2.prerequisiteExamId, equals('exam-lesson-1'));
      expect(lesson2.prerequisitePassingScore, equals(70));
    });

    test('Lesson with passed prerequisite exam is unlocked', () {
      final lesson2 = ContentEntity(
        id: 'lesson-2',
        tenantId: 'tenant-1',
        groupId: 'group-1',
        title: 'Lesson 2: Advanced Quadratics',
        type: ContentType.video,
        status: ContentStatus.published,
        sortOrder: 2,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        prerequisiteExamId: 'exam-lesson-1',
        prerequisiteExamTitle: 'Lesson 1 Quiz',
        prerequisitePassingScore: 70,
        isLocked: false, // passed
      );

      expect(lesson2.isLocked, isFalse);
    });

    test('Video Bank item with no groups is unassigned', () {
      final bankVideo = ContentEntity(
        id: 'video-bank-1',
        tenantId: 'tenant-1',
        groupId: null,
        title: 'Central Lecture: Intro to Algebra',
        type: ContentType.video,
        status: ContentStatus.published,
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        assignedGroupIds: const [],
      );

      expect(bankVideo.isUnassigned, isTrue);
      expect(bankVideo.assignedGroupIds, isEmpty);
    });

    test('Video Bank item assigned to 2 groups is not unassigned', () {
      final assignedVideo = ContentEntity(
        id: 'video-bank-2',
        tenantId: 'tenant-1',
        groupId: null,
        title: 'Calculus Session 1',
        type: ContentType.video,
        status: ContentStatus.published,
        sortOrder: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        assignedGroupIds: const ['group-basics', 'group-advanced'],
        assignedGroupNames: const ['Basics Group', 'Advanced Group'],
      );

      expect(assignedVideo.isUnassigned, isFalse);
      expect(assignedVideo.assignedGroupIds.length, equals(2));
      expect(assignedVideo.assignedGroupNames, contains('Basics Group'));
    });
  });

  group('Locked Lesson Card UI Tests', () {
    Widget buildTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        locale: const Locale('en'),
        home: Scaffold(body: child),
      );
    }

    testWidgets('Renders locked banner and required quiz info when isLocked is true',
        (tester) async {
      final lockedContent = ContentEntity(
        id: 'lesson-locked',
        tenantId: 'tenant-1',
        groupId: 'group-1',
        title: 'Trigonometry Lecture 3',
        type: ContentType.video,
        status: ContentStatus.published,
        sortOrder: 3,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        prerequisiteExamId: 'exam-trig-2',
        prerequisiteExamTitle: 'Trigonometry Quiz 2',
        prerequisitePassingScore: 75,
        isLocked: true,
      );

      await tester.pumpWidget(
        buildTestApp(
          ContentItemCard(
            content: lockedContent,
            isTeacher: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Trigonometry Lecture 3'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
      expect(find.textContaining('75%'), findsOneWidget);
    });

    testWidgets('Renders associated lesson quiz banner when present',
        (tester) async {
      final contentWithQuiz = ContentEntity(
        id: 'lesson-with-quiz',
        tenantId: 'tenant-1',
        groupId: 'group-1',
        title: 'Derivatives 101',
        type: ContentType.video,
        status: ContentStatus.published,
        sortOrder: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        associatedExamId: 'exam-derivatives',
        associatedExamTitle: 'Derivatives Practice Quiz',
        isLocked: false,
      );

      await tester.pumpWidget(
        buildTestApp(
          ContentItemCard(
            content: contentWithQuiz,
            isTeacher: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Derivatives 101'), findsOneWidget);
      expect(find.byIcon(Icons.quiz_outlined), findsOneWidget);
      expect(find.textContaining('Derivatives Practice Quiz'), findsOneWidget);
    });
  });
}
