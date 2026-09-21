import '../entities/lesson_assignment_entity.dart';

/// خدمة نقية لحساب حالة القفل/الفتح لكل درس في قائمة دروس المجموعة.
///
/// القواعد (بالترتيب):
/// 1. إذا كان الدرس مفتوح يدوياً → [LessonStatus.manuallyUnlocked]
/// 2. الدرس الأول دائماً مفتوح
/// 3. إذا كان التعلم المتسلسل مطفياً → كل الدروس مفتوحة
/// 4. إذا كان للدرس prerequisiteExamId → يجب اجتياز ذلك الاختبار أولاً
/// 5. وإلا → يجب أن يكون الدرس السابق مكتملاً
///
/// ملاحظة: هذه الخدمة لا تتصل بقاعدة البيانات. تعمل فقط على البيانات المجلوبة.
class LessonUnlockService {
  const LessonUnlockService._();

  /// يحسب حالة القفل للقائمة الكاملة ويعيدها محدَّثة.
  static List<LessonAssignmentEntity> applyUnlockRules({
    required List<LessonAssignmentEntity> lessons,
    required bool enforceSequential,
    Set<String> passedExamIds = const {},
  }) {
    if (lessons.isEmpty) return lessons;

    final result = <LessonAssignmentEntity>[];

    for (int i = 0; i < lessons.length; i++) {
      final lesson = lessons[i];

      if (lesson.isManuallyUnlocked) {
        result.add(lesson.copyWith(
          access: LessonAccess.unlocked,
          unlockSource: UnlockSource.manualOverride,
        ));
        continue;
      }

      if (i == 0) {
        result.add(lesson.copyWith(
          access: LessonAccess.unlocked,
          unlockSource: lesson.unlockSource ?? UnlockSource.firstLesson,
        ));
        continue;
      }

      if (!enforceSequential) {
        result.add(lesson.copyWith(access: LessonAccess.unlocked));
        continue;
      }

      if (lesson.prerequisiteExamId != null) {
        final prereqPassed = passedExamIds.contains(lesson.prerequisiteExamId);
        if (!prereqPassed) {
          result.add(lesson.copyWith(access: LessonAccess.locked));
          continue;
        }
        result.add(lesson.copyWith(
          access: LessonAccess.unlocked,
          unlockSource: UnlockSource.prerequisiteCompletion,
        ));
        continue;
      }

      final previous = result[i - 1];
      final prevCompleted = _isLessonCompleted(previous, passedExamIds);

      if (!prevCompleted) {
        result.add(lesson.copyWith(access: LessonAccess.locked));
        continue;
      }

      result.add(lesson.copyWith(
        access: LessonAccess.unlocked,
        unlockSource: UnlockSource.prerequisiteCompletion,
      ));
    }

    return result;
  }

  static bool _isLessonCompleted(
    LessonAssignmentEntity lesson,
    Set<String> passedExamIds,
  ) {
    if (lesson.progress == LessonProgress.completed) return true;

    if (!lesson.hasLessonExam) {
      return lesson.hasWatched90Percent || lesson.videoCompleted;
    }

    final videoOk = lesson.hasWatched90Percent || lesson.videoCompleted;
    final examOk = lesson.examPassed ||
        (lesson.lessonExamId != null &&
            passedExamIds.contains(lesson.lessonExamId));
    return videoOk && examOk;
  }
}
