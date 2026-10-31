import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';

/// Notification banner showing prerequisite locked status and exam link.
class ContentItemCardLockedBanner extends StatelessWidget {
  final ContentEntity content;

  const ContentItemCardLockedBanner({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_rounded,
            size: 16,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              context.l10n.mustPassExamToUnlock(
                content.prerequisiteExamTitle ??
                    context.l10n.prerequisiteExamBadge,
                content.prerequisitePassingScore ?? 60,
              ),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (content.prerequisiteExamId != null)
            TextButton(
              onPressed: () => context.push(AppRoutes.studentExams),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                context.l10n.takeRequiredExamAction,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
