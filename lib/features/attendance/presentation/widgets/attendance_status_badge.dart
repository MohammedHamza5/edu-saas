import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/attendance_entity.dart';

class AttendanceStatusBadge extends StatelessWidget {
  final AttendanceStatus status;
  final bool compact;

  const AttendanceStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon) = switch (status) {
      AttendanceStatus.present => (
          AppColors.success.withAlpha(30),
          AppColors.success,
          Icons.check_circle_rounded,
        ),
      AttendanceStatus.absent => (
          AppColors.error.withAlpha(30),
          AppColors.error,
          Icons.cancel_rounded,
        ),
      AttendanceStatus.late => (
          AppColors.warning.withAlpha(30),
          AppColors.warning,
          Icons.access_time_filled_rounded,
        ),
      AttendanceStatus.excused => (
          AppColors.info.withAlpha(30),
          AppColors.info,
          Icons.info_rounded,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.s8 : AppSpacing.s12,
        vertical: compact ? AppSpacing.s4 : AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: fg.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: fg),
          const SizedBox(width: AppSpacing.s4),
          Text(
            status.labelAr,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
