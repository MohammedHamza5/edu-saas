import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/tenant_registry.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';
import '../../../groups/presentation/widgets/interactive_group_card.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_state.dart';
import '../../../students/presentation/cubit/students_cubit.dart';
import '../../../students/presentation/cubit/students_state.dart';
import '../cubit/teacher_dashboard_cubit.dart';
import '../cubit/teacher_dashboard_state.dart';
import '../widgets/demo_sandbox_banner.dart';
import '../widgets/teacher_action_radar_cards.dart';
import '../widgets/teacher_dashboard_quick_actions_hub.dart';
import '../widgets/teacher_dashboard_services_grid.dart';
import '../../../../core/config/tenant_resolver.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    // PERF: Use silentRefresh for stale-while-revalidate.
    // Shows cached data instantly, refreshes in background only if stale.
    // Falls back to full load if no cached data exists (first visit).

    // 1. Notifications
    try {
      final cubit = context.read<NotificationsCubit>();
      if (cubit.state is NotificationsLoaded ||
          cubit.state is NotificationsInitial) {
        cubit.silentRefresh();
      } else {
        cubit.loadNotifications();
      }
    } catch (_) {}

    // 2. Groups
    try {
      final cubit = context.read<GroupsCubit>();
      if (cubit.state is GroupsLoaded) {
        cubit.silentRefresh();
      } else {
        cubit.loadGroups();
      }
    } catch (_) {}

    // 3. Students
    try {
      final cubit = context.read<StudentsCubit>();
      if (cubit.state is StudentsLoaded || cubit.state is StudentsInitial) {
        cubit.silentRefresh();
      } else {
        cubit.loadStudents();
      }
    } catch (_) {}

    // 4. Teacher Radar Alerts
    try {
      final cubit = context.read<TeacherDashboardCubit>();
      if (cubit.state is TeacherDashboardInitial) {
        final authState = context.read<AuthCubit>().state;
        final teacherId = (authState is AuthAuthenticated)
            ? authState.user.id
            : AppCache.currentUserId;
        if (teacherId != null && teacherId.isNotEmpty) {
          cubit.loadRadarAlerts(teacherId);
        }
      }
    } catch (_) {}
  }

  GroupsState? get _groupsState {
    try {
      return context.watch<GroupsCubit>().state;
    } catch (_) {
      return null;
    }
  }

  StudentsState? get _studentsState {
    try {
      return context.watch<StudentsCubit>().state;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamic Student Stats
    final studentsState = _studentsState;
    final totalStudents = studentsState is StudentsLoaded
        ? '${studentsState.students.length}'
        : studentsState is StudentsLoading
        ? '—'
        : '—';
    final pendingStudentsCount = studentsState is StudentsLoaded
        ? studentsState.pendingCount
        : 0;

    // Dynamic Groups Stats
    final groupsState = _groupsState;
    final totalGroups = groupsState is GroupsLoaded
        ? '${groupsState.groups.length}'
        : '—';
    final groupsTracks =
        groupsState is GroupsLoaded && groupsState.groups.isNotEmpty
        ? groupsState.groups.map((g) => g.level).toSet().join(' • ')
        : '';

    // Dynamic Tenant Branding
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: context.responsivePagePadding,
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // VIP Demo Banner (Only visible in Demo Sandbox Mode)
              if (TenantResolver.isDemoMode())
                DemoSandboxBanner(supportPhone: branding.supportPhone),

              // 1. Academic Command Center Header (No AppBar - Web SaaS Style)
              AcademicHeroBanner(
                title:
                    '${context.l10n.academicDashboardTitle} • ${branding.localizedTeacherName(context)}',
                subtitle: context.l10n.teacherDashboardSubtitle,
                academicTrack: branding.localizedAcademicTrack(context),
                badgeText: branding.localizedTagline(context),
              ),

              const SizedBox(height: AppSpacing.s12),

              const SizedBox(height: AppSpacing.s16),

              // Daily Quick Actions Hub (High Priority Actions)
              TeacherDashboardQuickActionsHub(
                pendingStudentsCount: pendingStudentsCount,
              ),

              const SizedBox(height: AppSpacing.s24),

              // 2. Teacher Action Radar & Early Warning Alerts (Isolated Rebuild Section)
              TeacherActionRadarSection(
                groupsState: groupsState,
                pendingCount: pendingStudentsCount,
              ),

              const SizedBox(height: AppSpacing.s32),

              // 3. Header
              Text(
                context.l10n.groupsAndStudentsOverview,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // 4. Responsive Stat Cards Grid (Connected to Cubits)
              ResponsiveGrid(
                mobileColumns: 2,
                tabletColumns: 2,
                desktopColumns: 4,
                spacing: AppSpacing.s16,
                runSpacing: AppSpacing.s16,
                children: [
                  // Card 1: Total Students
                  AppCard(
                    variant: AppCardVariant.elevated,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    onTap: () => context.go(AppRoutes.studentsList),
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
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                              ),
                              child: const Icon(
                                Icons.people_alt_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: pendingStudentsCount > 0
                                      ? AppColors.warningLight
                                      : AppColors.successLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  pendingStudentsCount > 0
                                      ? context.l10n.pendingLabel(
                                          pendingStudentsCount,
                                        )
                                      : context.l10n.allActive,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: pendingStudentsCount > 0
                                        ? AppColors.warning
                                        : AppColors.success,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          context.l10n.totalStudents,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          totalStudents,
                          style: AppTypography.statFigureLarge,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          context.l10n.viewStudentsAndApprovals,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Card 2: Active Groups
                  AppCard(
                    variant: AppCardVariant.elevated,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    onTap: () => context.go(AppRoutes.groupsList),
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
                                color: AppColors.primaryLight.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                              ),
                              child: const Icon(
                                Icons.category_rounded,
                                color: AppColors.primary,
                                size: 18,
                              ),
                            ),
                            Flexible(
                              child: Text(
                                groupsTracks,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          context.l10n.activeGroups,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(totalGroups, style: AppTypography.statFigureLarge),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          context.l10n.clickToManageAndControl,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Card 3: Attendance
                  AppCard(
                    variant: AppCardVariant.elevated,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    onTap: () => context.go(AppRoutes.teacherAttendance),
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
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: AppColors.success,
                                size: 18,
                              ),
                            ),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.successLight,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  context.l10n.excellentStatus,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          context.l10n.cumulativeAttendanceRate,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          context.l10n.tapToView,
                          style: AppTypography.statFigureLarge,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          context.l10n.lectureWatchingAnalytics,
                          style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Card 4: Notifications Center (Isolated Rebuild Card)
                  const TeacherNotificationsStatCard(),
                ],
              ),

              const SizedBox(height: AppSpacing.s32),

              // 5. Section: All Platform Services (Direct 1-Click Screen Access)
              const TeacherDashboardServicesGrid(),

              // 6. Section: Active Groups List & Fast Navigation
              if (groupsState is GroupsLoaded &&
                  groupsState.groups.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s32),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 450;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.layers_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  context.l10n.currentlyActiveStudyGroups,
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
                          const SizedBox(height: AppSpacing.s8),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton.icon(
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(context.l10n.addGroup),
                              onPressed: () => CreateGroupDialog.show(context),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(
                                Icons.layers_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              Expanded(
                                child: Text(
                                  context.l10n.currentlyActiveStudyGroups,
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
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        TextButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: Text(context.l10n.addGroup),
                          onPressed: () => CreateGroupDialog.show(context),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s12),
                ResponsiveGrid(
                  mobileColumns: 1,
                  tabletColumns: 2,
                  desktopColumns: 3,
                  spacing: AppSpacing.s16,
                  runSpacing: AppSpacing.s16,
                  children: groupsState.groups
                      .map(
                        (group) => InteractiveGroupCard(
                          group: group,
                          onTap: () => context.push(
                            '${AppRoutes.groupsList}/${group.id}',
                            extra: group,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],

              const SizedBox(height: AppSpacing.s48),
            ],
          ),
        ),
      ),
    );
  }
}

