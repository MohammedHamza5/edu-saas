import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../config/tenant_registry.dart';
import '../extensions/localized_context_extension.dart';
import '../network/supabase_service.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/tenant_theme_cubit.dart';
import 'language_switcher_button.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/notifications/presentation/cubit/notifications_state.dart';
import '../../features/students/presentation/cubit/students_cubit.dart';
import '../../features/students/presentation/cubit/students_state.dart';
import 'adaptive_scaffold.dart';
import 'app_logo.dart';

/// Permanent application shell for Teacher role screens.
/// Features a comprehensive, categorized, mathematical sidebar that stays pinned.
class TeacherShell extends StatelessWidget {
  final Widget child;
  final String currentLocation;

  const TeacherShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  int _computeIndex(String path) {
    if (path == '/teacher' || path == '/teacher/') return 0;
    if (path.startsWith('/notifications') || path.startsWith('/teacher/notifications')) return 1;
    if (path == '/teacher/students' ||
        path.startsWith('/teacher/students/profile') ||
        path.startsWith('/teacher/students/assign-groups')) {
      return 2;
    }
    if (path.startsWith('/teacher/students/pending')) return 3;
    if (path == '/teacher/groups' || path == '/teacher/groups/') return 4;
    if (path.startsWith('/teacher/attendance')) return 5;
    if (path.contains('/content')) return 6;
    if (path.contains('/assignments')) return 7;
    if (path.contains('/exams')) return 8;
    if (path.startsWith('/teacher/announcements')) return 9;
    if (path.startsWith('/teacher/settings')) return 10;
    if (path.startsWith('/teacher/groups/')) return 4; // Group detail fallback
    return 0;
  }

  void _onNavigationChanged(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRouter.teacherDashboard);
        break;
      case 1:
        context.go(AppRouter.notificationsCenter);
        break;
      case 2:
        context.go(AppRouter.studentsList);
        break;
      case 3:
        context.go(AppRouter.pendingStudents);
        break;
      case 4:
        context.go(AppRouter.groupsList);
        break;
      case 5:
        context.go(AppRouter.teacherAttendance);
        break;
      case 6:
        context.go(AppRouter.teacherContent);
        break;
      case 7:
        context.go(AppRouter.teacherAssignments);
        break;
      case 8:
        context.go(AppRouter.teacherExams);
        break;
      case 9:
        context.go(AppRouter.sendAnnouncement);
        break;
      case 10:
        context.go(AppRouter.platformOnboarding);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Safety guard: If active session is not a teacher, do not render teacher shell
    final role = SupabaseService.currentUserRole;
    if (role != null && role != 'teacher') {
      return child;
    }

    final currentIndex = _computeIndex(currentLocation);

    // Watch live notification unread count
    int unreadNotifications = 0;
    try {
      final notifState = context.watch<NotificationsCubit>().state;
      if (notifState is NotificationsLoaded) {
        unreadNotifications = notifState.unreadCount;
      }
    } catch (_) {}

    // Watch live pending students count
    int pendingCount = 0;
    try {
      final studentsState = context.watch<StudentsCubit>().state;
      if (studentsState is StudentsLoaded) {
        pendingCount = studentsState.pendingCount;
      }
    } catch (_) {}

    final sections = [
      // Section 1: Dashboard
      AdaptiveSidebarSection(
        title: context.l10n.navDashboard,
        destinations: [
          AdaptiveDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: context.l10n.navDashboard,
            tooltip: context.l10n.navDashboard,
          ),
          AdaptiveDestination(
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications_rounded,
            label: context.l10n.navNotifications,
            tooltip: context.l10n.notificationsCenterTitle,
            badgeCount: unreadNotifications,
          ),
        ],
      ),

      // Section 2: Students & Groups
      AdaptiveSidebarSection(
        title: context.l10n.navSectionStudents,
        destinations: [
          AdaptiveDestination(
            icon: Icons.school_outlined,
            selectedIcon: Icons.school_rounded,
            label: context.l10n.studentsListTitle,
            tooltip: context.l10n.studentsListTitle,
          ),
          AdaptiveDestination(
            icon: Icons.person_add_outlined,
            selectedIcon: Icons.person_add_rounded,
            label: context.l10n.pendingStudentsTitle,
            tooltip: context.l10n.pendingStudentsTitle,
            badgeCount: pendingCount,
          ),
          AdaptiveDestination(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups_rounded,
            label: context.l10n.groupsListTitle,
            tooltip: context.l10n.groupsListTitle,
          ),
          AdaptiveDestination(
            icon: Icons.play_circle_outline_rounded,
            selectedIcon: Icons.play_circle_rounded,
            label: context.l10n.attendanceTitle,
            tooltip: context.l10n.attendanceTitle,
          ),
        ],
      ),

      // Section 3: Academic Operations
      AdaptiveSidebarSection(
        title: context.l10n.navSectionAcademic,
        destinations: [
          AdaptiveDestination(
            icon: Icons.folder_shared_outlined,
            selectedIcon: Icons.folder_shared_rounded,
            label: context.l10n.contentLibraryTitle,
            tooltip: context.l10n.contentLibraryTitle,
          ),
          AdaptiveDestination(
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment_rounded,
            label: context.l10n.assignmentsListTitle,
            tooltip: context.l10n.assignmentsListTitle,
          ),
          AdaptiveDestination(
            icon: Icons.quiz_outlined,
            selectedIcon: Icons.quiz_rounded,
            label: context.l10n.examsListTitle,
            tooltip: context.l10n.examsListTitle,
          ),
          AdaptiveDestination(
            icon: Icons.campaign_outlined,
            selectedIcon: Icons.campaign_rounded,
            label: context.l10n.sendAnnouncementNav,
            tooltip: context.l10n.sendAnnouncementTitle,
          ),
        ],
      ),

      // Section 4: System & Settings
      AdaptiveSidebarSection(
        title: context.l10n.navSectionSystem,
        destinations: [
          AdaptiveDestination(
            icon: Icons.tune_outlined,
            selectedIcon: Icons.tune_rounded,
            label: context.l10n.navSettings,
            tooltip: context.l10n.navSettings,
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
      onTap: () => context.go(AppRouter.teacherDashboard),
      mouseCursor: SystemMouseCursors.click,
      borderRadius: BorderRadius.circular(12),
      child: AppLogo.compact(
        size: 42,
        showName: true,
        platformName: branding.localizedBrandName(context),
        subtitle: '${branding.localizedTeacherName(context)} • ${branding.localizedAcademicTrack(context)}',
        nameColor: Colors.white,
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context) {
    final theme = Theme.of(context);
    final userEmail = SupabaseService.currentUser?.email ?? context.l10n.roleTeacher;

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
              Icons.person_rounded,
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
                  context.go(AppRouter.login);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
