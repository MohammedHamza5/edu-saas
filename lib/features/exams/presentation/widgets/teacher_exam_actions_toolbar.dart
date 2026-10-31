import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import 'edit_exam_dialog.dart';

class TeacherExamActionsToolbar extends StatefulWidget {
  final ExamEntity exam;
  final ExamsCubit cubit;
  final VoidCallback onLinkLecture;
  final VoidCallback onUnlinkLecture;
  final VoidCallback onDeleteExam;
  final VoidCallback? onEditQuestions;

  const TeacherExamActionsToolbar({
    super.key,
    required this.exam,
    required this.cubit,
    required this.onLinkLecture,
    required this.onUnlinkLecture,
    required this.onDeleteExam,
    this.onEditQuestions,
  });

  @override
  State<TeacherExamActionsToolbar> createState() =>
      _TeacherExamActionsToolbarState();
}

class _TeacherExamActionsToolbarState extends State<TeacherExamActionsToolbar> {
  bool _isPublishing = false;
  bool _isUnpublishing = false;

  @override
  Widget build(BuildContext context) {
    final exam = widget.exam;
    final isLecture = exam.isLectureExam;
    final isPublished = exam.isPublished;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      child: Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        children: [
          // Edit Questions button
          if (widget.onEditQuestions != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: Text(context.l10n.editDraftQuestionsAction),
              onPressed: widget.onEditQuestions,
            ),

          // Edit basic settings
          OutlinedButton.icon(
            icon: const Icon(Icons.tune_rounded, size: 15),
            label: Text(context.l10n.editExamSettingsAction),
            onPressed: () {
              Navigator.of(context).pop();
              EditExamDialog.show(context, exam);
            },
          ),

          // Parent Dispatch Hub Action Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF16A34A),
              side: BorderSide(
                color: const Color(0xFF16A34A).withValues(alpha: 0.5),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 14),
            label: Text(context.l10n.examParentDispatchHubTitle),
            onPressed: () {
              Navigator.of(context).pop();
              context.push(
                '/teacher/exams/${exam.id}/parent-dispatch?title=${Uri.encodeComponent(exam.title)}',
              );
            },
          ),

          // Unpublish button
          if (exam.activeVersion != null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning),
              ),
              icon: _isUnpublishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.warning,
                      ),
                    )
                  : const Icon(Icons.visibility_off_outlined, size: 15),
              label: Text(
                _isUnpublishing
                    ? context.l10n.unpublishingExamLoading
                    : context.l10n.unpublishExamAction,
              ),
              onPressed: _isUnpublishing ? null : _handleUnpublish,
            ),

          // If draft: Publish version button
          if (!isPublished && exam.activeVersion != null)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              icon: _isPublishing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined, size: 15),
              label: Text(
                _isPublishing
                    ? context.l10n.publishingVersionLoading
                    : context.l10n.publishCurrentDraftAction,
              ),
              onPressed: _isPublishing ? null : _handlePublish,
            ),

          // Link / Unlink shortcuts
          if (isLecture) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.link_rounded, size: 15),
              label: Text(
                exam.isLinkedToLesson
                    ? context.l10n.linkOrChangeLectureAction
                    : context.l10n.linkToLectureNowAction,
              ),
              onPressed: widget.onLinkLecture,
            ),
            if (exam.isLinkedToLesson)
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.link_off_rounded,
                  size: 15,
                  color: AppColors.warning,
                ),
                label: Text(
                  context.l10n.unlinkFromLectureAction,
                  style: const TextStyle(color: AppColors.warning),
                ),
                onPressed: widget.onUnlinkLecture,
              ),
          ],

          // Delete / Archive Exam
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 15,
              color: AppColors.error,
            ),
            label: Text(
              context.l10n.deleteExamAction,
              style: const TextStyle(color: AppColors.error),
            ),
            onPressed: widget.onDeleteExam,
          ),
        ],
      ),
    );
  }

  Future<void> _handleUnpublish() async {
    final exam = widget.exam;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final successMsg = context.l10n.examUnpublishedSuccess;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.visibility_off_outlined,
              color: AppColors.warning,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(dialogCtx.l10n.confirmUnpublishExamTitle),
            ),
          ],
        ),
        content: Text(dialogCtx.l10n.confirmUnpublishExamBody(exam.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(dialogCtx.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(dialogCtx.l10n.confirmUnpublishButton),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUnpublishing = true);
    final success = await widget.cubit.unpublishVersion(
      examId: exam.id,
      versionId: exam.activeVersion!.id,
    );
    if (!mounted) return;
    setState(() => _isUnpublishing = false);
    if (success) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _handlePublish() async {
    final exam = widget.exam;
    setState(() => _isPublishing = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final publishedSuccessMsg = context.l10n.versionPublishedSuccess;

    final success = await widget.cubit.publishVersion(
      exam.activeVersion!.id,
      exam.id,
    );
    if (!mounted) return;
    setState(() => _isPublishing = false);
    if (success) {
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(publishedSuccessMsg),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}
