import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_360_entity.dart';

/// Interactive tile representing a student group with assignment/unassignment actions.
class AssignGroupTile extends StatelessWidget {
  final StudentGroupInfo group;
  final bool isAssigned;
  final VoidCallback onToggle;

  const AssignGroupTile({
    super.key,
    required this.group,
    required this.isAssigned,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          children: [
            Icon(
              isAssigned
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: isAssigned ? AppColors.success : AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isAssigned)
                    Text(
                      context.l10n.joinedDateLabel(
                        '${group.joinedAt.day}/${group.joinedAt.month}/${group.joinedAt.year}',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            AppBadge(label: group.groupLevel, variant: AppBadgeVariant.active),
            const SizedBox(width: AppSpacing.s8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isAssigned ? AppColors.error : AppColors.primary,
                side: BorderSide(
                  color: isAssigned
                      ? AppColors.error.withValues(alpha: 0.4)
                      : AppColors.primary.withValues(alpha: 0.4),
                ),
                minimumSize: const Size(64, 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: 0,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onToggle,
              child: Text(
                isAssigned
                    ? context.l10n.unassignAction
                    : context.l10n.assignActionPlus,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
