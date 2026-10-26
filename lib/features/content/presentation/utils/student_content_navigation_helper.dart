import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/file_attachment_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../cubit/content_cubit.dart';
import '../widgets/material_viewer_sheet.dart';

/// Helper coordinating navigation and actions for student content items
/// (Video playback, PDF handouts, quizzes, assignments).
class StudentContentNavigationHelper {
  const StudentContentNavigationHelper._();

  static Future<void> handleContentTap({
    required BuildContext context,
    required LessonAssignmentEntity item,
    required String activeGroupId,
    required String? activeGroupName,
    required Future<void> Function(LessonAssignmentEntity item) onTakeQuiz,
    int? index,
    int? totalCount,
  }) async {
    if (item.isLocked) {
      final prevIndex = index != null && index > 1
          ? index - 1
          : (item.sortOrder > 1 ? item.sortOrder - 1 : 1);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(context.l10n.completeLessonToUnlock(prevIndex)),
        ),
      );
      return;
    }

    switch (item.type) {
      case ContentType.video:
        final encodedTitle = item.lessonExamTitle != null
            ? Uri.encodeComponent(item.lessonExamTitle!)
            : '';
        final encodedGroupName = activeGroupName != null
            ? Uri.encodeComponent(activeGroupName)
            : '';
        final lIndex = index ?? item.sortOrder;
        final tLessons = totalCount ?? 1;

        await context.push(
          '${AppRoutes.videoPlayer}?id=${item.contentId}&associatedExamId=${item.lessonExamId ?? ''}&associatedExamTitle=$encodedTitle&groupId=$activeGroupId&groupName=$encodedGroupName&lessonIndex=$lIndex&totalLessons=$tLessons',
        );
        break;

      case ContentType.assignment:
        await context.push(AppRoutes.studentAssignments);
        break;

      case ContentType.exam:
        if (item.hasLessonExam ||
            (item.lessonExamId != null && item.lessonExamId!.isNotEmpty)) {
          await onTakeQuiz(item);
        } else if (item.attachedExams.isNotEmpty) {
          final firstExam = item.attachedExams.first;
          await onTakeQuiz(
            item.copyWith(
              lessonExamId: firstExam.examId,
              lessonExamTitle: firstExam.examTitle,
            ),
          );
        } else {
          try {
            final exam = await context.read<ContentCubit>().getExamByContentId(
              item.contentId,
            );
            if (exam != null && context.mounted) {
              await onTakeQuiz(
                item.copyWith(
                  lessonExamId: exam['id'] as String,
                  lessonExamTitle: exam['title'],
                ),
              );
              break;
            }
          } catch (_) {}

          if (context.mounted) {
            await context.push(AppRoutes.studentExams);
          }
        }
        break;

      case ContentType.pdf:
      case ContentType.image:
        await openHandout(context: context, item: item);
        break;
    }
  }

  static Future<void> openHandout({
    required BuildContext context,
    required LessonAssignmentEntity item,
  }) async {
    if (item.pdfFileId == null) return;

    await MaterialViewerSheet.show(
      context,
      content: ContentEntity(
        id: item.contentId,
        tenantId: '',
        groupId: item.groupId,
        title: item.title,
        type: item.type,
        status: ContentStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        file: FileAttachmentEntity(
          id: item.pdfFileId!,
          tenantId: '',
          contentId: item.contentId,
          fileName: item.pdfFileName ?? '',
          storagePath: item.pdfStoragePath ?? '',
          mimeType: '',
          fileSize: 0,
          createdAt: DateTime.now(),
        ),
      ),
      onGetSignedUrl: (storagePath) => context
          .read<ContentRepository>()
          .getSignedFileUrl(storagePath: storagePath)
          .then((value) => value.dataOrNull ?? ''),
    );
  }
}
