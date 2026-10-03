import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/attendance_entity.dart';

class StudentAttendanceRowCard extends StatefulWidget {
  final StudentAttendanceItem student;
  final ValueChanged<AttendanceStatus>? onStatusChanged;
  final VoidCallback onNoteTap;
  final VoidCallback? onWhatsAppTap;

  const StudentAttendanceRowCard({
    super.key,
    required this.student,
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

    // Status-specific accent border tint
    final statusColor = switch (student.status) {
      AttendanceStatus.present => AppColors.success,
      AttendanceStatus.absent => AppColors.error,
      AttendanceStatus.late => AppColors.warning,
      AttendanceStatus.excused => AppColors.info,
    };

    // Formatted real watch percentage
    final realPercentage = student.watchProgressPercent;
    final pctString = realPercentage.toStringAsFixed(
      realPercentage > 0 && realPercentage < 10 ? 1 : 0,
    );

    // Watch status label & icon
    final (watchLabel, watchIcon, watchColor) = () {
      if (student.isCompleted || realPercentage >= 80.0) {
        return (
          context.l10n.attendanceRateFull,
          Icons.check_circle_rounded,
          AppColors.success,
        );
      } else if (realPercentage > 0.0) {
        return (
          context.l10n.attendanceRatePartial,
          Icons.play_circle_filled_rounded,
          AppColors.warning,
        );
      } else {
        return (
          context.l10n.attendanceRateNone,
          Icons.cancel_outlined,
          AppColors.error,
        );
      }
    }();

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
                // Top Row: Avatar, Student Info, Actions (WhatsApp & Note)
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
                          Text(
                            student.studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
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
                        message: context.l10n.sendLectureWhatsAppNotice,
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

                // Real Video Lecture Watch Progress Tracker
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s10,
                  ),
                  decoration: BoxDecoration(
                    color: watchColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                    border: Border.all(
                      color: watchColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(watchIcon, size: 16, color: watchColor),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.currentLectureTitle != null
                                      ? student.currentLectureTitle!
                                      : (student.totalLecturesCount > 1
                                          ? context.l10n.completedLecturesRatio(
                                              student.completedLecturesCount,
                                              student.totalLecturesCount,
                                            )
                                          : watchLabel),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: watchColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (student.currentLectureTitle != null)
                                  Text(
                                    watchLabel,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: watchColor.withValues(alpha: 0.85),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: watchColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$pctString%',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: watchColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      // Real Progress Bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: (realPercentage / 100.0).clamp(0.0, 1.0),
                          backgroundColor: AppColors.border.withValues(
                            alpha: 0.5,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(watchColor),
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
                                    color: AppColors.error.withValues(
                                      alpha: 0.3,
                                    ),
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
                                DateFormat(
                                  'MM/dd HH:mm',
                                ).format(student.lastWatchedAt!.toLocal()),
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
                ),
                const SizedBox(height: AppSpacing.s10),

                // Quick Status Segmented Selector
                Row(
                  children: [
                    _buildStatusChip(
                      context,
                      status: AttendanceStatus.present,
                      label: context.l10n.attendanceStatusPresent,
                      activeColor: AppColors.success,
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    _buildStatusChip(
                      context,
                      status: AttendanceStatus.late,
                      label: context.l10n.attendanceStatusLate,
                      activeColor: AppColors.warning,
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    _buildStatusChip(
                      context,
                      status: AttendanceStatus.absent,
                      label: context.l10n.attendanceStatusAbsent,
                      activeColor: AppColors.error,
                      icon: Icons.cancel_outlined,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    _buildStatusChip(
                      context,
                      status: AttendanceStatus.excused,
                      label: context.l10n.attendanceStatusExcused,
                      activeColor: AppColors.info,
                      icon: Icons.info_outline_rounded,
                    ),
                  ],
                ),

                // Note Preview Section (if student has note)
                if (hasNote) ...[
                  const SizedBox(height: AppSpacing.s8),
                  Container(
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
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.s6),
                        Expanded(
                          child: Text(
                            student.note!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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

  Widget _buildStatusChip(
    BuildContext context, {
    required AttendanceStatus status,
    required String label,
    required Color activeColor,
    required IconData icon,
  }) {
    final isSelected = widget.student.status == status;

    return Expanded(
      child: InkWell(
        onTap: widget.onStatusChanged != null
            ? () => widget.onStatusChanged!(status)
            : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.16)
                : AppColors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.6)
                  : AppColors.border.withValues(alpha: 0.6),
              width: isSelected ? 1.3 : 1.0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 12,
                color: isSelected ? activeColor : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? activeColor : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
