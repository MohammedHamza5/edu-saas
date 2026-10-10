import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/attendance_entity.dart';

class StudentAttendanceRowCard extends StatefulWidget {
  final StudentAttendanceItem student;
  final bool isOverallView;
  final ValueChanged<AttendanceStatus>? onStatusChanged;
  final VoidCallback onNoteTap;
  final VoidCallback? onWhatsAppTap;

  const StudentAttendanceRowCard({
    super.key,
    required this.student,
    this.isOverallView = false,
    this.onStatusChanged,
    required this.onNoteTap,
    this.onWhatsAppTap,
  });

  @override
  State<StudentAttendanceRowCard> createState() =>
      _StudentAttendanceRowCardState();
}

class _StudentAttendanceRowCardState extends State<StudentAttendanceRowCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final hasNote = student.note != null && student.note!.trim().isNotEmpty;
    final isOverall = widget.isOverallView;

    // Resolve Status and Colors automatically based on engagement
    final (Color statusColor, String statusLabel, IconData statusIcon) = () {
      if (isOverall) {
        final total = student.totalLecturesCount > 0 ? student.totalLecturesCount : 1;
        final ratio = student.completedLecturesCount / total;
        if (ratio >= 0.75) {
          return (
            AppColors.success,
            context.l10n.engagementHigh,
            Icons.verified_rounded,
          );
        } else if (ratio >= 0.35) {
          return (
            AppColors.warning,
            context.l10n.engagementMedium,
            Icons.schedule_rounded,
          );
        } else {
          return (
            AppColors.error,
            context.l10n.engagementLow,
            Icons.error_outline_rounded,
          );
        }
      } else {
        if (student.isCompleted || student.watchProgressPercent >= 80.0) {
          return (
            AppColors.success,
            context.l10n.lectureCompletedBadge,
            Icons.check_circle_rounded,
          );
        } else if (student.watchProgressPercent > 0.0) {
          final pct = student.watchProgressPercent.toStringAsFixed(0);
          return (
            AppColors.warning,
            '${context.l10n.lectureInProgressBadge} ($pct%)',
            Icons.play_circle_filled_rounded,
          );
        } else {
          return (
            AppColors.error,
            context.l10n.lectureNotStartedBadge,
            Icons.cancel_outlined,
          );
        }
      }
    }();

    // Formatted real watch percentage for single lecture
    final realPercentage = student.watchProgressPercent;
    final pctString = realPercentage.toStringAsFixed(
      realPercentage > 0 && realPercentage < 10 ? 1 : 0,
    );

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -1.5 : 0.0, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: _isHovered
                  ? statusColor.withValues(alpha: 0.35)
                  : AppColors.border,
              width: _isHovered ? 1.2 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Avatar, Student Info, Automatic Status Badge, & Actions
                Row(
                  children: [
                    // Student Academic Avatar
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            statusColor.withValues(alpha: 0.16),
                            statusColor.withValues(alpha: 0.06),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        student.studentName.isNotEmpty
                            ? student.studentName.characters.first
                            : context.l10n.studentInitialDefault,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),

                    // Student Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  student.studentName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              // Automated Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon, size: 12, color: statusColor),
                                    const SizedBox(width: 4),
                                    Text(
                                      statusLabel,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: statusColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (student.phone != null &&
                              student.phone!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              student.phone!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // WhatsApp Instant Report Action
                    if (widget.onWhatsAppTap != null) ...[
                      Tooltip(
                        message: isOverall
                            ? context.l10n.sendParentEngagementReport
                            : context.l10n.sendLectureWhatsAppNotice,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: widget.onWhatsAppTap,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(AppSpacing.s6),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF25D366,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                              ),
                              child: const Icon(
                                Icons.mark_chat_read_rounded,
                                color: Color(0xFF25D366),
                                size: 19,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s6),
                    ],

                    // Quick Note Action Icon
                    Tooltip(
                      message: hasNote
                          ? student.note!
                          : context.l10n.attendanceNoteHint,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onNoteTap,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(AppSpacing.s6),
                            decoration: BoxDecoration(
                              color: hasNote
                                  ? AppColors.primary.withValues(alpha: 0.10)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                            child: Icon(
                              hasNote
                                  ? Icons.note_alt_rounded
                                  : Icons.note_add_outlined,
                              color: hasNote
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                              size: 19,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s10),

                // Engagement & Watch Progress Display
                if (isOverall)
                  _buildOverallProgressContainer(context, statusColor)
                else
                  _buildLectureProgressContainer(
                    context,
                    statusColor,
                    pctString,
                    realPercentage,
                  ),

                // Note Preview Section (if student has note)
                if (hasNote) ...[
                  const SizedBox(height: AppSpacing.s8),
                  InkWell(
                    onTap: widget.onNoteTap,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusSmall,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.sticky_note_2_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.s6),
                          Expanded(
                            child: Text(
                              student.note!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds progress tracker for a specific lecture
  Widget _buildLectureProgressContainer(
    BuildContext context,
    Color statusColor,
    String pctString,
    double realPercentage,
  ) {
    final student = widget.student;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.play_circle_outline_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  student.currentLectureTitle ?? context.l10n.allLecturesOverview,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pctString%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (realPercentage / 100.0).clamp(0.0, 1.0),
              backgroundColor: AppColors.border.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
          // Watch Details Footer
          if (student.formattedWatchDuration.isNotEmpty ||
              student.isSkipped ||
              student.lastWatchedAt != null) ...[
            const SizedBox(height: AppSpacing.s6),
            Row(
              children: [
                if (student.formattedWatchDuration.isNotEmpty) ...[
                  const Icon(
                    Icons.timer_outlined,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    student.formattedWatchDuration,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
                if (student.isSkipped) ...[
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          size: 11,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          context.l10n.fastSkippingDetected,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                if (student.lastWatchedAt != null) ...[
                  Text(
                    DateFormat('MM/dd HH:mm').format(
                      student.lastWatchedAt!.toLocal(),
                    ),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Builds progress tracker for overall group lectures
  Widget _buildOverallProgressContainer(
    BuildContext context,
    Color statusColor,
  ) {
    final student = widget.student;
    final total = student.totalLecturesCount > 0 ? student.totalLecturesCount : 1;
    final completed = student.completedLecturesCount;
    final ratio = (completed / total).clamp(0.0, 1.0);
    final pct = (ratio * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: statusColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories_rounded, size: 16, color: statusColor),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  context.l10n.completedLecturesSummary(completed, total, '$pct'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.border.withValues(alpha: 0.5),
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              minHeight: 6,
            ),
          ),
          if (student.lastWatchedAt != null) ...[
            const SizedBox(height: AppSpacing.s6),
            Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'آخر نشاط: ${DateFormat('yyyy/MM/dd HH:mm').format(student.lastWatchedAt!.toLocal())}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
