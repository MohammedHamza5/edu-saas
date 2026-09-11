import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/attendance_entity.dart';

class StudentAttendanceRowCard extends StatefulWidget {
  final StudentAttendanceItem student;
  final ValueChanged<AttendanceStatus>? onStatusChanged;
  final VoidCallback onNoteTap;

  const StudentAttendanceRowCard({
    super.key,
    required this.student,
    this.onStatusChanged,
    required this.onNoteTap,
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
                // Top Row: Avatar, Student Info, Note Action Button
                Row(
                  children: [
                    // Student Academic Avatar
                    Container(
                      width: 40,
                      height: 40,
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
                          if (student.phone != null) ...[
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

                    // Quick Note Action Icon
                    Material(
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
                  ],
                ),
                const SizedBox(height: AppSpacing.s10),

                // Lecture Watch Progress Tracker
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s10,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            switch (student.status) {
                              AttendanceStatus.present => Icons.check_circle_rounded,
                              AttendanceStatus.late => Icons.play_circle_filled_rounded,
                              AttendanceStatus.absent => Icons.cancel_outlined,
                              AttendanceStatus.excused => Icons.info_outline_rounded,
                            },
                            size: 16,
                            color: statusColor,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              switch (student.status) {
                                AttendanceStatus.present => context.l10n.attendanceRateFull,
                                AttendanceStatus.late => context.l10n.attendanceRatePartial,
                                AttendanceStatus.absent => context.l10n.attendanceRateNone,
                                AttendanceStatus.excused => context.l10n.attendanceRateExcused,
                              },
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
                              switch (student.status) {
                                AttendanceStatus.present => '100%',
                                AttendanceStatus.late => '45%',
                                AttendanceStatus.absent => '0%',
                                AttendanceStatus.excused => '100%',
                              },
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
                          value: switch (student.status) {
                            AttendanceStatus.present => 1.0,
                            AttendanceStatus.late => 0.45,
                            AttendanceStatus.absent => 0.0,
                            AttendanceStatus.excused => 1.0,
                          },
                          backgroundColor: AppColors.border.withValues(alpha: 0.5),
                          valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
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
}
