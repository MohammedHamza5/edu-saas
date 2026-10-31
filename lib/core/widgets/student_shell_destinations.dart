import 'package:flutter/material.dart';

import '../extensions/localized_context_extension.dart';
import 'adaptive_scaffold.dart';

/// Builds the categorized navigation sections and destinations for the Student Shell.
class StudentShellDestinations {
  StudentShellDestinations._();

  static List<AdaptiveSidebarSection> buildSections(
    BuildContext context, {
    required int unreadNotifications,
  }) {
    final l10n = context.l10n;

    return [
      // Section 1: Dashboard & Alerts
      AdaptiveSidebarSection(
        title: l10n.studentNavDashboard,
        destinations: [
          AdaptiveDestination(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard_rounded,
            label: l10n.studentNavDashboard,
            subtitle: l10n.studentNavDashboardSubtitle,
            tooltip: l10n.navDashboard,
          ),
          AdaptiveDestination(
            icon: Icons.notifications_outlined,
            selectedIcon: Icons.notifications_rounded,
            label: l10n.studentNavNotifications,
            subtitle: l10n.studentNavNotificationsSubtitle,
            tooltip: l10n.notificationsCenterTitle,
            badgeCount: unreadNotifications,
          ),
        ],
      ),

      // Section 2: Lectures & Content
      AdaptiveSidebarSection(
        title: l10n.studentNavLectures,
        destinations: [
          AdaptiveDestination(
            icon: Icons.play_circle_outline_rounded,
            selectedIcon: Icons.play_circle_rounded,
            label: l10n.studentNavLectures,
            subtitle: l10n.studentNavLecturesSubtitle,
            tooltip: l10n.studentNavLectures,
          ),
        ],
      ),

      // Section 3: Tasks & Exams
      AdaptiveSidebarSection(
        title: l10n.assignmentsListTitle,
        destinations: [
          AdaptiveDestination(
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment_rounded,
            label: l10n.studentNavAssignments,
            subtitle: l10n.studentNavAssignmentsSubtitle,
            tooltip: l10n.assignmentsListTitle,
          ),
          AdaptiveDestination(
            icon: Icons.quiz_outlined,
            selectedIcon: Icons.quiz_rounded,
            label: l10n.studentNavExams,
            subtitle: l10n.studentNavExamsSubtitle,
            tooltip: l10n.examsListTitle,
          ),
          AdaptiveDestination(
            icon: Icons.auto_stories_outlined,
            selectedIcon: Icons.auto_stories_rounded,
            label: l10n.studentNavMistakesBank,
            subtitle: l10n.mistakesBankSidebarSubtitle,
            tooltip: l10n.studentNavMistakesBank,
          ),
          AdaptiveDestination(
            icon: Icons.bookmark_border_rounded,
            selectedIcon: Icons.bookmark_rounded,
            label: l10n.savedQuestionsVaultTitle,
            subtitle: l10n.savedQuestionsVaultSubtitle,
            tooltip: l10n.savedQuestionsVaultTitle,
          ),
          AdaptiveDestination(
            icon: Icons.insights_outlined,
            selectedIcon: Icons.insights_rounded,
            label: l10n.studentEngagementNavTitle,
            subtitle: l10n.studentEngagementNavSubtitle,
            tooltip: l10n.studentEngagementNavTitle,
          ),
        ],
      ),

      // Section 4: Account & Settings
      AdaptiveSidebarSection(
        title: l10n.navSettings,
        destinations: [
          AdaptiveDestination(
            icon: Icons.manage_accounts_outlined,
            selectedIcon: Icons.manage_accounts_rounded,
            label: l10n.studentProfileAndSettingsTitle,
            subtitle: l10n.studentProfileSubtitle,
            tooltip: l10n.studentProfileAndSettingsTitle,
          ),
        ],
      ),
    ];
  }
}
