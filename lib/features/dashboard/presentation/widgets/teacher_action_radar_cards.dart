import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_state.dart';
import '../cubit/teacher_dashboard_cubit.dart';
import '../cubit/teacher_dashboard_state.dart';
import 'teacher_action_radar.dart';

/// Isolated section for TeacherActionRadar so that radar state updates
/// do not cause a full rebuild of the entire TeacherDashboardPage.
class TeacherActionRadarSection extends StatelessWidget {
  final GroupsState? groupsState;
  final int pendingCount;

  const TeacherActionRadarSection({
    super.key,
    required this.groupsState,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    TeacherDashboardCubit? cubit;
    try {
      cubit = context.read<TeacherDashboardCubit>();
    } catch (_) {}

    if (cubit == null) {
      return TeacherActionRadar(
        alertsState: null,
        groupsState: groupsState,
        pendingCount: pendingCount,
      );
    }

    return BlocBuilder<TeacherDashboardCubit, TeacherDashboardState>(
      bloc: cubit,
      buildWhen: (prev, curr) => prev != curr,
      builder: (context, alertsState) {
        return TeacherActionRadar(
          alertsState: alertsState,
          groupsState: groupsState,
          pendingCount: pendingCount,
        );
      },
    );
  }
}

/// Isolated stat card for Notifications so that unread badge increments
/// do not cause a full rebuild of the entire TeacherDashboardPage.
class TeacherNotificationsStatCard extends StatelessWidget {
  const TeacherNotificationsStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    NotificationsCubit? notifCubit;
    try {
      notifCubit = context.read<NotificationsCubit>();
    } catch (_) {}

    if (notifCubit == null) {
      return _buildCard(context, 0);
    }

    return BlocBuilder<NotificationsCubit, NotificationsState>(
      bloc: notifCubit,
      buildWhen: (prev, curr) {
        final prevCount = prev is NotificationsLoaded ? prev.unreadCount : 0;
        final currCount = curr is NotificationsLoaded ? curr.unreadCount : 0;
        return prevCount != currCount;
      },
      builder: (context, state) {
        final unreadCount = state is NotificationsLoaded
            ? state.unreadCount
            : 0;
        return _buildCard(context, unreadCount);
      },
    );
  }

  Widget _buildCard(BuildContext context, int unreadNotifs) {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s12),
      onTap: () => context.go(AppRoutes.notificationsCenter),
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
                  color: AppColors.warningLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: AppColors.warning,
                  size: 18,
                ),
              ),
              Flexible(
                child: Text(
                  unreadNotifs > 0
                      ? context.l10n.newNotificationsCount(unreadNotifs)
                      : context.l10n.studentNavNotifications,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            context.l10n.notificationsCenter,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            unreadNotifs > 0 ? '$unreadNotifs' : context.l10n.active,
            style: AppTypography.statFigureLarge,
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            context.l10n.studentAnnouncementsAndUpdates,
            style: const TextStyle(
              color: Color(0xFF38BDF8),
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
