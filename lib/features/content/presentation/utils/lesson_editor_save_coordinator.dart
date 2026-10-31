import 'dart:async';
import '../../../notifications/domain/services/notification_dispatcher.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../widgets/lesson_editor_quiz_section.dart';

/// Coordinator that encapsulates saving logic and sort order calculation for [LessonEditorPane].
class LessonEditorSaveCoordinator {
  const LessonEditorSaveCoordinator._();

  static Future<bool> saveLesson({
    required ContentCubit cubit,
    required ContentEntity selectedVideo,
    required ContentEntity? editingLesson,
    required String groupId,
    required String? lessonTitle,
    required String? fileId,
    required bool removePdf,
    required String? selectedExamId,
    required List<LessonEditorAttachedExam> attachedExams,
    required int? passingScore,
    required String? selectedChapterId,
    required bool isPublished,
  }) async {
    int? targetSortOrder;
    if (editingLesson != null) {
      targetSortOrder = editingLesson.sortOrder;
    } else {
      if (cubit.state is! ContentLoaded) {
        await cubit.loadGroupContent(groupId);
      }
      if (cubit.state is ContentLoaded) {
        final currentItems = (cubit.state as ContentLoaded).items;
        if (currentItems.isNotEmpty) {
          final maxOrder = currentItems
              .map((e) => e.sortOrder)
              .fold<int>(0, (prev, elem) => elem > prev ? elem : prev);
          targetSortOrder = maxOrder + 1;
        } else {
          targetSortOrder = 0;
        }
      } else {
        targetSortOrder = 0;
      }
    }

    final success = await cubit.assignContentToGroups(
      contentId: selectedVideo.id,
      groupIds: [groupId],
      groupConfigs: [
        {
          'group_id': groupId,
          'is_published': isPublished,
          'sort_order': targetSortOrder,
          if (lessonTitle != null) 'custom_title': lessonTitle,
          if (fileId != null) 'file_id': fileId,
          if (fileId == null && removePdf) 'file_id': null,
          if (selectedExamId != null) 'associated_exam_id': selectedExamId,
          if (selectedExamId == null) 'associated_exam_id': null,
          'attached_exams': attachedExams.asMap().entries.map((entry) => {
            'exam_id': entry.value.examId,
            'sort_order': entry.key,
            'is_required': entry.value.isRequired,
          }).toList(),
          if (passingScore != null) 'passing_score_override': passingScore,
          if (passingScore == null) 'passing_score_override': null,
          'chapter_id': selectedChapterId,
        },
      ],
    );

    if (success && isPublished) {
      unawaited(
        NotificationDispatcher.notifyNewLecture(
          title: lessonTitle ?? selectedVideo.title,
          groupId: groupId,
          contentId: selectedVideo.id,
          contentType: 'video',
        ),
      );
    }

    return success;
  }
}
