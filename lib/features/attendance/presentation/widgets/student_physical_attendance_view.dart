import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../domain/entities/attendance_entity.dart';
import '../cubit/attendance_state.dart';
import 'attendance_history_item_card.dart';
import 'attendance_stat_card.dart';

class StudentPhysicalAttendanceView extends StatelessWidget {
  final StudentAttendanceLoaded state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final AttendanceStatus? historyFilter;

  const StudentPhysicalAttendanceView({
    super.key,
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    this.historyFilter,
  });

  @override
  Widget build(BuildContext context) {
    final records = state.records;
    final stats = state.stats;

    if (records.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: AppEmptyView(
              message: context.l10n.noAttendanceRecordsMessage,
              icon: Icons.event_busy_rounded,
            ),
          ),
        ),
      );
    }

    final displayedRecords = records.where((r) {
      if (historyFilter != null && r.status != historyFilter) {
        return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ResponsiveContainer(
        child: ListView(
          controller: scrollController,
          padding: context.responsivePagePadding,
          children: [
            _buildPercentageCard(stats.attendancePercentage),
            const SizedBox(height: AppSpacing.s16),
            ResponsiveGrid(
              mobileColumns: 2,
              tabletColumns: 4,
              desktopColumns: 4,
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                AttendanceStatCard(
                  title: context.l10n.attendanceStatusPresent,
                  value: '${stats.presentCount}',
                  color: AppColors.success,
                  icon: Icons.check_circle_rounded,
                ),
                AttendanceStatCard(
                  title: context.l10n.attendanceStatusAbsent,
                  value: '${stats.absentCount}',
                  color: AppColors.error,
                  icon: Icons.cancel_rounded,
                ),
                AttendanceStatCard(
                  title: context.l10n.attendanceStatusLate,
                  value: '${stats.lateCount}',
                  color: AppColors.warning,
                  icon: Icons.access_time_filled_rounded,
                ),
                AttendanceStatCard(
                  title: context.l10n.attendanceStatusExcused,
                  value: '${stats.excusedCount}',
                  color: AppColors.info,
                  icon: Icons.info_rounded,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),
            ...displayedRecords.map((record) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: AttendanceHistoryItemCard(record: record),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentageCard(double percentage) {
    final isHigh = percentage >= 85.0;
    final isMedium = percentage >= 70.0 && percentage < 85.0;
    final color = isHigh
        ? AppColors.success
        : isMedium
        ? AppColors.warning
        : AppColors.error;

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.2),
        ),
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${percentage.toStringAsFixed(1)}%',
              style: AppTypography.statFigureLarge.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.s8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: LinearProgressIndicator(
                value: (percentage / 100.0).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
