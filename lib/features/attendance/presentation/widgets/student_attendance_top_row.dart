import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/attendance_entity.dart';

/// Top row of the student attendance card:
/// Academic avatar, student name & phone, engagement badge, WhatsApp and quick note actions.
class StudentAttendanceTopRow extends StatelessWidget {
  final StudentAttendanceItem student;
  final Color statusColor;
  final String statusLabel;
  final IconData statusIcon;
  final bool hasNote;
  final bool isOverall;
  final VoidCallback? onWhatsAppTap;
  final VoidCallback onNoteTap;

  const StudentAttendanceTopRow({
    super.key,
    required this.student,
    required this.statusColor,
    required this.statusLabel,
    required this.statusIcon,
    required this.hasNote,
    required this.isOverall,
    this.onWhatsAppTap,
    required this.onNoteTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
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
              if (student.phone != null && student.phone!.isNotEmpty) ...[
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
        if (onWhatsAppTap != null) ...[
          Tooltip(
            message: isOverall
                ? context.l10n.sendParentEngagementReport
                : context.l10n.sendLectureWhatsAppNotice,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onWhatsAppTap,
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusSmall,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.12),
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
              ? (student.note ?? '')
              : context.l10n.attendanceNoteHint,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onNoteTap,
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
    );
  }
}
