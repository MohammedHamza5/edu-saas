import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/tenant_registry.dart';
import '../../../../core/config/tenant_resolver.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/utils/cache_manager.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_state.dart';
import '../../../students/presentation/cubit/students_cubit.dart';
import '../../../students/presentation/cubit/students_state.dart';
import '../cubit/teacher_dashboard_cubit.dart';
import '../cubit/teacher_dashboard_state.dart';
import '../widgets/demo_sandbox_banner.dart';
import '../widgets/teacher_action_radar_cards.dart';
import '../widgets/teacher_dashboard_groups_section.dart';
import '../widgets/teacher_dashboard_quick_actions_hub.dart';
import '../widgets/teacher_dashboard_services_grid.dart';
import '../widgets/teacher_dashboard_stats_grid.dart';

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

              // 4. Responsive Stat Cards Grid
              TeacherDashboardStatsGrid(
                totalStudents: totalStudents,
                pendingStudentsCount: pendingStudentsCount,
                totalGroups: totalGroups,
                groupsTracks: groupsTracks,
              ),

              const SizedBox(height: AppSpacing.s32),

              // 5. Section: All Platform Services (Direct 1-Click Screen Access)
              const TeacherDashboardServicesGrid(),

              // 6. Section: Active Groups List & Fast Navigation
              if (groupsState is GroupsLoaded)
                TeacherDashboardGroupsSection(
                  groups: groupsState.groups,
                ),

              const SizedBox(height: AppSpacing.s48),
            ],
          ),
        ),
      ),
    );
  }
}
