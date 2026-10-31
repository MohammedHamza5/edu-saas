import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_grid.dart';

/// Complete services grid presenting all 10 academic and operational tools
/// available to teachers with 1-click navigation.
class TeacherDashboardServicesGrid extends StatelessWidget {
  const TeacherDashboardServicesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final services = [
      _ServiceItem(
        icon: Icons.people_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryLight,
        title: l10n.manageStudentsAndApprovals,
        description: l10n.manageStudentsDesc,
        route: AppRoutes.studentsList,
      ),
      _ServiceItem(
        icon: Icons.groups_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryLight,
        title: l10n.manageStudyGroups,
        description: l10n.manageGroupsDesc,
        route: AppRoutes.groupsList,
      ),
      _ServiceItem(
        icon: Icons.fact_check_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryLight,
        title: l10n.recordDailyAttendance,
        description: l10n.recordAttendanceDesc,
        route: AppRoutes.teacherAttendance,
      ),
      _ServiceItem(
        icon: Icons.campaign_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryLight,
        title: l10n.sendNoticeOrBroadcast,
        description: l10n.sendNoticeDesc,
        route: AppRoutes.sendAnnouncement,
      ),
      _ServiceItem(
        icon: Icons.auto_stories_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryLight,
        title: l10n.libraryAndAcademicContent,
        description: l10n.uploadPdfHandoutsDesc,
        route: AppRoutes.teacherContent,
      ),
      _ServiceItem(
        icon: Icons.video_library_rounded,
        iconColor: const Color(0xFF6366F1),
        iconBgColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
        title: l10n.videoLibraryCardTitle,
        description: l10n.videoLibraryCardDesc,
        route: AppRoutes.teacherVideos,
      ),
      _ServiceItem(
        icon: Icons.functions_rounded,
        iconColor: const Color(0xFF0EA5E9),
        iconBgColor: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
        title: l10n.centralQuestionBankTitle,
        description: l10n.centralQuestionBankDesc,
        route: AppRoutes.questionBank,
      ),
      _ServiceItem(
        icon: Icons.quiz_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryLight,
        title: l10n.interactiveExamsBank,
        description: l10n.interactiveExamsDesc,
        route: AppRoutes.teacherExams,
      ),
      _ServiceItem(
        icon: Icons.assignment_rounded,
        iconColor: AppColors.warning,
        iconBgColor: AppColors.warningLight.withValues(alpha: 0.2),
        title: l10n.assignmentsAndGradingTitle,
        description: l10n.assignmentsAndGradingDesc,
        route: AppRoutes.teacherAssignments,
      ),
      _ServiceItem(
        icon: Icons.settings_suggest_rounded,
        iconColor: AppColors.primary,
        iconBgColor: AppColors.primaryLight,
        title: l10n.settingsServiceCardTitle,
        description: l10n.settingsServiceCardDesc,
        route: AppRoutes.teacherSettings,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.dashboard_customize_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                l10n.academicServicesAndSections,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.directAccessAllTools,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // 10 Platform Hub Cards Grid
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s16,
          children: services.map((item) => _ServiceCard(item: item)).toList(),
        ),
      ],
    );
  }
}

class _ServiceItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String description;
  final String route;

  const _ServiceItem({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.description,
    required this.route,
  });
}

class _ServiceCard extends StatelessWidget {
  final _ServiceItem item;

  const _ServiceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.elevated,
      onTap: () => context.go(item.route),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.iconColor),
          ),
          const SizedBox(width: AppSpacing.s16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
