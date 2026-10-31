import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';

/// Helper for flushing video playback progress and performing smooth lesson transitions.
class VideoLessonNavigator {
  static Future<void> flushProgressAndExit({
    required BuildContext context,
    required Future<void> Function() forceFlushProgress,
    LessonAssignmentEntity? thenNavigateToLesson,
    int? lessonIndex,
    int? totalLessons,
    String? groupId,
    String? groupName,
    List<LessonAssignmentEntity> courseLessons = const [],
  }) async {
    // Fire-and-forget progress flush in background so navigation happens instantly without lag
    unawaited(forceFlushProgress());

    if (context.mounted) {
      if (thenNavigateToLesson != null) {
        final encodedTitle = thenNavigateToLesson.lessonExamTitle != null
            ? Uri.encodeComponent(thenNavigateToLesson.lessonExamTitle!)
            : '';
        final encodedGroupName = groupName != null
            ? Uri.encodeComponent(groupName)
            : '';
        final lIdx = lessonIndex ?? thenNavigateToLesson.sortOrder;
        final tLessons = totalLessons ?? courseLessons.length;
        context.pushReplacement(
          '${AppRoutes.videoPlayer}?id=${thenNavigateToLesson.contentId}&associatedExamId=${thenNavigateToLesson.lessonExamId ?? ''}&associatedExamTitle=$encodedTitle&groupId=$groupId&groupName=$encodedGroupName&lessonIndex=$lIdx&totalLessons=$tLessons',
        );
      } else {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go(AppRoutes.studentDashboard);
        }
      }
    }
  }

  /// Verifies lock status, reloads context if needed, and navigates to target lesson.
  static Future<void> openLesson({
    required BuildContext context,
    required LessonAssignmentEntity lesson,
    required int lessonIndex,
    required int totalLessons,
    required String? groupId,
    required String? groupName,
    required List<LessonAssignmentEntity> courseLessons,
    required Future<void> Function() forceFlushProgress,
    required Future<void> Function() reloadLessonContext,
  }) async {
    var targetLesson = lesson;
    if (targetLesson.isLocked) {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        ),
      );

      await forceFlushProgress();
      if (!context.mounted) return;
      await reloadLessonContext();
      if (!context.mounted) return;

      Navigator.of(context).pop();

      final updatedLesson = courseLessons.firstWhere(
        (l) => l.contentId == targetLesson.contentId,
        orElse: () => targetLesson,
      );

      if (updatedLesson.isLocked) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                context.l10n.completeLessonToUnlock(
                  lessonIndex > 1 ? lessonIndex - 1 : 1,
                ),
              ),
            ),
          );
        }
        return;
      }

      targetLesson = updatedLesson;
    }

    await flushProgressAndExit(
      context: context,
      forceFlushProgress: forceFlushProgress,
      thenNavigateToLesson: targetLesson,
      lessonIndex: lessonIndex,
      totalLessons: totalLessons,
      groupId: groupId,
      groupName: groupName,
      courseLessons: courseLessons,
    );
  }
}
