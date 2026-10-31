import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// Group Operations Quick Action Bar providing one-tap navigation to lessons, assignments, exams, and announcements.
class GroupServicesActionBar extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupServicesActionBar({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.dashboard_customize_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  context.l10n.groupServicesAndTools,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(
                  Icons.folder_shared_rounded,
                  size: 16,
                ),
                label: Text(context.l10n.manageLessons),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => context.go(
                  '${AppRoutes.teacherGroupContent.replaceAll(':groupId', groupId)}?name=${Uri.encodeComponent(groupName)}',
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(
                  Icons.assignment_rounded,
                  size: 16,
                ),
                label: Text(
                  context.l10n.assignmentsAndSubmissions,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => context.go(
                  '${AppRoutes.teacherGroupAssignments.replaceAll(':groupId', groupId)}?name=${Uri.encodeComponent(groupName)}',
                ),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.quiz_rounded, size: 16),
                label: Text(context.l10n.examsBank),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => context.go(
                  '${AppRoutes.teacherGroupExams.replaceAll(':groupId', groupId)}?name=${Uri.encodeComponent(groupName)}',
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(
                  Icons.campaign_rounded,
                  size: 16,
                ),
                label: Text(context.l10n.sendGroupAnnouncement),
                onPressed: () => context.go(
                  '${AppRoutes.sendAnnouncement}?groupId=$groupId',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
