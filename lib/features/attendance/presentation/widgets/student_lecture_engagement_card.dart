import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/attendance_entity.dart';

/// Single Lecture Engagement Visual Card with Watch Progress Telemetry (Read-only, Zero Buttons)
class StudentLectureEngagementCard extends StatelessWidget {
  final StudentLectureEngagementItem item;

  const StudentLectureEngagementCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final isCompleted = item.isFullyWatched;
    final hasStarted = item.hasWatchedAny;

    final statusColor = isCompleted
        ? AppColors.success
        : hasStarted
        ? AppColors.warning
        : AppColors.textSecondary;

    final statusBadge = isCompleted
        ? context.l10n.lectureCompletedBadge
        : hasStarted
        ? context.l10n.lectureInProgressBadge
        : context.l10n.lectureNotStartedBadge;

    final lastWatchedText = item.lastWatchedAt != null
        ? context.l10n.lastWatchedAtLabel(
            DateFormat(
              'd MMMM yyyy, hh:mm a',
              Localizations.localeOf(context).languageCode,
            ).format(item.lastWatchedAt!),
          )
        : context.l10n.notWatchedYetLabel;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Title, Group Badge & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  isCompleted
                      ? Icons.verified_rounded
                      : hasStarted
                      ? Icons.play_arrow_rounded
                      : Icons.play_circle_outline_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.lectureTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Text(
                            statusBadge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.groupName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.groupName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),

          // Middle: Watch Progress & Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.formattedDuration.isNotEmpty
                    ? context.l10n.watchedTimeOutOfTotal(
                        item.formattedWatchTime,
                        item.formattedDuration,
                      )
                    : item.formattedWatchTime,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${item.watchProgressPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (item.watchProgressPercent / 100.0).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // Bottom Row: Last Watched Date (Read-only, Zero Buttons)
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  lastWatchedText,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
