import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/tenant_registry.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
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
import '../widgets/teacher_action_radar.dart';

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
        final authClient = SupabaseService.client.auth;
        final teacherId = authClient.currentUser?.id;
        if (teacherId != null) {
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

  NotificationsState? get _notificationsState {
    try {
      return context.watch<NotificationsCubit>().state;
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

    // Dynamic Notifications Stats
    final notifState = _notificationsState;
    final unreadNotifs = notifState is NotificationsLoaded
        ? notifState.unreadCount
        : 0;

    // Dynamic Tenant Branding
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    // Dynamic Teacher Alerts
    final alertsState = (() {
      try {
        return context.watch<TeacherDashboardCubit>().state;
      } catch (_) {
        return null;
      }
    })();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: context.responsivePagePadding,
        child: ResponsiveContainer(
          maxWidth: ResponsiveBreakpoints.maxContentWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              _buildQuickActionsHub(context, pendingStudentsCount),

              const SizedBox(height: AppSpacing.s24),

              // 2. Teacher Action Radar & Early Warning Alerts
              TeacherActionRadar(
                alertsState: alertsState,
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

                  // Card 4: Notifications Center
                  AppCard(
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
                                color: AppColors.warningLight.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
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
                                    ? context.l10n.newNotificationsCount(
                                        unreadNotifs,
                                      )
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
                          unreadNotifs > 0
                              ? '$unreadNotifs'
                              : context.l10n.active,
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
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s32),

              // 5. Section: All Platform Services (Direct 1-Click Screen Access)
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
                      context.l10n.academicServicesAndSections,
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
                context.l10n.directAccessAllTools,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // 8 Platform Hub Cards Grid
              ResponsiveGrid(
                mobileColumns: 1,
                tabletColumns: 2,
                desktopColumns: 2,
                spacing: AppSpacing.s16,
                runSpacing: AppSpacing.s16,
                children: [
                  // Service 1: Students Management
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.studentsList),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.people_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.manageStudentsAndApprovals,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.manageStudentsDesc,
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
                  ),

                  // Service 2: Groups Management
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.groupsList),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.groups_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.manageStudyGroups,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.manageGroupsDesc,
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
                  ),

                  // Service 3: Attendance
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.teacherAttendance),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.fact_check_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.recordDailyAttendance,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.recordAttendanceDesc,
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
                  ),

                  // Service 4: Announcement
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.sendAnnouncement),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.campaign_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.sendNoticeOrBroadcast,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.sendNoticeDesc,
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
                  ),

                  // Service 5: Course Builder & Lessons
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.teacherContent),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.libraryAndAcademicContent,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.uploadPdfHandoutsDesc,
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
                  ),

                  // Service 6: Video & Media Bank
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.teacherVideos),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.video_library_rounded,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.videoLibraryCardTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.videoLibraryCardDesc,
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
                  ),

                  // Service 7: Central Question Bank
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.questionBank),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.functions_rounded,
                            color: Color(0xFF0EA5E9),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.centralQuestionBankTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.centralQuestionBankDesc,
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
                  ),

                  // Service 8: Exams & Assessments
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.teacherExams),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.quiz_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.interactiveExamsBank,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.interactiveExamsDesc,
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
                  ),

                  // Service 9: Assignments & Grading
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.teacherAssignments),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.warningLight.withValues(
                              alpha: 0.2,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_rounded,
                            color: AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.assignmentsAndGradingTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.assignmentsAndGradingDesc,
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
                  ),

                  // Service 10: Platform & Academy Settings
                  AppCard(
                    variant: AppCardVariant.elevated,
                    onTap: () => context.go(AppRoutes.teacherSettings),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            Icons.settings_suggest_rounded,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.settingsServiceCardTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.settingsServiceCardDesc,
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
                  ),
                ],
              ),

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

  Widget _buildQuickActionsHub(BuildContext context, int pendingCount) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: const Icon(
                Icons.bolt_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dailyQuickActionsTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    l10n.dailyQuickActionsSubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 720;

            final cardLesson = _QuickActionCard(
              title: l10n.quickActionUploadLessonTitle,
              description: l10n.quickActionUploadLessonDesc,
              icon: Icons.video_call_rounded,
              accentColor: const Color(0xFF10B981),
              onTap: () => context.go(AppRoutes.teacherContent),
            );

            final cardAssessment = _QuickActionCard(
              title: l10n.quickActionAssessmentTitle,
              description: l10n.quickActionAssessmentDesc,
              icon: Icons.quiz_rounded,
              accentColor: const Color(0xFF3B82F6),
              onTap: () => _showCreateAssessmentChoice(context),
            );

            final cardPending = _QuickActionCard(
              title: l10n.quickActionPendingStudentsTitle,
              description: l10n.quickActionPendingStudentsDesc,
              icon: Icons.person_add_rounded,
              accentColor: const Color(0xFFF59E0B),
              badgeText: pendingCount > 0
                  ? l10n.pendingStudentsCountBadge(pendingCount)
                  : l10n.noPendingStudentsBadge,
              isBadgeWarning: pendingCount > 0,
              onTap: () => context.go(AppRoutes.pendingStudents),
            );

            if (isDesktop) {
              return Row(
                children: [
                  Expanded(child: cardLesson),
                  const SizedBox(width: AppSpacing.s14),
                  Expanded(child: cardAssessment),
                  const SizedBox(width: AppSpacing.s14),
                  Expanded(child: cardPending),
                ],
              );
            }

            return Column(
              children: [
                cardLesson,
                const SizedBox(height: AppSpacing.s10),
                cardAssessment,
                const SizedBox(height: AppSpacing.s10),
                cardPending,
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.s12),
        // Secondary Action Links
        Wrap(
          spacing: AppSpacing.s10,
          runSpacing: AppSpacing.s8,
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.group_add_rounded, size: 16),
              label: Text(
                l10n.createNewGroup,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
              ),
              onPressed: () => CreateGroupDialog.show(context),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.campaign_rounded, size: 16),
              label: Text(
                l10n.sendAnnouncementToStudents,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0284C7),
                side: const BorderSide(color: Color(0xFF38BDF8)),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
              ),
              onPressed: () => context.go(AppRoutes.sendAnnouncement),
            ),
          ],
        ),
      ],
    );
  }

  void _showCreateAssessmentChoice(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_add,
                      color: Color(0xFF3B82F6),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.createAssessmentChoiceTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.createAssessmentChoiceSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Option 1: Assignment
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.teacherAssignments);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_document,
                          color: Color(0xFF6366F1),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.createHomeworkAction,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.createHomeworkActionDesc,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Option 2: Exam / Quiz
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(ctx);
                  context.go(AppRoutes.teacherExams);
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0284C7).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.quiz_rounded,
                          color: Color(0xFF0284C7),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.createExamOrQuizAction,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l10n.createExamOrQuizActionDesc,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final String? badgeText;
  final bool isBadgeWarning;

  const _QuickActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.badgeText,
    this.isBadgeWarning = false,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: _isHovered
                  ? widget.accentColor.withValues(alpha: 0.6)
                  : AppColors.border,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      border: Border.all(
                        color: widget.accentColor.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 22,
                    ),
                  ),
                  if (widget.badgeText != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isBadgeWarning
                              ? AppColors.warningLight
                              : AppColors.successLight,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSmall),
                        ),
                        child: Text(
                          widget.badgeText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: widget.isBadgeWarning
                                ? AppColors.warning
                                : AppColors.success,
                          ),
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: _isHovered
                          ? widget.accentColor
                          : AppColors.textMuted,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s14),
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
