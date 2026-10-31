import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';
import 'teacher_assessment_choice_sheet.dart';
import 'teacher_quick_action_card.dart';

export 'teacher_assessment_choice_sheet.dart';
export 'teacher_quick_action_card.dart';

/// High-priority daily quick actions hub for teacher dashboard.
class TeacherDashboardQuickActionsHub extends StatelessWidget {
  final int pendingStudentsCount;

  const TeacherDashboardQuickActionsHub({
    super.key,
    required this.pendingStudentsCount,
  });

  /// Opens the modal sheet to create an assessment (quiz or homework).
  static void showAssessmentChoice(BuildContext context) {
    TeacherAssessmentChoiceSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
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
            final isWide = constraints.maxWidth >= 720;

            final cardLesson = TeacherQuickActionCard(
              title: l10n.quickActionUploadLessonTitle,
              description: l10n.quickActionUploadLessonDesc,
              icon: Icons.video_call_rounded,
              accentColor: const Color(0xFF10B981),
              onTap: () => context.go(AppRoutes.teacherContent),
            );

            final cardAssessment = TeacherQuickActionCard(
              title: l10n.quickActionAssessmentTitle,
              description: l10n.quickActionAssessmentDesc,
              icon: Icons.quiz_rounded,
              accentColor: const Color(0xFF3B82F6),
              onTap: () => TeacherAssessmentChoiceSheet.show(context),
            );

            final cardPending = TeacherQuickActionCard(
              title: l10n.quickActionPendingStudentsTitle,
              description: l10n.quickActionPendingStudentsDesc,
              icon: Icons.person_add_rounded,
              accentColor: const Color(0xFFF59E0B),
              badgeText: pendingStudentsCount > 0
                  ? l10n.pendingStudentsCountBadge(pendingStudentsCount)
                  : l10n.noPendingStudentsBadge,
              isBadgeWarning: pendingStudentsCount > 0,
              onTap: () => context.go(AppRoutes.pendingStudents),
            );

            if (isWide) {
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
}
