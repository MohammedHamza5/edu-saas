import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/tenant_registry.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_state.dart';
import '../../../notifications/presentation/widgets/notification_badge_button.dart';
import '../widgets/sat_domain_mastery_card.dart';

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
              context.go(AppRouter.login);
            },
            child: Text(context.l10n.logout),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    NotificationsState? notifState;
    try {
      notifState = context.watch<NotificationsCubit>().state;
    } catch (_) {}
    final unreadNotifs =
        notifState is NotificationsLoaded ? notifState.unreadCount : 0;

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
            onPressed: () => context.go(AppRouter.studentNotifications),
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
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - value)),
                child: child,
              ),
            );
          },
          child: SingleChildScrollView(
            padding: context.responsivePagePadding,
            child: ResponsiveContainer(
              maxWidth: ResponsiveBreakpoints.maxContentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Academic Hero Banner
                  AcademicHeroBanner(
                    title: context.l10n.welcomeStudentHeader(branding.localizedBrandName(context)),
                    subtitle: context.l10n.studentHeroSubtitle(
                      branding.localizedTeacherName(context),
                      branding.localizedAcademicTrack(context),
                    ),
                    academicTrack: branding.localizedAcademicTrack(context),
                    badgeText: context.l10n.americanMathAcademy,
                  ),
                const SizedBox(height: AppSpacing.s24),

                // 2. Responsive Stat Cards Grid
                ResponsiveGrid(
                  mobileColumns: 2,
                  tabletColumns: 2,
                  desktopColumns: 4,
                  spacing: AppSpacing.s16,
                  runSpacing: AppSpacing.s16,
                  children: [
                    AppCard(
                      variant: AppCardVariant.elevated,
                      padding: const EdgeInsets.all(AppSpacing.s12),
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
                                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                ),
                                child: const Icon(Icons.school_rounded, color: AppColors.primary, size: 18),
                              ),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.l10n.active,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Text(context.l10n.academicTrackLabel,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: AppSpacing.s4),
                          Text(branding.academicTrack,
                              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    AppCard(
                      variant: AppCardVariant.elevated,
                      padding: const EdgeInsets.all(AppSpacing.s12),
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
                                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                ),
                                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 18),
                              ),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'V1',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Text(context.l10n.assessmentSystemLabel,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: AppSpacing.s4),
                          const Text('SAT & EST',
                              style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    AppCard(
                      variant: AppCardVariant.elevated,
                      padding: const EdgeInsets.all(AppSpacing.s12),
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
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                ),
                                child: const Icon(Icons.event_available_rounded, color: AppColors.success, size: 18),
                              ),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    context.l10n.excellentStatus,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Text(context.l10n.attendanceRateLabel,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: AppSpacing.s4),
                          const Text('100%', style: AppTypography.statFigureLarge),
                        ],
                      ),
                    ),
                    AppCard(
                      variant: AppCardVariant.elevated,
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      onTap: () => context.go(AppRouter.studentNotifications),
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
                                  color: AppColors.primaryLight.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                ),
                                child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 18),
                              ),
                              Flexible(
                                child: Text(
                                  unreadNotifs > 0
                                      ? context.l10n.newNotificationsCount(unreadNotifs)
                                      : context.l10n.navNotifications,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Text(context.l10n.notificationsCenter,
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                          const SizedBox(height: AppSpacing.s4),
                          Text(unreadNotifs > 0 ? '$unreadNotifs' : context.l10n.active, style: AppTypography.statFigureLarge),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.s24),

                // 2.5 College Board 4-Domain Mastery & Target 800 Card
                const SatDomainMasteryCard(),

                const SizedBox(height: AppSpacing.s24),

                // 3. Responsive Action Cards Grid (1 col mobile, 2 col tablet/desktop)
                ResponsiveGrid(
                  mobileColumns: 1,
                  tabletColumns: 2,
                  desktopColumns: 2,
                  spacing: AppSpacing.s16,
                  runSpacing: AppSpacing.s16,
                  children: [
                    AppCard(
                      variant: AppCardVariant.elevated,
                      onTap: () => context.go(AppRouter.studentAssignments),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.assignment_rounded, color: AppColors.primary),
                          ),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.assignmentsAndSubmissions,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(context.l10n.studentAssignmentsDesc,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    AppCard(
                      variant: AppCardVariant.elevated,
                      onTap: () => context.go(AppRouter.studentExams),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.quiz_rounded, color: AppColors.primary),
                          ),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.myExamsAndAssessments,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(context.l10n.myExamsAndAssessmentsDesc,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    AppCard(
                      variant: AppCardVariant.elevated,
                      onTap: () => context.go(AppRouter.studentNotifications),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.campaign_rounded, color: AppColors.primary),
                          ),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.teacherAnnouncements,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(context.l10n.teacherAnnouncementsDesc,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                    AppCard(
                      variant: AppCardVariant.elevated,
                      onTap: () => context.go(AppRouter.studentAttendance),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                          ),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(context.l10n.attendanceRecord,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(context.l10n.attendanceRecordDesc,
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
}
}
