import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../config/tenant_registry.dart';
import '../di/injection_container.dart';
import '../network/supabase_service.dart';
import '../router/app_routes.dart';
import '../utils/group_slug_resolver.dart';
import '../extensions/localized_context_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/tenant_theme_cubit.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/notifications/presentation/cubit/notifications_state.dart';
import 'adaptive_scaffold.dart';
import 'app_logo.dart';
import 'language_switcher_button.dart';

/// Permanent application shell for Student role screens.
/// Features a categorized, mathematical sidebar that stays pinned across all student pages.
class StudentShell extends StatelessWidget {
  final Widget child;
  final String currentLocation;

  const StudentShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  int _computeIndex(String path) {
    if (path == '/student' || path == '/student/') return 0;
    if (path.startsWith('/notifications') || path.startsWith('/student/notifications')) return 1;
    if (path.contains('/content')) return 2;
    if (path.startsWith('/student/assignments')) return 3;
    if (path.startsWith('/student/exams')) return 4;
    return 0;
  }

  void _onNavigationChanged(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.studentDashboard);
        break;
      case 1:
        context.go(AppRoutes.studentNotifications);
        break;
      case 2:
        _handleStudentContentNavigation(context);
        break;
      case 3:
        context.go(AppRoutes.studentAssignments);
        break;
      case 4:
        context.go(AppRoutes.studentExams);
        break;
    }
  }

  Future<void> _handleStudentContentNavigation(BuildContext context) async {
    // Fetch student's groups
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
    final role = SupabaseService.currentUserRole;
    if (role != null && role != 'student') {
      return child;
    }

    final currentIndex = _computeIndex(currentLocation);

    // Watch live unread notification count
    int unreadNotifications = 0;
    try {
      final notifState = context.watch<NotificationsCubit>().state;
      if (notifState is NotificationsLoaded) {
        unreadNotifications = notifState.unreadCount;
      }
    } catch (_) {}

    final sections = [
      // Section 1: Dashboard & Alerts
      AdaptiveSidebarSection(
        title: context.l10n.studentNavDashboard,
        destinations: [
          AdaptiveDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: context.l10n.studentNavDashboard,
            subtitle: context.l10n.studentNavDashboardSubtitle,
            tooltip: context.l10n.navDashboard,
          ),
          AdaptiveDestination(
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications_rounded,
            label: context.l10n.studentNavNotifications,
            subtitle: context.l10n.studentNavNotificationsSubtitle,
            tooltip: context.l10n.notificationsCenterTitle,
            badgeCount: unreadNotifications,
          ),
        ],
      ),

      // Section 2: Learning Courses
      AdaptiveSidebarSection(
        title: context.l10n.myCoursesTitle,
        destinations: [
          AdaptiveDestination(
            icon: Icons.school_outlined,
            selectedIcon: Icons.school_rounded,
            label: context.l10n.myCoursesTitle,
            subtitle: context.l10n.myCoursesSubtitle,
            tooltip: context.l10n.myCoursesTitle,
          ),
        ],
      ),

      // Section 3: Tasks & Exams
      AdaptiveSidebarSection(
        title: context.l10n.assignmentsListTitle,
        destinations: [
          AdaptiveDestination(
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment_rounded,
            label: context.l10n.studentNavAssignments,
            subtitle: context.l10n.studentNavAssignmentsSubtitle,
            tooltip: context.l10n.assignmentsListTitle,
          ),
          AdaptiveDestination(
            icon: Icons.quiz_outlined,
            selectedIcon: Icons.quiz_rounded,
            label: context.l10n.studentNavExams,
            subtitle: context.l10n.studentNavExamsSubtitle,
            tooltip: context.l10n.examsListTitle,
          ),
        ],
      ),
    ];

    return AdaptiveScaffold(
      currentIndex: currentIndex,
      sections: sections,
      onNavigationIndexChanged: (idx) => _onNavigationChanged(context, idx),
      sidebarHeader: _buildSidebarHeader(context),
      sidebarFooter: _buildSidebarFooter(context),
      body: child,
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    // Resolve active branding (from TenantThemeCubit or default registry)
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    return InkWell(
      onTap: () => context.go(AppRoutes.studentDashboard),
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(12),
      child: AppLogo.compact(
        size: 42,
        showName: true,
        platformName: context.l10n.studentPortal,
        subtitle: '${branding.localizedBrandName(context)} • ${context.l10n.academicMathematics}',
        nameColor: Colors.white,
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context) {
    final theme = Theme.of(context);
    final userEmail = SupabaseService.currentUser?.email ?? context.l10n.roleStudent;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFF334155).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF334155),
            child: Icon(
              Icons.school_rounded,
              size: 18,
              color: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              userEmail,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const LanguageSwitcherButton(compact: true),
          IconButton(
            icon: const Icon(Icons.logout_rounded, size: 18),
            tooltip: context.l10n.logout,
            color: const Color(0xFFF87171),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(ctx.l10n.logoutDialogTitle),
                  content: Text(ctx.l10n.logoutDialogContent),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(ctx.l10n.cancel),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(ctx.l10n.logout),
                    ),
                  ],
                ),
              );
              if (confirmed == true && context.mounted) {
                await SupabaseService.client.auth.signOut();
                if (context.mounted) {
                  context.go(AppRoutes.login);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
