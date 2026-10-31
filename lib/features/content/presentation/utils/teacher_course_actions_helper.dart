import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../dialogs/chapter_edit_dialog.dart';
import '../dialogs/move_lesson_to_chapter_dialog.dart';
import '../dialogs/quick_create_chapter_dialog.dart';

/// Helper coordinating confirmation dialogs and mutations for course lessons and chapters.
class TeacherCourseActionsHelper {
  TeacherCourseActionsHelper._();

  /// Prompts teacher with a confirmation dialog before deleting a lesson.
  static Future<void> confirmDeleteLesson({
    required BuildContext context,
    required ContentEntity item,
    required ContentCubit cubit,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.deleteConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ctx.l10n.deleteItemConfirmMessage(item.title)),
            const SizedBox(height: AppSpacing.s12),
            Text(
              ctx.l10n.deleteLessonSmartNote,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(ctx.l10n.deleteAction),
          ),
        ],
      ),
    );
    if (confirm == true) {
      unawaited(cubit.deleteContent(item.id));
    }
  }

  /// Prompts teacher with bulk publish/hide confirmation dialog and updates all lessons.
  static Future<void> handleBulkVisibility({
    required BuildContext context,
    required ContentCubit cubit,
    required String groupId,
    required bool isPublished,
  }) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isPublished
              ? l10n.publishAllLessonsConfirmTitle
              : l10n.hideAllLessonsConfirmTitle,
        ),
        content: Text(
          isPublished
              ? l10n.publishAllLessonsConfirmMessage
              : l10n.hideAllLessonsConfirmMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isPublished ? AppColors.success : AppColors.warning,
              foregroundColor: Colors.white,
            ),
            child: Text(
              isPublished
                  ? l10n.publishAllLessonsAction
                  : l10n.hideAllLessonsAction,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await cubit.toggleAllLessonsVisibility(
        groupId: groupId,
        isPublished: isPublished,
      );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.allLessonsVisibilityUpdatedToast),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Prompts teacher with chapter deletion confirmation dialog and deletes the chapter.
  static Future<void> handleDeleteChapter({
    required BuildContext context,
    required ContentCubit cubit,
    required ChapterEntity chapter,
  }) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            const SizedBox(width: AppSpacing.s8),
            Text(l10n.deleteChapterTitle),
          ],
        ),
        content: Text(l10n.deleteChapterConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await cubit.deleteChapter(chapter.id);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.chapterDeletedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  /// Opens the move lesson dialog and updates the lesson's target chapter.
  static Future<void> handleMoveLessonToChapter({
    required BuildContext context,
    required ContentCubit cubit,
    required String groupId,
    required ContentEntity lesson,
    required List<ChapterEntity> chapters,
  }) async {
    final l10n = context.l10n;
    final targetChapterId = await MoveLessonToChapterDialog.show(
      context,
      lesson: lesson,
      chapters: chapters,
    );

    if (targetChapterId != null && context.mounted) {
      final actualChapterId =
          targetChapterId == '__NONE__' ? null : targetChapterId;
      final success = await cubit.setLessonChapter(
        contentId: lesson.id,
        groupId: groupId,
        chapterId: actualChapterId,
      );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.lectureMovedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  /// Opens the create chapter dialog and displays a toast upon success.
  static Future<void> handleCreateChapter({
    required BuildContext context,
    required String groupId,
  }) async {
    final created = await QuickCreateChapterDialog.show(
      context,
      groupId: groupId,
    );
    if (created != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.chapterCreatedSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  /// Opens the edit chapter dialog and displays a toast upon success.
  static Future<void> handleEditChapter({
    required BuildContext context,
    required ChapterEntity chapter,
  }) async {
    final confirmed = await ChapterEditDialog.show(
      context,
      chapter: chapter,
    );
    if (confirmed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.chapterUpdatedSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  /// Toggles visibility for a single chapter with feedback.
  static Future<void> handleToggleChapterVisibility({
    required BuildContext context,
    required ContentCubit cubit,
    required ChapterEntity chapter,
  }) async {
    final l10n = context.l10n;
    final success = await cubit.toggleChapterVisibility(
      chapterId: chapter.id,
      isPublished: !chapter.isPublished,
    );
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !chapter.isPublished
                ? l10n.chapterPublishedToast
                : l10n.chapterHiddenToast,
          ),
          backgroundColor:
              !chapter.isPublished ? AppColors.success : AppColors.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Toggles visibility for a single lesson with feedback.
  static Future<void> handleToggleLessonVisibility({
    required BuildContext context,
    required ContentCubit cubit,
    required String groupId,
    required ContentEntity lesson,
  }) async {
    final success = await cubit.toggleLessonVisibility(
      contentId: lesson.id,
      groupId: groupId,
      isPublished: !lesson.isPublished,
    );
    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.lessonVisibilityUpdatedToast),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Reorders chapters within a course by a given delta.
  static Future<void> moveChapter({
    required ContentCubit cubit,
    required String groupId,
    required List<ChapterEntity> allChapters,
    required int currentIndex,
    required int delta,
  }) async {
    final newIndex = currentIndex + delta;
    if (newIndex < 0 || newIndex >= allChapters.length) return;

    final reordered = List<ChapterEntity>.from(allChapters);
    final movedItem = reordered.removeAt(currentIndex);
    reordered.insert(newIndex, movedItem);

    final idsInOrder = reordered.map((c) => c.id).toList();
    await cubit.reorderCourseChapters(
      groupId: groupId,
      chapterIdsInOrder: idsInOrder,
    );
  }

  /// Reorders lessons within a chapter via drag and drop.
  static Future<void> reorderLessonsInChapter({
    required ContentCubit cubit,
    required String groupId,
    required List<ContentEntity> chapterLessons,
    required int oldIndex,
    required int newIndex,
  }) async {
    var targetIndex = newIndex;
    if (oldIndex < targetIndex) {
      targetIndex -= 1;
    }
    if (oldIndex < 0 ||
        oldIndex >= chapterLessons.length ||
        targetIndex < 0 ||
        targetIndex >= chapterLessons.length ||
        oldIndex == targetIndex) {
      return;
    }
    final reordered = List<ContentEntity>.from(chapterLessons);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(targetIndex, moved);

    await cubit.reorderChapterLessons(
      groupId: groupId,
      contentIdsInOrder: reordered.map((l) => l.id).toList(),
    );
  }
}
