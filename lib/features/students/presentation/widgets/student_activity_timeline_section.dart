import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/student_360_entity.dart';
import 'student_360_stats_grid.dart';

/// Chronological activity timeline section for student interactions.
class StudentActivityTimelineSection extends StatelessWidget {
  final List<StudentActivityItem> activities;

  const StudentActivityTimelineSection({
    super.key,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StudentSectionTitle(context.l10n.activityTimelineTitle),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s8,
          ),
          child: Column(
            children: activities.take(8).map((act) {
              final (label, icon, color) = switch (act.eventType) {
                'login' => (
                  context.l10n.eventLogin,
                  Icons.login_rounded,
                  AppColors.info,
                ),
                'content_opened' => (
                  context.l10n.eventContentOpened,
                  Icons.menu_book_rounded,
                  AppColors.primary,
                ),
                'video_started' => (
                  context.l10n.eventVideoStarted,
                  Icons.play_circle_outline_rounded,
                  AppColors.primary,
                ),
                'video_completed' => (
                  context.l10n.eventVideoCompleted,
                  Icons.check_circle_outline_rounded,
                  AppColors.success,
                ),
                'assignment_submitted' => (
                  context.l10n.eventAssignmentSubmitted,
                  Icons.assignment_turned_in_outlined,
                  AppColors.success,
                ),
                'exam_started' => (
                  context.l10n.eventExamStarted,
                  Icons.timer_outlined,
                  AppColors.warning,
                ),
                'exam_submitted' => (
                  context.l10n.eventExamSubmitted,
                  Icons.grading_rounded,
                  AppColors.success,
                ),
                _ => (act.eventType, Icons.circle, AppColors.textSecondary),
              };

              final itemTitle = act.contentTitle ?? act.groupName;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 14, color: color),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          if (itemTitle != null)
                            Text(
                              itemTitle,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _formatRelativeTime(context, act.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static String _formatRelativeTime(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return context.l10n.minutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return context.l10n.hoursAgo(diff.inHours);
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}
