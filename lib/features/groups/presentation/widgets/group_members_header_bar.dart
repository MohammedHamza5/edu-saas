import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'add_member_dialog.dart';

/// Header bar displaying group members count with "Add Member" and "Record Attendance" action buttons.
class GroupMembersHeaderBar extends StatelessWidget {
  final int totalMembersCount;
  final String groupId;
  final Set<String> existingMemberIds;

  const GroupMembersHeaderBar({
    super.key,
    required this.totalMembersCount,
    required this.groupId,
    required this.existingMemberIds,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.s12,
      runSpacing: AppSpacing.s8,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 250),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.people_alt_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Flexible(
                child: Text(
                  context.l10n.groupMembersCountHeader(totalMembersCount),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          icon: const Icon(
            Icons.person_add_alt_1_rounded,
            size: 16,
          ),
          label: Text(context.l10n.addMemberAction),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppSpacing.radiusSmall,
              ),
            ),
          ),
          onPressed: () => AddMemberDialog.show(
            context,
            groupId,
            existingMemberIds: existingMemberIds,
          ),
        ),
        ElevatedButton.icon(
          icon: const Icon(Icons.fact_check_rounded, size: 16),
          label: Text(context.l10n.recordAttendanceAction),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppSpacing.radiusSmall,
              ),
            ),
          ),
          onPressed: () => context.push(
            '${AppRoutes.teacherAttendance}?groupId=$groupId',
          ),
        ),
      ],
    );
  }
}
