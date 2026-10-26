import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Reusable confirmation dialogs for teacher exam actions (unlink, unpublish, delete/archive)
abstract final class TeacherExamsConfirmationDialogs {
  /// Confirmation dialog before unlinking an exam from a lecture
  static Future<bool> confirmUnlink(
    BuildContext context, {
    required String examTitle,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.confirmUnlinkDialogTitle),
        content: Text(ctx.l10n.confirmUnlinkDialogBody(examTitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancelAction),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.confirmUnlinkButton),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Confirmation dialog before unpublishing an active exam version
  static Future<bool> confirmUnpublish(
    BuildContext context, {
    required String examTitle,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.visibility_off_outlined,
              color: AppColors.warning,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(ctx.l10n.confirmUnpublishExamTitle),
            ),
          ],
        ),
        content: Text(ctx.l10n.confirmUnpublishExamBody(examTitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.confirmUnpublishButton),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Confirmation dialog before deleting or archiving an exam
  static Future<bool> confirmDeleteOrArchive(
    BuildContext context, {
    required String examTitle,
    required int attemptsCount,
  }) async {
    final hasAttempts = attemptsCount > 0;
    final title = hasAttempts
        ? context.l10n.archiveOrDeleteExamDialogTitle
        : context.l10n.deleteExamDialogTitle;
    final body = hasAttempts
        ? context.l10n.archiveOrDeleteExamDialogBody(examTitle, attemptsCount)
        : context.l10n.deleteExamDialogBody(examTitle);
    final confirmBtnText = hasAttempts
        ? context.l10n.archiveExamConfirmButton
        : context.l10n.deleteExamConfirmButton;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              hasAttempts ? Icons.archive_outlined : Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmBtnText),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
