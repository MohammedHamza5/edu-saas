import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../config/tenant_resolver.dart';
import '../extensions/localized_context_extension.dart';
import '../network/supabase_service.dart';
import '../router/app_router.dart';
import '../theme/tenant_theme_cubit.dart';
import '../utils/prefetch_service.dart';
import '../../features/notifications/presentation/cubit/notifications_cubit.dart';
import '../../features/notifications/presentation/cubit/notifications_state.dart';
import 'adaptive_scaffold.dart';
import 'app_logo.dart';
import 'student_shell_content_navigation.dart';
import 'student_shell_destinations.dart';
import 'student_shell_footer.dart';

/// Permanent application shell for Student role screens.
/// Features a categorized, mathematical sidebar that stays pinned across all student pages.
class StudentShell extends StatefulWidget {
  final Widget child;
  final String currentLocation;

  const StudentShell({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  @override
  void initState() {
    super.initState();
    // Silently prefetch all student domains in background for instant (0ms) tab switching
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          PrefetchService.prefetchStudentData(context);
        } catch (_) {}
      }
    });
  }

  int _computeIndex(String path) {
    if (path == '/student' || path == '/student/') return 0;
    if (path.startsWith('/notifications') ||
        path.startsWith('/student/notifications')) {
      return 1;
    }
    if (path.contains('/content')) return 2;
    if (path.startsWith('/student/assignments')) return 3;
    if (path.startsWith('/student/exams')) return 4;
    if (path.startsWith('/student/mistakes')) return 5;
    if (path.startsWith('/student/saved-questions')) return 6;
    if (path.startsWith('/student/attendance')) return 7;
    if (path.startsWith(AppRoutes.studentProfile)) return 8;
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
        StudentShellContentNavigation.handleContentNavigation(context);
        break;
      case 3:
        context.go(AppRoutes.studentAssignments);
        break;
      case 4:
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        context.go(AppRoutes.studentExams);
        break;
      case 5:
        context.go(AppRoutes.studentMistakes);
        break;
      case 6:
        context.go(AppRoutes.studentSavedQuestions);
        break;
      case 7:
        context.go(AppRoutes.studentAttendance);
        break;
      case 8:
        context.go(AppRoutes.studentProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = SupabaseService.currentUserRole;
    final status = SupabaseService.currentUserStatus;
    if (role != null && role != 'student') {
      return widget.child;
    }
    if (status != null && status != 'active') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go(AppRoutes.studentPending);
        }
      });
      return const SizedBox.shrink();
    }

    final currentIndex = _computeIndex(widget.currentLocation);

    // Watch live unread notification count
    int unreadNotifications = 0;
    try {
      final notifState = context.watch<NotificationsCubit>().state;
      if (notifState is NotificationsLoaded) {
        unreadNotifications = notifState.unreadCount;
      }
    } catch (_) {}

    final sections = StudentShellDestinations.buildSections(
      context,
      unreadNotifications: unreadNotifications,
    );

    return AdaptiveScaffold(
      currentIndex: currentIndex,
      sections: sections,
      onNavigationIndexChanged: (idx) => _onNavigationChanged(context, idx),
      sidebarHeader: _buildSidebarHeader(context),
      sidebarFooter: StudentShellFooter(
        currentLocation: widget.currentLocation,
      ),
      collapsedSidebarHeader: _buildCollapsedSidebarHeader(context),
      collapsedSidebarFooter: StudentShellFooter(
        isCollapsed: true,
        currentLocation: widget.currentLocation,
      ),
      body: widget.child,
    );
  }

  Widget _buildSidebarHeader(BuildContext context) {
    // Resolve active branding (from TenantThemeCubit or default registry)
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantResolver.resolveBranding();
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
        subtitle:
            '${branding.localizedBrandName(context)} • ${context.l10n.academicMathematics}',
        nameColor: Colors.white,
      ),
    );
  }

  Widget _buildCollapsedSidebarHeader(BuildContext context) {
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantResolver.resolveBranding();
      }
    })();

    return Tooltip(
      message:
          '${context.l10n.studentPortal} • ${branding.localizedBrandName(context)}',
      preferBelow: false,
      child: InkWell(
        onTap: () => context.go(AppRoutes.studentDashboard),
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(10),
        child: const AppLogo.badge(
          size: 38,
          withGlow: true,
        ),
      ),
    );
  }
}
