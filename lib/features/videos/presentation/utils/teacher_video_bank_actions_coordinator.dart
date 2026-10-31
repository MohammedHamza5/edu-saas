import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/presentation/dialogs/add_to_course_flow.dart';
import '../../domain/entities/library_video_entity.dart';
import '../../domain/entities/video_folder_entity.dart';
import '../cubit/video_bank_cubit.dart';
import '../dialogs/assign_folder_as_chapter_dialog.dart';
import '../dialogs/upload_video_to_bank_dialog.dart';
import '../dialogs/video_bank_folder_dialogs.dart';
import '../dialogs/video_preview_dialog.dart';

/// Coordinator isolating user actions, modal dialogs, and mutations for the Teacher Video Bank.
class TeacherVideoBankActionsCoordinator {
  const TeacherVideoBankActionsCoordinator._();

  static Future<void> createFolder(BuildContext context) async {
    final cubit = context.read<VideoBankCubit>();
    final l10n = context.l10n;
    final result = await CreateFolderDialog.show(context);
    if (!context.mounted) return;
    if (result != null && result.name.trim().isNotEmpty) {
      final success =
          await cubit.createFolder(result.name, color: result.color);
      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.folderCreatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  static Future<void> changeFolderColor(
    BuildContext context,
    VideoFolderEntity folder,
  ) async {
    final cubit = context.read<VideoBankCubit>();
    final l10n = context.l10n;
    final newColor = await ChangeFolderColorDialog.show(
      context,
      folder: folder,
    );
    if (!context.mounted) return;
    if (newColor != null) {
      final actualColor = newColor.isEmpty ? null : newColor;
      final success = await cubit.updateFolderColor(folder.id, actualColor);
      if (!context.mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.folderColorUpdated),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  static Future<void> assignFolderAsChapter(
    BuildContext context,
    VideoFolderEntity folder,
  ) async {
    final success = await AssignFolderAsChapterDialog.show(
      context,
      folder: folder,
    );
    if (success == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.assignFolderAsChapterSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  static Future<void> renameFolder(
    BuildContext context,
    VideoFolderEntity folder,
  ) async {
    final cubit = context.read<VideoBankCubit>();
    final newName = await RenameFolderDialog.show(
      context,
      currentName: folder.name,
    );
    if (!context.mounted) return;
    if (newName != null && newName.trim().isNotEmpty) {
      await cubit.renameFolder(folder.id, newName);
    }
  }

  static Future<void> deleteFolder(
    BuildContext context,
    VideoFolderEntity folder,
  ) async {
    final cubit = context.read<VideoBankCubit>();
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteFolderConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed == true) {
      await cubit.deleteFolder(folder.id);
    }
  }

  static Future<void> uploadVideo(
    BuildContext context,
    String? currentFolderName,
  ) async {
    await UploadVideoToBankDialog.show(
      context,
      currentFolderName: currentFolderName,
    );
  }

  static Future<void> previewVideo(
    BuildContext context,
    LibraryVideoEntity video,
  ) async {
    final cubit = context.read<VideoBankCubit>();
    await VideoPreviewDialog.show(
      context,
      videoId: video.id,
      videoTitle: video.title,
      cubit: cubit,
    );
  }

  static Future<void> moveVideo(
    BuildContext context,
    LibraryVideoEntity video,
  ) async {
    final cubit = context.read<VideoBankCubit>();
    final loaded = cubit.currentLoadedState;
    if (loaded == null) return;

    // Fetch all folders to let teacher pick destination
    await cubit.loadFolder(); // ensures state is fresh
    if (!context.mounted) return;
    final targetFolderId = await MoveVideoDialog.show(
      context,
      allFolders: loaded.folders,
      currentFolderId: video.folderId,
    );

    if (targetFolderId != null && context.mounted) {
      final actualTargetId =
          targetFolderId == '__ROOT__' ? null : targetFolderId;
      final success = await cubit.moveVideo(
        videoId: video.id,
        targetFolderId: actualTargetId,
      );
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.videoMovedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  static Future<void> renameVideo(
    BuildContext context,
    LibraryVideoEntity video,
  ) async {
    final l10n = context.l10n;
    final controller = TextEditingController(text: video.title);
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameVideo),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l10n.videoTitleHint),
            validator: (v) =>
                v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          AppButton(
            text: l10n.save,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(ctx).pop(true);
              }
            },
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<VideoBankCubit>().renameVideo(
            videoId: video.id,
            newTitle: controller.text.trim(),
          );
    }
  }

  static Future<void> deleteVideo(
    BuildContext context,
    LibraryVideoEntity video,
  ) async {
    final cubit = context.read<VideoBankCubit>();
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteVideoConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (confirmed == true) {
      await cubit.deleteVideo(video.id);
    }
  }

  static Future<void> syncVideo(
    BuildContext context,
    LibraryVideoEntity video,
  ) async {
    final l10n = context.l10n;
    final cubit = context.read<VideoBankCubit>();
    final success = await cubit.syncVideo(video.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? l10n.videoStatusRefreshed : l10n.videoStatusRefreshFailed,
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  static Future<void> addToCourse(
    BuildContext context,
    LibraryVideoEntity video,
  ) async {
    final contentEntity = ContentEntity(
      id: video.id,
      tenantId: video.tenantId,
      title: video.title,
      description: video.description,
      type: ContentType.video,
      status: ContentStatus.published,
      videoProvider: video.provider,
      videoProviderId: video.providerVideoId,
      videoId: video.id,
      createdAt: video.createdAt,
      updatedAt: video.updatedAt,
      assignedGroupNames: video.assignedGroupNames,
    );

    final cubit = context.read<VideoBankCubit>();
    await AddToCourseFlow.show(context, video: contentEntity);
    if (!context.mounted) return;
    await cubit.loadFolder(forceRefresh: true);
  }
}
