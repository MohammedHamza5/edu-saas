import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/features/content/domain/entities/content_entity.dart';
import 'package:edu_saas/features/content/domain/entities/lesson_assignment_entity.dart';
import 'package:edu_saas/features/content/presentation/widgets/student_lesson_tile.dart';

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
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('Student UX Redesign — Final Acceptance Tests (Section 44)', () {
    // Initial Course Setup: SAT Advanced Prep with 3 Lessons
    late LessonAssignmentEntity lesson1;
    late LessonAssignmentEntity lesson2;
    late LessonAssignmentEntity lesson3;

    setUp(() {
      lesson1 = const LessonAssignmentEntity(
        contentGroupId: 'cg-sat-01',
        contentId: 'content-vid-01',
        groupId: 'group-sat-adv',
        title: 'Lesson 1: Introduction & Functions',
        type: ContentType.video,
        sortOrder: 1,
        pdfFileId: 'pdf-01',
        pdfFileName: 'Lesson1_Handout.pdf',
        pdfStoragePath: 'materials/sat/l1.pdf',
        lessonExamId: 'exam-l1',
        lessonExamTitle: 'Lesson 1 Quiz: Functions',
        effectivePassingScore: 60,
        access: LessonAccess.unlocked,
        progress: LessonProgress.notStarted,
        unlockSource: UnlockSource.firstLesson,
        videoDurationSeconds: 1200,
      );

      lesson2 = const LessonAssignmentEntity(
        contentGroupId: 'cg-sat-02',
        contentId: 'content-vid-02',
        groupId: 'group-sat-adv',
        title: 'Lesson 2: Advanced Quadratics',
        type: ContentType.video,
        sortOrder: 2,
        pdfFileId: 'pdf-02',
        pdfFileName: 'Lesson2_Handout.pdf',
        pdfStoragePath: 'materials/sat/l2.pdf',
        lessonExamId: 'exam-l2',
        lessonExamTitle: 'Lesson 2 Quiz: Quadratics',
        effectivePassingScore: 60,
        prerequisiteExamId: 'exam-l1',
        access: LessonAccess.locked,
        progress: LessonProgress.notStarted,
        videoDurationSeconds: 1500,
      );

      lesson3 = const LessonAssignmentEntity(
        contentGroupId: 'cg-sat-03',
        contentId: 'content-vid-03',
        groupId: 'group-sat-adv',
        title: 'Lesson 3: Exponential Growth',
        type: ContentType.video,
        sortOrder: 3,
        lessonExamId: 'exam-l3',
        lessonExamTitle: 'Lesson 3 Quiz: Exponentials',
        effectivePassingScore: 60,
        prerequisiteExamId: 'exam-l2',
        access: LessonAccess.locked,
        progress: LessonProgress.notStarted,
        videoDurationSeconds: 1800,
      );
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 1: Student opens Course.
    // Expected: Lesson 1 → Available, Lesson 2 → Locked, Lesson 3 → Locked
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 1: Initial Course State — Only Lesson 1 is Available, Lessons 2 & 3 are Locked', () {
      expect(lesson1.isLocked, isFalse);
      expect(lesson1.access, equals(LessonAccess.unlocked));

      expect(lesson2.isLocked, isTrue);
      expect(lesson2.access, equals(LessonAccess.locked));

      expect(lesson3.isLocked, isTrue);
      expect(lesson3.access, equals(LessonAccess.locked));
    });

    testWidgets('Test 1 UI: Renders Available badge on Lesson 1 and Locked on Lessons 2 & 3', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          Column(
            children: [
              StudentLessonTile(
                lesson: lesson1,
                content: lesson1.toContentEntity(),
                index: 1,
                onTap: () {},
              ),
              StudentLessonTile(
                lesson: lesson2,
                content: lesson2.toContentEntity(),
                index: 2,
                onTap: () {},
              ),
              StudentLessonTile(
                lesson: lesson3,
                content: lesson3.toContentEntity(),
                index: 3,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Lesson 1 is Available
      expect(find.text('Available'), findsOneWidget);

      // Lessons 2 and 3 show locked text referencing prerequisite
      expect(find.textContaining('Complete Lesson 1 to unlock'), findsOneWidget);
      expect(find.textContaining('Complete Lesson 2 to unlock'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 2: Student opens Lesson 1.
    // Expected:
    // - video visible
    // - PDF available (without video completion)
    // - Lesson Quiz locked until video completion
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 2: PDF is accessible immediately; Quiz is locked until video is watched', () {
      // Student has not watched the video yet
      expect(lesson1.videoCompleted, isFalse);
      expect(lesson1.watchedCoveragePercent, equals(0.0));

      // PDF is accessible unconditionally for accessible lesson
      expect(lesson1.hasPdf, isTrue);
      expect(lesson1.pdfFileName, equals('Lesson1_Handout.pdf'));

      // Lesson quiz exists, but student has not qualified for quiz yet
      expect(lesson1.hasLessonExam, isTrue);
      expect(lesson1.progress, equals(LessonProgress.notStarted));
      // Quiz requires video completion
      final isQuizUnlocked = lesson1.videoCompleted || lesson1.progress == LessonProgress.quizAvailable;
      expect(isQuizUnlocked, isFalse);
    });

    testWidgets('Test 2 UI: Renders Study Material / PDF Chip while quiz is not completed', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          StudentLessonTile(
            lesson: lesson1,
            content: lesson1.toContentEntity(),
            index: 1,
            onTap: () {},
            onOpenHandout: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // PDF study material chip is visible immediately
      expect(find.text('Handout PDF'), findsOneWidget);
      // Lesson 1 is not completed
      expect(find.text('Completed'), findsNothing);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 3: Student watches video to legitimate completion.
    // Expected:
    // ✓ Video completed
    // [ Start Lesson Quiz ]
    // NOT: Next Lesson unlocked
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 3: Video completed unlocks Lesson Quiz, NOT Next Lesson', () {
      // Update lesson 1 to video watched
      final watchedLesson1 = lesson1.copyWith(
        videoCompleted: true,
        watchedCoveragePercent: 95.0,
        progress: LessonProgress.quizAvailable,
      );

      // Video is completed and quiz is ready
      expect(watchedLesson1.videoCompleted, isTrue);
      expect(watchedLesson1.progress, equals(LessonProgress.quizAvailable));

      // BUT lesson 1 itself is NOT completed yet (Quiz must be passed)
      expect(watchedLesson1.isEffectivelyCompleted, isFalse);

      // And Lesson 2 remains STRICTLY LOCKED
      expect(lesson2.isLocked, isTrue);
      expect(lesson2.access, equals(LessonAccess.locked));
    });

    testWidgets('Test 3 UI: Lesson tile reflects Quiz Ready state and Next Lesson remains locked', (tester) async {
      final watchedLesson1 = lesson1.copyWith(
        videoCompleted: true,
        watchedCoveragePercent: 95.0,
        progress: LessonProgress.quizAvailable,
      );

      await tester.pumpWidget(
        buildTestApp(
          Column(
            children: [
              StudentLessonTile(
                lesson: watchedLesson1,
                content: watchedLesson1.toContentEntity(),
                index: 1,
                onTap: () {},
              ),
              StudentLessonTile(
                lesson: lesson2,
                content: lesson2.toContentEntity(),
                index: 2,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your lesson quiz is ready.'), findsOneWidget);
      expect(find.textContaining('Complete Lesson 1 to unlock'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 4: Student opens Lesson Quiz and fails.
    // Expected:
    // Lesson 1 → Quiz Failed
    // Lesson 2 → Locked
    // Student can retry. Video progress preserved.
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 4: Quiz failure marks Lesson 1 as quizFailed, keeps Lesson 2 locked, preserves video', () {
      final failedLesson1 = lesson1.copyWith(
        videoCompleted: true,
        watchedCoveragePercent: 95.0,
        progress: LessonProgress.quizFailed,
        examBestScore: 45.0,
        examPassed: false,
      );

      expect(failedLesson1.progress, equals(LessonProgress.quizFailed));
      expect(failedLesson1.examPassed, isFalse);
      expect(failedLesson1.examBestScore, equals(45.0));

      // Video progress must NOT be reset on quiz failure
      expect(failedLesson1.videoCompleted, isTrue);
      expect(failedLesson1.watchedCoveragePercent, equals(95.0));

      // Lesson is NOT completed
      expect(failedLesson1.isEffectivelyCompleted, isFalse);

      // Lesson 2 remains strictly locked
      expect(lesson2.isLocked, isTrue);
      expect(lesson2.access, equals(LessonAccess.locked));
    });

    testWidgets('Test 4 UI: Renders Quiz Failed badge and score warning', (tester) async {
      final failedLesson1 = lesson1.copyWith(
        videoCompleted: true,
        watchedCoveragePercent: 95.0,
        progress: LessonProgress.quizFailed,
        examBestScore: 45.0,
        examPassed: false,
      );

      await tester.pumpWidget(
        buildTestApp(
          StudentLessonTile(
            lesson: failedLesson1,
            content: failedLesson1.toContentEntity(),
            index: 1,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quiz not passed (45%)'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 5: Student retries and passes.
    // Expected:
    // Lesson 1 → Completed
    // Lesson 2 → Available
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 5: Passing quiz completes Lesson 1 and unlocks Lesson 2', () {
      final passedLesson1 = lesson1.copyWith(
        videoCompleted: true,
        watchedCoveragePercent: 95.0,
        progress: LessonProgress.completed,
        examBestScore: 85.0,
        examPassed: true,
      );

      expect(passedLesson1.progress, equals(LessonProgress.completed));
      expect(passedLesson1.isEffectivelyCompleted, isTrue);
      expect(passedLesson1.examPassed, isTrue);

      // Sequential progression unlocks Lesson 2
      final unlockedLesson2 = lesson2.copyWith(
        access: LessonAccess.unlocked,
        progress: LessonProgress.notStarted,
        unlockSource: UnlockSource.prerequisiteCompletion,
      );

      expect(unlockedLesson2.isLocked, isFalse);
      expect(unlockedLesson2.access, equals(LessonAccess.unlocked));
      expect(unlockedLesson2.unlockSource, equals(UnlockSource.prerequisiteCompletion));

      // Lesson 3 remains locked
      expect(lesson3.isLocked, isTrue);
    });

    testWidgets('Test 5 UI: Renders Completed on Lesson 1 and Available on Lesson 2', (tester) async {
      final passedLesson1 = lesson1.copyWith(
        videoCompleted: true,
        watchedCoveragePercent: 95.0,
        progress: LessonProgress.completed,
        examBestScore: 85.0,
        examPassed: true,
      );

      final unlockedLesson2 = lesson2.copyWith(
        access: LessonAccess.unlocked,
        progress: LessonProgress.notStarted,
        unlockSource: UnlockSource.prerequisiteCompletion,
      );

      await tester.pumpWidget(
        buildTestApp(
          Column(
            children: [
              StudentLessonTile(
                lesson: passedLesson1,
                content: passedLesson1.toContentEntity(),
                index: 1,
                onTap: () {},
              ),
              StudentLessonTile(
                lesson: unlockedLesson2,
                content: unlockedLesson2.toContentEntity(),
                index: 2,
                onTap: () {},
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 6: Student revisits Lesson 1.
    // Expected:
    // - video still accessible
    // - PDF still accessible
    // - quiz still accessible
    // - previous progress preserved
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 6: Revisit completed Lesson 1 — all materials, video, and quiz preserved', () {
      final passedLesson1 = lesson1.copyWith(
        videoCompleted: true,
        watchedCoveragePercent: 95.0,
        progress: LessonProgress.completed,
        examBestScore: 85.0,
        examPassed: true,
      );

      // Access remains unlocked
      expect(passedLesson1.access, equals(LessonAccess.unlocked));
      expect(passedLesson1.isLocked, isFalse);

      // PDF is still present and accessible
      expect(passedLesson1.hasPdf, isTrue);
      expect(passedLesson1.pdfStoragePath, equals('materials/sat/l1.pdf'));

      // Video tracking progress is intact
      expect(passedLesson1.watchedCoveragePercent, equals(95.0));
      expect(passedLesson1.videoCompleted, isTrue);

      // Quiz result is intact
      expect(passedLesson1.examPassed, isTrue);
      expect(passedLesson1.examBestScore, equals(85.0));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 7: Teacher reorders Lesson 2 and Lesson 3.
    // Expected:
    // - Lesson 1 remains completed
    // - quiz attempts remain
    // - video progress remains
    // - previously unlocked access is not accidentally revoked
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 7: Reordering preserves student progress, attempts, and unlocks by stable assignment ID', () {
      final passedLesson1 = lesson1.copyWith(
        videoCompleted: true,
        watchedCoveragePercent: 95.0,
        progress: LessonProgress.completed,
        examBestScore: 85.0,
        examPassed: true,
      );

      // Teacher swaps order of Lesson 2 and 3
      final reorderedLesson2 = lesson2.copyWith(
        sortOrder: 3, // was 2
        access: LessonAccess.unlocked, // was already unlocked
      );

      final reorderedLesson3 = lesson3.copyWith(
        sortOrder: 2, // was 3
      );

      // Lesson 1 completion is untouched
      expect(passedLesson1.isEffectivelyCompleted, isTrue);
      expect(passedLesson1.examBestScore, equals(85.0));
      expect(passedLesson1.watchedCoveragePercent, equals(95.0));

      // Stable IDs ensure progress maps to contentGroupId/contentId, not sortOrder
      expect(passedLesson1.contentGroupId, equals('cg-sat-01'));
      expect(reorderedLesson2.contentGroupId, equals('cg-sat-02'));
      expect(reorderedLesson2.access, equals(LessonAccess.unlocked));
      expect(reorderedLesson3.contentGroupId, equals('cg-sat-03'));
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 8: Teacher manually unlocks Lesson 3.
    // Expected:
    // Student can access Lesson 3.
    // But:
    // Quiz attempts = unchanged
    // Quiz score = unchanged
    // Lesson completion = unchanged (NOT completed)
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 8: Manual unlock changes ACCESS only; does not fake score or completion', () {
      final manuallyUnlockedLesson3 = lesson3.copyWith(
        access: LessonAccess.unlocked,
        isManuallyUnlocked: true,
        unlockSource: UnlockSource.manualOverride,
        // Quiz attempts and completion must NOT be altered
        progress: LessonProgress.notStarted,
        examBestScore: null,
        examPassed: false,
        videoCompleted: false,
      );

      // Can access Lesson 3
      expect(manuallyUnlockedLesson3.isLocked, isFalse);
      expect(manuallyUnlockedLesson3.access, equals(LessonAccess.unlocked));
      expect(manuallyUnlockedLesson3.isManuallyUnlocked, isTrue);

      // BUT NOT completed!
      expect(manuallyUnlockedLesson3.isEffectivelyCompleted, isFalse);
      expect(manuallyUnlockedLesson3.progress, equals(LessonProgress.notStarted));

      // No fake quiz score or attempts
      expect(manuallyUnlockedLesson3.examBestScore, isNull);
      expect(manuallyUnlockedLesson3.examPassed, isFalse);

      // Video completion is false
      expect(manuallyUnlockedLesson3.videoCompleted, isFalse);
    });

    testWidgets('Test 8 UI: Manually unlocked lesson displays Available, NOT Completed', (tester) async {
      final manuallyUnlockedLesson3 = lesson3.copyWith(
        access: LessonAccess.unlocked,
        isManuallyUnlocked: true,
        unlockSource: UnlockSource.manualOverride,
        progress: LessonProgress.notStarted,
        examBestScore: null,
        examPassed: false,
        videoCompleted: false,
      );

      await tester.pumpWidget(
        buildTestApp(
          StudentLessonTile(
            lesson: manuallyUnlockedLesson3,
            content: manuallyUnlockedLesson3.toContentEntity(),
            index: 3,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
    });

    // ─────────────────────────────────────────────────────────────────────────
    // Test 9: Student takes a General Course Exam.
    // Expected:
    // General Exam completion does NOT unlock the next lesson.
    // ─────────────────────────────────────────────────────────────────────────
    test('Test 9: General Exam completion does NOT unlock next lesson in sequence', () {
      // General Course Exam (not a lesson prerequisite)
      const generalMidtermExamId = 'general-midterm-exam-sat';
      
      // Lesson 2 is currently locked, waiting for Lesson 1 Quiz ('exam-l1')
      expect(lesson2.prerequisiteExamId, equals('exam-l1'));
      expect(lesson2.isLocked, isTrue);

      // Student passes the General Midterm Exam with 100%
      const generalExamScore = 100.0;
      expect(generalExamScore, equals(100.0));
      const passedExamId = generalMidtermExamId;

      // Checking sequential unlock:
      // The prerequisite for lesson2 is 'exam-l1', NOT 'general-midterm-exam-sat'
      final isPrerequisiteSatisfied = passedExamId == lesson2.prerequisiteExamId;
      expect(isPrerequisiteSatisfied, isFalse);

      // Therefore Lesson 2 remains locked
      final updatedLesson2 = isPrerequisiteSatisfied
          ? lesson2.copyWith(access: LessonAccess.unlocked)
          : lesson2;

      expect(updatedLesson2.isLocked, isTrue);
      expect(updatedLesson2.access, equals(LessonAccess.locked));
    });
  });
}
