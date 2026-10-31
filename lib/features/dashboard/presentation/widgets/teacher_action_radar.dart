import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../dashboard/presentation/cubit/teacher_dashboard_state.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import 'teacher_action_detail_modal.dart';
import 'teacher_test_prep_cohorts_list.dart';

/// رادار المتابعة والإنذار المبكر للمعلم
/// يجيب عن الأسئلة الأربعة المصيرية بنظرة واحدة:
/// 1. مين مشافش المحاضرة؟
/// 2. مين مسلّمش الواجب؟
/// 3. مين محتاج تدخل لضعف السكور في الكويز؟
/// 4. مين بانتظار القبول في المجموعات؟
class TeacherActionRadar extends StatelessWidget {
  final TeacherDashboardState? alertsState;
  final GroupsState? groupsState;
  final int pendingCount;
  final VoidCallback? onRefresh;

  const TeacherActionRadar({
    super.key,
    required this.alertsState,
    this.groupsState,
    this.pendingCount = 0,
    this.onRefresh,
  });

  void _showActionDetailModal(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<Map<String, String>> items,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    TeacherActionDetailModal.show(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      items: items,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Unwatched Videos
    final unwatchedStudents = alertsState is TeacherDashboardLoaded
        ? (alertsState as TeacherDashboardLoaded).alerts.unwatchedVideos
              .map(
                (s) => {'name': s.name, 'group': s.group, 'detail': s.detail},
              )
              .toList()
        : <Map<String, String>>[];

    // 2. Unsubmitted Drill Homework
    final unsubmittedHomework = alertsState is TeacherDashboardLoaded
        ? (alertsState as TeacherDashboardLoaded).alerts.overdueAssignments
              .map(
                (s) => {'name': s.name, 'group': s.group, 'detail': s.detail},
              )
              .toList()
        : <Map<String, String>>[];

    // 3. Needs Academic Intervention (Low Scores)
    final lowScoreAlerts = alertsState is TeacherDashboardLoaded
        ? (alertsState as TeacherDashboardLoaded).alerts.lowScores
              .map(
                (s) => {'name': s.name, 'group': s.group, 'detail': s.detail},
              )
              .toList()
        : <Map<String, String>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Bar
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.radar_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.radarInstantTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    context.l10n.radarInstantSubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s16),

        // 4 Critical Action Radar Cards
        ResponsiveGrid(
          mobileColumns: 2,
          tabletColumns: 2,
          desktopColumns: 4,
          spacing: AppSpacing.s12,
          runSpacing: AppSpacing.s12,
          children: [
            // Alert 1: Lecture Watch Alert
            _buildRadarActionCard(
              context,
              title: context.l10n.radarLectureViewsTitle,
              count: '${unwatchedStudents.length}',
              subtitle: context.l10n.radarLectureViewsSubtitle,
              icon: Icons.play_lesson_rounded,
              color: AppColors.error,
              isCritical: unwatchedStudents.isNotEmpty,
              onTap: () => _showActionDetailModal(
                context,
                title: context.l10n.radarLectureModalTitle,
                subtitle: context.l10n.radarLectureModalSubtitle,
                icon: Icons.play_lesson_rounded,
                color: AppColors.error,
                items: unwatchedStudents,
                actionLabel: context.l10n.radarSendWatchAlert,
                onAction: () => context.push(AppRoutes.sendAnnouncement),
              ),
            ),

            // Alert 2: Drill Homework Unsubmitted
            _buildRadarActionCard(
              context,
              title: context.l10n.radarDrillSubmissionsTitle,
              count: '${unsubmittedHomework.length}',
              subtitle: context.l10n.radarDrillSubmissionsSubtitle,
              icon: Icons.assignment_late_rounded,
              color: AppColors.warning,
              isCritical: unsubmittedHomework.isNotEmpty,
              onTap: () => _showActionDetailModal(
                context,
                title: context.l10n.radarDrillModalTitle,
                subtitle: context.l10n.radarDrillModalSubtitle,
                icon: Icons.assignment_late_rounded,
                color: AppColors.warning,
                items: unsubmittedHomework,
                actionLabel: context.l10n.radarOpenHomeworkList,
                onAction: () => context.push(AppRoutes.teacherAssignments),
              ),
            ),

            // Alert 3: Score Warning Alert
            _buildRadarActionCard(
              context,
              title: context.l10n.radarScoreWarningTitle,
              count: '${lowScoreAlerts.length}',
              subtitle: context.l10n.radarScoreWarningSubtitle,
              icon: Icons.trending_down_rounded,
              color: const Color(0xFF8B5CF6), // Royal purple
              isCritical: lowScoreAlerts.isNotEmpty,
              onTap: () => _showActionDetailModal(
                context,
                title: context.l10n.radarScoreModalTitle,
                subtitle: context.l10n.radarScoreModalSubtitle,
                icon: Icons.trending_down_rounded,
                color: const Color(0xFF8B5CF6),
                items: lowScoreAlerts,
                actionLabel: context.l10n.radarReviewPerformance,
                onAction: () => context.push(AppRoutes.studentsList),
              ),
            ),

            // Alert 4: Pending Admissions
            _buildRadarActionCard(
              context,
              title: context.l10n.radarPendingJoinTitle,
              count: '$pendingCount',
              subtitle: pendingCount > 0
                  ? context.l10n.radarPendingStudentsCount
                  : context.l10n.radarNoPendingRequests,
              icon: Icons.person_add_alt_1_rounded,
              color: AppColors.primary,
              isCritical: pendingCount > 0,
              onTap: () => context.push(AppRoutes.pendingStudents),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.s24),

        // Study Groups Section Header (Dynamic for real teachers, academic preview fallback for tests)
        Row(
          children: [
            const Icon(Icons.stars_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                groupsState != null
                    ? context.l10n.navGroups
                    : context.l10n.testPrepCohortsTitle,
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
          groupsState is GroupsLoaded
              ? (groupsState as GroupsLoaded).groups.isEmpty
                    ? context.l10n.noGroupsAvailable
                    : '${(groupsState as GroupsLoaded).groups.length} ${context.l10n.activeGroups}'
              : groupsState != null
              ? context.l10n.navGroups
              : context.l10n.testPrepCohortsSubtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.s16),

        // 5 Test-Prep Cohort Specialized Cards
        TeacherTestPrepCohortsList(
          groupsState: groupsState,
        ),
      ],
    );
  }

  Widget _buildRadarActionCard(
    BuildContext context, {
    required String title,
    required String count,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isCritical,
    required VoidCallback onTap,
  }) {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (isCritical)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.radarUrgentAlert,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count,
            style: AppTypography.statFigureLarge.copyWith(
              color: isCritical ? color : AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
