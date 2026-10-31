import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

class ExamCardTeacherMenu extends StatelessWidget {
  final ExamEntity exam;
  final VoidCallback onTap;
  final VoidCallback? onPublish;
  final VoidCallback? onUnpublish;
  final VoidCallback? onEditQuestions;
  final VoidCallback? onEdit;
  final VoidCallback? onLinkLecture;
  final VoidCallback? onUnlinkLecture;
  final VoidCallback? onConvertToLecture;
  final VoidCallback? onConvertToGeneral;
  final VoidCallback? onDelete;
  final VoidCallback? onDispatchResults;
  final VoidCallback? onMoveToFolder;

  const ExamCardTeacherMenu({
    super.key,
    required this.exam,
    required this.onTap,
    this.onPublish,
    this.onUnpublish,
    this.onEditQuestions,
    this.onEdit,
    this.onLinkLecture,
    this.onUnlinkLecture,
    this.onConvertToLecture,
    this.onConvertToGeneral,
    this.onDelete,
    this.onDispatchResults,
    this.onMoveToFolder,
  });

  @override
  Widget build(BuildContext context) {
    final isLecture = exam.isLectureExam;

    return PopupMenuButton<String>(
      icon: const Icon(
        Icons.more_vert,
        size: 18,
        color: AppColors.textSecondary,
      ),
      padding: EdgeInsets.zero,
      tooltip: context.l10n.settingsTitle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          AppSpacing.radiusMedium,
        ),
      ),
      onSelected: (val) {
        if (val == 'details') {
          onTap();
        } else if (val == 'publish' && onPublish != null) {
          onPublish!();
        } else if (val == 'unpublish' && onUnpublish != null) {
          onUnpublish!();
        } else if (val == 'edit_questions' && onEditQuestions != null) {
          onEditQuestions!();
        } else if (val == 'edit' && onEdit != null) {
          onEdit!();
        } else if (val == 'link' && onLinkLecture != null) {
          onLinkLecture!();
        } else if (val == 'unlink' && onUnlinkLecture != null) {
          onUnlinkLecture!();
        } else if (val == 'to_lecture' && onConvertToLecture != null) {
          onConvertToLecture!();
        } else if (val == 'to_general' && onConvertToGeneral != null) {
          onConvertToGeneral!();
        } else if (val == 'delete' && onDelete != null) {
          onDelete!();
        } else if (val == 'dispatch_results' && onDispatchResults != null) {
          onDispatchResults!();
        } else if (val == 'move_folder' && onMoveToFolder != null) {
          onMoveToFolder!();
        }
      },
      itemBuilder: (ctx) => [
        if (!exam.isPublished && onPublish != null) ...[
          PopupMenuItem(
            value: 'publish',
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 18,
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.publishCurrentDraftAction,
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ] else if (exam.isPublished && onUnpublish != null) ...[
          PopupMenuItem(
            value: 'unpublish',
            child: Row(
              children: [
                const Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.unpublishExamAction,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: 'details',
          child: Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(ctx.l10n.viewExamDetailsAndAttempts),
            ],
          ),
        ),
        if (onDispatchResults != null && exam.attemptsCount > 0)
          PopupMenuItem(
            value: 'dispatch_results',
            child: Row(
              children: [
                const Icon(
                  Icons.send_rounded,
                  size: 18,
                  color: Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.examParentDispatchHubTitle,
                  style: const TextStyle(
                    color: Color(0xFF16A34A),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (exam.canEditQuestions && onEditQuestions != null)
          PopupMenuItem(
            value: 'edit_questions',
            child: Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.editDraftQuestionsAction,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        if (onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(ctx.l10n.editExamSettingsAction),
              ],
            ),
          ),
        if (onMoveToFolder != null)
          PopupMenuItem(
            value: 'move_folder',
            child: Row(
              children: [
                const Icon(
                  Icons.drive_file_move_outlined,
                  size: 18,
                  color: Color(0xFF5B4FE0),
                ),
                const SizedBox(width: 8),
                Text(ctx.l10n.moveExamToFolderAction),
              ],
            ),
          ),
        const PopupMenuDivider(),
        if (onLinkLecture != null)
          PopupMenuItem(
            value: 'link',
            child: Row(
              children: [
                const Icon(
                  Icons.link_rounded,
                  size: 18,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.linkOrChangeLectureAction,
                ),
              ],
            ),
          ),
        if (exam.isLinkedToLesson && onUnlinkLecture != null)
          PopupMenuItem(
            value: 'unlink',
            child: Row(
              children: [
                const Icon(
                  Icons.link_off_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(ctx.l10n.unlinkFromLectureAction),
              ],
            ),
          ),
        if (!isLecture && onConvertToLecture != null)
          PopupMenuItem(
            value: 'to_lecture',
            child: Row(
              children: [
                const Icon(
                  Icons.menu_book_rounded,
                  size: 18,
                  color: Color(0xFF0284C7),
                ),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.convertToLectureQuizAction,
                ),
              ],
            ),
          ),
        if (isLecture && !exam.isLinkedToLesson && onConvertToGeneral != null)
          PopupMenuItem(
            value: 'to_general',
            child: Row(
              children: [
                const Icon(
                  Icons.assignment_rounded,
                  size: 18,
                  color: Color(0xFF7C3AED),
                ),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.convertToGeneralExamAction,
                ),
              ],
            ),
          ),
        if (onDelete != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.error,
                ),
                const SizedBox(width: 8),
                Text(
                  ctx.l10n.deleteExamAction,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
