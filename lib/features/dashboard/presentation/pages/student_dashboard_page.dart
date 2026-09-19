import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/tenant_registry.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/utils/group_slug_resolver.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/widgets/notification_badge_button.dart';
import '../cubit/student_dashboard_cubit.dart';
import '../cubit/student_dashboard_state.dart';
import '../widgets/academic_performance_card.dart';
import '../widgets/continue_learning_card.dart';
import '../widgets/urgent_tasks_radar_card.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          context.read<NotificationsCubit>().loadNotifications();
          final authState = context.read<AuthCubit>().state;
          if (authState is AuthAuthenticated) {
            context.read<StudentDashboardCubit>().loadDashboardStats(
              authState.user.id,
            );
          }
        } catch (_) {}
      }
    });
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.logoutDialogTitle),
        content: Text(context.l10n.confirmLogoutStudent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthCubit>().logout();
              context.go(AppRoutes.login);
            },
            child: Text(context.l10n.logout),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOpenContent(BuildContext context) async {
    final result = await InjectionContainer.groupsRepository.getGroups();
    if (!context.mounted) return;

    final groups = result.dataOrNull ?? [];
    if (!result.isSuccess || groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.studentNoGroupsAssigned),
          backgroundColor: AppColors.info,
        ),
      );
      return;
    }

    // Direct 1-tap navigation to the student's assigned group content
    final g = groups.first;
    final slug = GroupSlugResolver.toSlug(g.id, g.name);
    context.go(
      AppRoutes.studentGroupContent.replaceAll(':groupId', slug),
      extra: g.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.studentDashboardHeader(branding.brandName)),
        actions: [
          NotificationBadgeButton(
            onPressed: () => context.go(AppRoutes.studentNotifications),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: context.l10n.logout,
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      backgroundColor: Colors.transparent,
      body: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 12 * (1 - value)),
              child: child,
            ),
          );
        },
        child: BlocBuilder<StudentDashboardCubit, StudentDashboardState>(
          builder: (context, dashboardState) {
            if (dashboardState is StudentDashboardLoading ||
                dashboardState is StudentDashboardInitial) {
              return const Center(child: AppLoadingView.signature());
            }

            if (dashboardState is StudentDashboardError) {
              return Center(
                child: Text(
                  dashboardState.message,
                  style: const TextStyle(color: AppColors.error),
                ),
              );
            }

            final stats = (dashboardState as StudentDashboardLoaded).stats;

            return RefreshIndicator(
              onRefresh: () async {
                final authState = context.read<AuthCubit>().state;
                if (authState is AuthAuthenticated) {
                  await context.read<StudentDashboardCubit>().loadDashboardStats(
                        authState.user.id,
                        forceRefresh: true,
                      );
                }
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: context.responsivePagePadding,
              child: ResponsiveContainer(
                maxWidth: ResponsiveBreakpoints.maxContentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Academic Hero Banner
                    AcademicHeroBanner(
                      title: context.l10n.welcomeStudentHeader(
                        branding.localizedBrandName(context),
                      ),
                      subtitle: context.l10n.studentHeroSubtitle(
                        branding.localizedTeacherName(context),
                        branding.localizedAcademicTrack(context),
                      ),
                      academicTrack: branding.localizedAcademicTrack(context),
                      badgeText: stats.activeGroupName != 'No Active Group'
                          ? stats.activeGroupName
                          : context.l10n.americanMathAcademy,
                    ),
                    const SizedBox(height: AppSpacing.s16),

                    // 2. Continue Learning Hero Card (If student has a lecture in progress)
                    if (stats.continueLearningItem != null) ...[
                      ContinueLearningCard(item: stats.continueLearningItem!),
                      const SizedBox(height: AppSpacing.s16),
                    ],

                    // 3. Urgent Tasks & Deadlines Radar
                    UrgentTasksRadarCard(tasks: stats.urgentTasks),
                    const SizedBox(height: AppSpacing.s16),

                    // 4. Academic Performance Summary (Sigma Badge)
                    AcademicPerformanceCard(stats: stats),
                    const SizedBox(height: AppSpacing.s20),

                    // 5. Section Title: Quick Study Hub
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.quickAccessTitle,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.quickAccessSubtitle,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // 6. Responsive Action Cards Grid (Fast Navigation Hub)
                    ResponsiveGrid(
                      mobileColumns: 1,
                      tabletColumns: 2,
                      desktopColumns: 2,
                      spacing: AppSpacing.s16,
                      runSpacing: AppSpacing.s16,
                      children: [
                        // Card A: Study Materials & Lectures
                        AppCard(
                          variant: AppCardVariant.elevated,
                          onTap: () => _handleOpenContent(context),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.myStudyMaterials,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.myStudyMaterialsDesc,
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

                        // Card B: Homework & Submissions
                        AppCard(
                          variant: AppCardVariant.elevated,
                          onTap: () => context.go(AppRoutes.studentAssignments),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.assignment_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.assignmentsAndSubmissions,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.studentAssignmentsDesc,
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

                        // Card C: Exams & Assessments
                        AppCard(
                          variant: AppCardVariant.elevated,
                          onTap: () => context.go(AppRoutes.studentExams),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                  border: Border.all(
                                    color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.quiz_rounded,
                                  color: Color(0xFF7C3AED),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.myExamsAndAssessments,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.myExamsAndAssessmentsDesc,
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

                        // Card D: Teacher Announcements & Updates
                        AppCard(
                          variant: AppCardVariant.elevated,
                          onTap: () => context.go(AppRoutes.studentNotifications),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.campaign_rounded,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.teacherAnnouncements,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      context.l10n.teacherAnnouncementsDesc,
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
                  ],
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}
