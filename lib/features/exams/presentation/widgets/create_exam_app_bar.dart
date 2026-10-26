import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Top app bar for the exam creation/editing view, displaying title, group name,
/// and auto-saved status indicator.
class CreateExamAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isEditing;
  final String? groupName;
  final bool isAutoSaved;

  const CreateExamAppBar({
    super.key,
    required this.isEditing,
    this.groupName,
    required this.isAutoSaved,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Column(
        children: [
          Text(
            isEditing
                ? context.l10n.editDraftExamTitle
                : context.l10n.createExamTitle,
          ),
          if (groupName != null) ...[
            const SizedBox(height: 2),
            Text(
              groupName!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ],
      ),
      centerTitle: true,
      actions: [
        if (isAutoSaved)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.s12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_done_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.progressSavedAutomatically,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
