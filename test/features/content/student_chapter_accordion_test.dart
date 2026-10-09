import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/content/domain/entities/content_entity.dart';
import 'package:edu_saas/features/content/domain/entities/lesson_assignment_entity.dart';
import 'package:edu_saas/features/content/presentation/widgets/student_chapter_accordion_card.dart';

void main() {
  Widget createTestWidget({required Widget child}) {
    return MaterialApp(
      locale: const Locale('ar'),
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

  final testLessons = [
    const LessonAssignmentEntity(
      contentGroupId: 'cg-1',
      contentId: 'c-1',
      groupId: 'g-1',
      title: 'المحاضرة 1: مقدمة الجبر',
      type: ContentType.video,
      sortOrder: 1,
      chapterId: 'chap-1',
      chapterTitle: 'الفصل الأول: الجبر',
      chapterSortOrder: 1,
      access: LessonAccess.unlocked,
      progress: LessonProgress.completed,
      videoCompleted: true,
    ),
    const LessonAssignmentEntity(
      contentGroupId: 'cg-2',
      contentId: 'c-2',
      groupId: 'g-1',
      title: 'المحاضرة 2: المعادلات الخطية',
      type: ContentType.video,
      sortOrder: 2,
      chapterId: 'chap-1',
      chapterTitle: 'الفصل الأول: الجبر',
      chapterSortOrder: 1,
      access: LessonAccess.unlocked,
      progress: LessonProgress.inProgress,
    ),
    const LessonAssignmentEntity(
      contentGroupId: 'cg-3',
      contentId: 'c-3',
      groupId: 'g-1',
      title: 'المحاضرة 3: المتباينات',
      type: ContentType.video,
      sortOrder: 3,
      chapterId: 'chap-1',
      chapterTitle: 'الفصل الأول: الجبر',
      chapterSortOrder: 1,
      access: LessonAccess.locked,
      progress: LessonProgress.notStarted,
    ),
  ];

  testWidgets(
    'StudentChapterAccordionCard renders title, badge and lessons when expanded',
    (tester) async {
      bool toggled = false;
      LessonAssignmentEntity? tappedLesson;

      await tester.pumpWidget(
        createTestWidget(
          child: StudentChapterAccordionCard(
            chapterId: 'chap-1',
            chapterTitle: 'الفصل الأول: الجبر',
            chapterIndex: 1,
            lessons: testLessons,
            globalStartIndex: 1,
            isExpanded: true,
            onToggle: () => toggled = true,
            onLessonTap: (l, idx) => tappedLesson = l,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Chapter title & number
      expect(find.text('الفصل الأول: الجبر'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);

      // Verify Lesson titles inside expanded accordion
      expect(find.text('المحاضرة 1: مقدمة الجبر'), findsOneWidget);
      expect(find.text('المحاضرة 2: المعادلات الخطية'), findsOneWidget);
      expect(find.text('المحاضرة 3: المتباينات'), findsOneWidget);

      // Tap header triggers onToggle
      await tester.tap(find.text('الفصل الأول: الجبر'));
      expect(toggled, isTrue);

      // Tap lesson triggers onLessonTap
      await tester.tap(find.text('المحاضرة 1: مقدمة الجبر'));
      expect(tappedLesson?.contentId, equals('c-1'));
    },
  );

  testWidgets('StudentChapterAccordionCard hides lesson content when collapsed', (
    tester,
  ) async {
    await tester.pumpWidget(
      createTestWidget(
        child: StudentChapterAccordionCard(
          chapterId: 'chap-1',
          chapterTitle: 'الفصل الأول: الجبر',
          chapterIndex: 1,
          lessons: testLessons,
          globalStartIndex: 1,
          isExpanded: false,
          onToggle: () {},
          onLessonTap: (_, __) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('الفصل الأول: الجبر'), findsOneWidget);
    // When collapsed, the inner tiles are not shown (crossfade firstChild is SizedBox.shrink)
    expect(find.text('المحاضرة 1: مقدمة الجبر'), findsNothing);
  });
}
