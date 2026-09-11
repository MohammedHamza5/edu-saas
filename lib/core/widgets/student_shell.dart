import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../config/tenant_registry.dart';
import '../di/injection_container.dart';
import '../network/supabase_service.dart';
import '../router/app_router.dart';
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
    if (path.startsWith('/student/attendance')) return 5;
    return 0;
  }

  void _onNavigationChanged(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRouter.studentDashboard);
        break;
      case 1:
        context.go(AppRouter.studentNotifications);
        break;
      case 2:
        _handleStudentContentNavigation(context);
        break;
      case 3:
        context.go(AppRouter.studentAssignments);
        break;
      case 4:
        context.go(AppRouter.studentExams);
        break;
      case 5:
        context.go(AppRouter.studentAttendance);
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

    if (groups.length == 1) {
      final g = groups.first;
      context.go(
        '${AppRouter.studentGroupContent.replaceAll(':groupId', g.id)}?name=${Uri.encodeComponent(g.name)}',
      );
      return;
    }

    // Show group picker bottom sheet if multiple groups
    unawaited(showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
               mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      sheetContext.l10n.selectSubjectGroup,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.s8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: groups.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                    itemBuilder: (ctx, i) {
                      final group = groups[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight.withValues(alpha: 0.15),
                          child: const Icon(Icons.menu_book_rounded, color: AppColors.primary),
                        ),
                        title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(group.level),
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.go(
                            '${AppRouter.studentGroupContent.replaceAll(':groupId', group.id)}?name=${Uri.encodeComponent(group.name)}',
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ));
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
            tooltip: context.l10n.navDashboard,
          ),
          AdaptiveDestination(
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications_rounded,
            label: context.l10n.studentNavNotifications,
            tooltip: context.l10n.notificationsCenterTitle,
            badgeCount: unreadNotifications,
          ),
        ],
      ),

      // Section 2: Learning Materials
      AdaptiveSidebarSection(
        title: context.l10n.studentNavContent,
        destinations: [
          AdaptiveDestination(
            icon: Icons.menu_book_outlined,
            selectedIcon: Icons.menu_book_rounded,
            label: context.l10n.studentNavContent,
            tooltip: context.l10n.contentLibraryTitle,
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
            tooltip: context.l10n.assignmentsListTitle,
          ),
          AdaptiveDestination(
            icon: Icons.quiz_outlined,
            selectedIcon: Icons.quiz_rounded,
            label: context.l10n.studentNavExams,
            tooltip: context.l10n.examsListTitle,
          ),
          AdaptiveDestination(
            icon: Icons.fact_check_outlined,
            selectedIcon: Icons.fact_check_rounded,
            label: context.l10n.studentNavAttendance,
            tooltip: context.l10n.studentAttendanceTitle,
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
      onTap: () => context.go(AppRouter.studentDashboard),
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
