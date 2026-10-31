import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/attendance_entity.dart';
import 'student_attendance_lecture_progress_box.dart';
import 'student_attendance_overall_progress_box.dart';
import 'student_attendance_top_row.dart';

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
                StudentAttendanceTopRow(
                  student: student,
                  statusColor: statusColor,
                  statusLabel: statusLabel,
                  statusIcon: statusIcon,
                  hasNote: hasNote,
                  isOverall: isOverall,
                  onWhatsAppTap: widget.onWhatsAppTap,
                  onNoteTap: widget.onNoteTap,
                ),
                const SizedBox(height: AppSpacing.s10),

                // Engagement & Watch Progress Display
                if (isOverall)
                  StudentAttendanceOverallProgressBox(
                    student: student,
                    statusColor: statusColor,
                  )
                else
                  StudentAttendanceLectureProgressBox(
                    student: student,
                    statusColor: statusColor,
                    pctString: pctString,
                    realPercentage: realPercentage,
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
}
