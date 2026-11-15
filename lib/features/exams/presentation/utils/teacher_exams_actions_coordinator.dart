import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/exam_folder_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../pages/create_exam_page.dart';
import '../widgets/exam_folder_dialogs.dart';
import '../widgets/link_exam_to_lecture_sheet.dart';
import '../widgets/teacher_exam_details_sheet.dart';
import '../widgets/teacher_exams_confirmation_dialogs.dart';

/// Coordinator for teacher exam actions, lifecycle mutations, dialogs,
/// and folder management.
class TeacherExamsActionsCoordinator {
  const TeacherExamsActionsCoordinator._();

  static void showLinkExamDialog({
    required BuildContext context,
    required ExamEntity exam,
    required String groupId,
    required ExamsCubit cubit,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (sheetContext) {
        return LinkExamToLectureSheet(
          exam: exam,
          groupId: groupId,
          cubit: cubit,
        );
      },
    );
  }

  static Future<void> confirmUnlinkExam({
    required BuildContext context,
    required ExamEntity exam,
    required String groupId,
    required ExamsCubit cubit,
  }) async {
    final confirmed = await TeacherExamsConfirmationDialogs.confirmUnlink(
      context,
      examTitle: exam.title,
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final l10n = context.l10n;
      final success = await cubit.unlinkExamFromLesson(
        examId: exam.id,
        groupId: groupId,
        makeGeneralExam: true,
      );
      if (context.mounted && success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.examUnlinkedSuccessToast),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  static Future<void> convertToLectureExam({
    required BuildContext context,
    required ExamEntity exam,
    required String groupId,
    required ExamsCubit cubit,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final success = await cubit.convertExamType(
      examId: exam.id,
      contentId: exam.contentId,
      toLectureExam: true,
      groupId: groupId,
    );
    if (context.mounted && success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.examConvertedToLectureSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      showLinkExamDialog(
        context: context,
        exam: exam,
        groupId: groupId,
        cubit: cubit,
      );
    }
  }

  static Future<void> publishExam({
    required BuildContext context,
    required ExamEntity exam,
    required ExamsCubit cubit,
  }) async {
    if (exam.activeVersion == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final publishedSuccessMsg = context.l10n.versionPublishedSuccess;
    final success = await cubit.publishVersion(
      exam.activeVersion!.id,
      exam.id,
    );
    if (context.mounted && success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(publishedSuccessMsg),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  static Future<void> confirmUnpublish({
    required BuildContext context,
    required ExamEntity exam,
    required ExamsCubit cubit,
  }) async {
    if (exam.activeVersion == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final successMsg = context.l10n.examUnpublishedSuccess;

    final confirmed = await TeacherExamsConfirmationDialogs.confirmUnpublish(
      context,
      examTitle: exam.title,
    );

    if (confirmed == true && context.mounted) {
      final success = await cubit.unpublishVersion(
        examId: exam.id,
        versionId: exam.activeVersion!.id,
      );
      if (context.mounted && success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  static Future<void> handleDeleteExam({
    required BuildContext context,
    required ExamEntity exam,
    required ExamsCubit cubit,
  }) async {
    final hasAttempts = exam.attemptsCount > 0;
    final confirmed =
        await TeacherExamsConfirmationDialogs.confirmDeleteOrArchive(
      context,
      examTitle: exam.title,
      attemptsCount: exam.attemptsCount,
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final l10n = context.l10n;
      final success = await cubit.deleteExam(
        examId: exam.id,
      );
      if (context.mounted) {
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                hasAttempts
                    ? l10n.examArchivedSuccessToast
                    : l10n.examDeletedSuccessToast,
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          final state = cubit.state;
          final errorMsg = (state is TeacherExamsLoaded && state.message != null)
              ? state.message!
              : (state is ExamsError ? state.message : l10n.errorOccurred);
          messenger.showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  static Future<void> openEditDraftExam({
    required BuildContext context,
    required ExamEntity exam,
    required ExamsCubit cubit,
    required String? selectedGroupId,
    required VoidCallback onReload,
  }) async {
    ExamEntity examToEdit = exam;
    final needsFetch =
        exam.activeVersion == null || exam.activeVersion!.questions.isEmpty;

    if (needsFetch) {
      final l10n = context.l10n;
      AppFeedback.showLoadingDialog(
        context,
        message: l10n.loadingExamDetails,
      );

      try {
        final fullExam = await cubit
            .getExamDetails(exam.id)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);

        if (!context.mounted) return;
        AppFeedback.hideLoadingDialog(context);

        if (fullExam != null) {
          examToEdit = fullExam;
        } else {
          AppFeedback.showError(
            context,
            l10n.failedToLoadExamDetails,
          );
          return;
        }
      } catch (e) {
        if (context.mounted) {
          AppFeedback.hideLoadingDialog(context);
          AppFeedback.showError(
            context,
            context.l10n.failedToLoadExamDetails,
          );
        }
        return;
      }
    }

    if (!context.mounted) return;

    final updated = await Navigator.of(context).push<ExamEntity?>(
      MaterialPageRoute<ExamEntity?>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: CreateExamPage(
            groupId: examToEdit.groupId.isNotEmpty
                ? examToEdit.groupId
                : selectedGroupId,
            groupName: examToEdit.groupName,
            initialTitle: examToEdit.title,
            existingExam: examToEdit,
          ),
        ),
      ),
    );

    if (updated != null) {
      cubit.invalidateExamDetailsCache(exam.id);
      if (context.mounted) {
        onReload();
      }
    }
  }

  static Future<void> showCreateFolderDialog({
    required BuildContext context,
    required ExamsCubit cubit,
    required String? selectedGroupId,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await CreateOrEditExamFolderDialog.show(
      context,
      onSave: ({required name, color, description}) async {
        final success = await cubit.createFolder(
          name: name,
          groupId: selectedGroupId,
          color: color ?? '#5B4FE0',
          description: description,
        );
        if (context.mounted && success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.folderCreatedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return success;
      },
    );
  }

  static Future<void> showEditFolderDialog({
    required BuildContext context,
    required ExamFolderEntity folder,
    required ExamsCubit cubit,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    await CreateOrEditExamFolderDialog.show(
      context,
      initialFolder: folder,
      onSave: ({required name, color, description}) async {
        final success = await cubit.updateFolder(
          folderId: folder.id,
          name: name,
          color: color,
          description: description,
        );
        if (context.mounted && success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.folderUpdatedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
        }
        return success;
      },
    );
  }

  static Future<void> confirmDeleteFolder({
    required BuildContext context,
    required ExamFolderEntity folder,
    required ExamsCubit cubit,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteFolderDialogTitle),
        content: Text(l10n.deleteFolderDialogBody(folder.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelAction),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.confirmDeleteButton),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await cubit.deleteFolder(folder.id);
      if (context.mounted && success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.folderDeletedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  static Future<void> showMoveExamFolderDialog({
    required BuildContext context,
    required ExamEntity exam,
    required ExamsCubit cubit,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final state = cubit.state;
    final folders =
        state is TeacherExamsLoaded ? state.folders : <ExamFolderEntity>[];

    await MoveExamFolderDialog.show(
      context,
      examTitle: exam.title,
      currentFolderId: exam.folderId,
      folders: folders,
      onSelectFolder: (newFolderId) async {
        final success = await cubit.moveExamToFolder(
          examId: exam.id,
          folderId: newFolderId,
        );
        if (context.mounted && success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                newFolderId == null
                    ? l10n.examRemovedFromFolderSuccess
                    : l10n.examMovedToFolderSuccess,
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
    );
  }

  static void openParentDispatch({
    required BuildContext context,
    required ExamEntity exam,
  }) {
    context.push(
      '/teacher/exams/${exam.id}/parent-dispatch?title=${Uri.encodeComponent(exam.title)}',
    );
  }

  static void showExamDetailsSheet({
    required BuildContext context,
    required ExamEntity exam,
    required ExamsCubit cubit,
    required String? selectedGroupId,
    required VoidCallback onReload,
  }) {
    cubit.selectExamForTeacher(exam);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: cubit,
          child: TeacherExamDetailsSheetContent(
            exam: exam,
            cubit: cubit,
            onLinkLecture: () {
              Navigator.of(sheetContext).pop();
              if (selectedGroupId != null) {
                showLinkExamDialog(
                  context: context,
                  exam: exam,
                  groupId: selectedGroupId,
                  cubit: cubit,
                );
              }
            },
            onUnlinkLecture: () {
              Navigator.of(sheetContext).pop();
              if (selectedGroupId != null) {
                confirmUnlinkExam(
                  context: context,
                  exam: exam,
                  groupId: selectedGroupId,
                  cubit: cubit,
                );
              }
            },
            onDeleteExam: () {
              Navigator.of(sheetContext).pop();
              handleDeleteExam(
                context: context,
                exam: exam,
                cubit: cubit,
              );
            },
            onEditQuestions: () {
              Navigator.of(sheetContext).pop();
              if (context.mounted) {
                openEditDraftExam(
                  context: context,
                  exam: exam,
                  cubit: cubit,
                  selectedGroupId: selectedGroupId,
                  onReload: onReload,
                );
              }
            },
          ),
        );
      },
    );
  }

  /// Transfers an exam between Question Bank and Real Test categories with instant feedback
  static Future<void> moveExamCategory({
    required BuildContext context,
    required ExamEntity exam,
    required ExamCategory targetCategory,
    required ExamsCubit cubit,
  }) async {
    final l10n = context.l10n;
    await HapticFeedback.mediumImpact();
    final success = await cubit.moveExamCategory(
      examId: exam.id,
      targetCategory: targetCategory,
    );

    if (context.mounted) {
      if (success) {
        final message = targetCategory.isQuestionBank
            ? l10n.examMovedToBankSuccess
            : l10n.examMovedToRealTestSuccess;
        AppFeedback.showSuccess(context, message);
      } else {
        AppFeedback.showError(
          context,
          context.l10n.errorOccurred,
        );
      }
    }
  }
}
