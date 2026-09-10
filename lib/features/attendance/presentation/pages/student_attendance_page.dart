import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/entities/attendance_entity.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/attendance_stat_card.dart';
import '../widgets/attendance_status_badge.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';

class StudentAttendancePage extends StatefulWidget {
  final String? studentId;
  final AttendanceCubit? attendanceCubit;

  const StudentAttendancePage({
    super.key,
    this.studentId,
    this.attendanceCubit,
  });

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  late final AttendanceCubit _attendanceCubit;
  String? _resolvedStudentId;
  AttendanceStatus? _historyFilter;

  @override
  void initState() {
    super.initState();
    _attendanceCubit =
        widget.attendanceCubit ?? InjectionContainer.createAttendanceCubit();

    final authState = context.read<AuthCubit>().state;
    if (widget.studentId != null) {
      _resolvedStudentId = widget.studentId;
    } else if (authState is AuthAuthenticated) {
      _resolvedStudentId = authState.user.id;
    }

    _loadData();
  }

  @override
  void dispose() {
    if (widget.attendanceCubit == null) {
      _attendanceCubit.close();
    }
    super.dispose();
  }

  void _loadData() {
    if (_resolvedStudentId != null) {
      _attendanceCubit.loadStudentAttendance(studentId: _resolvedStudentId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _attendanceCubit,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'الرجوع للرئيسية',
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go(AppRouter.studentDashboard);
              }
            },
          ),
          title: const Text('سجل الحضور والغياب'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: _loadData,
            ),
          ],
        ),
        body: BlocBuilder<AttendanceCubit, AttendanceState>(
          builder: (context, state) {
            if (state is AttendanceLoading || state is AttendanceInitial) {
              return _buildSkeletonLoading();
            }

            if (state is AttendanceError) {
              return AppErrorView(message: state.message, onRetry: _loadData);
            }

            if (state is StudentAttendanceLoaded) {
              final records = state.records;
              final stats = state.stats;

              if (records.isEmpty) {
                return const AppEmptyView(
                  message:
                      'لا يوجد سجلات حضور\nلم يتم تسجيل أي حضور أو غياب لك في المجموعات حتى الآن.',
                  icon: Icons.event_available_rounded,
                );
              }

              final displayedRecords = records.where((r) {
                if (_historyFilter != null && r.status != _historyFilter) {
                  return false;
                }
                return true;
              }).toList();

              return RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: Center(
                  child: ResponsiveContainer(
                    maxWidth: ResponsiveBreakpoints.maxContentWidth,
                    child: ListView(
                      padding: context.responsivePagePadding,
                      children: [
                        // Top Highlight Card: Attendance Percentage
                        _buildPercentageCard(stats.attendancePercentage),
                        const SizedBox(height: AppSpacing.s16),

                        // Metrics Breakdown (Responsive Grid)
                        ResponsiveGrid(
                          mobileColumns: 2,
                          tabletColumns: 4,
                          desktopColumns: 4,
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s8,
                          children: [
                            AttendanceStatCard(
                              title: 'حاضر',
                              value: '${stats.presentCount}',
                              color: AppColors.success,
                              icon: Icons.check_circle_rounded,
                            ),
                            AttendanceStatCard(
                              title: 'غياب',
                              value: '${stats.absentCount}',
                              color: AppColors.error,
                              icon: Icons.cancel_rounded,
                            ),
                            AttendanceStatCard(
                              title: 'تأخير',
                              value: '${stats.lateCount}',
                              color: AppColors.warning,
                              icon: Icons.access_time_filled_rounded,
                            ),
                            AttendanceStatCard(
                              title: 'معذور',
                              value: '${stats.excusedCount}',
                              color: AppColors.info,
                              icon: Icons.info_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s24),

                        // Section Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'سجل الجلسات السابقة',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'إجمالي ${records.length} جلسة',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),

                        // History Filter Chips
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              FilterChip(
                                label: Text('الكل (${records.length})'),
                                selected: _historyFilter == null,
                                selectedColor: AppColors.primaryLight
                                    .withValues(alpha: 0.25),
                                checkmarkColor: AppColors.primary,
                                labelStyle: TextStyle(
                                  color: _historyFilter == null
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: _historyFilter == null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) =>
                                    setState(() => _historyFilter = null),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              FilterChip(
                                label: Text('حاضر (${stats.presentCount})'),
                                selected:
                                    _historyFilter == AttendanceStatus.present,
                                selectedColor: AppColors.success.withValues(
                                  alpha: 0.2,
                                ),
                                checkmarkColor: AppColors.success,
                                labelStyle: TextStyle(
                                  color:
                                      _historyFilter == AttendanceStatus.present
                                      ? AppColors.success
                                      : AppColors.textPrimary,
                                  fontWeight:
                                      _historyFilter == AttendanceStatus.present
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(
                                  () => _historyFilter =
                                      _historyFilter == AttendanceStatus.present
                                      ? null
                                      : AttendanceStatus.present,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              FilterChip(
                                label: Text('غياب (${stats.absentCount})'),
                                selected:
                                    _historyFilter == AttendanceStatus.absent,
                                selectedColor: AppColors.error.withValues(
                                  alpha: 0.2,
                                ),
                                checkmarkColor: AppColors.error,
                                labelStyle: TextStyle(
                                  color:
                                      _historyFilter == AttendanceStatus.absent
                                      ? AppColors.error
                                      : AppColors.textPrimary,
                                  fontWeight:
                                      _historyFilter == AttendanceStatus.absent
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(
                                  () => _historyFilter =
                                      _historyFilter == AttendanceStatus.absent
                                      ? null
                                      : AttendanceStatus.absent,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              FilterChip(
                                label: Text('تأخير (${stats.lateCount})'),
                                selected:
                                    _historyFilter == AttendanceStatus.late,
                                selectedColor: AppColors.warning.withValues(
                                  alpha: 0.2,
                                ),
                                checkmarkColor: AppColors.warning,
                                labelStyle: TextStyle(
                                  color: _historyFilter == AttendanceStatus.late
                                      ? AppColors.warning
                                      : AppColors.textPrimary,
                                  fontWeight:
                                      _historyFilter == AttendanceStatus.late
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(
                                  () => _historyFilter =
                                      _historyFilter == AttendanceStatus.late
                                      ? null
                                      : AttendanceStatus.late,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              FilterChip(
                                label: Text('معذور (${stats.excusedCount})'),
                                selected:
                                    _historyFilter == AttendanceStatus.excused,
                                selectedColor: AppColors.info.withValues(
                                  alpha: 0.2,
                                ),
                                checkmarkColor: AppColors.info,
                                labelStyle: TextStyle(
                                  color:
                                      _historyFilter == AttendanceStatus.excused
                                      ? AppColors.info
                                      : AppColors.textPrimary,
                                  fontWeight:
                                      _historyFilter == AttendanceStatus.excused
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) => setState(
                                  () => _historyFilter =
                                      _historyFilter == AttendanceStatus.excused
                                      ? null
                                      : AttendanceStatus.excused,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),

                        // History list or Empty View
                        if (displayedRecords.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.s16,
                            ),
                            child: AppEmptyView(
                              message: _historyFilter == AttendanceStatus.absent
                                  ? 'سجل ممتاز! لا توجد أي حالات غياب مسجلة 👏'
                                  : 'لا توجد جلسات مطابقة لخيار التصفية المحدد',
                              actionText: 'عرض جميع الجلسات',
                              onAction: () =>
                                  setState(() => _historyFilter = null),
                            ),
                          )
                        else
                          ...displayedRecords.map((record) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.s8,
                              ),
                              child: _AttendanceHistoryItemCard(record: record),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 140,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Container(
                width: 80,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Container(
                width: double.infinity,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        ResponsiveGrid(
          mobileColumns: 2,
          tabletColumns: 4,
          desktopColumns: 4,
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: List.generate(
            4,
            (_) => AppCard(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 30,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          child: Stack(
            children: [
              Positioned(
                top: -15,
                left: -15,
                child: IgnorePointer(
                  child: Text(
                    '%',
                    style: TextStyle(
                      fontSize: 100,
                      fontWeight: FontWeight.w900,
                      color: color.withValues(alpha: 0.04),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s8),
                                  const Text(
                                    'نسبة الالتزام بالحضور',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: AppTypography.statFigureLarge.copyWith(
                                  color: color,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                isHigh
                                    ? 'ممتاز! التزامك عالي بحضور الجلسات التعليمية.'
                                    : isMedium
                                    ? 'جيد، يرجى الحرص على عدم تكرار الغياب.'
                                    : 'تنبيه: نسبة حضورك منخفضة، راجع مدرسك.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                color.withValues(alpha: 0.18),
                                color.withValues(alpha: 0.08),
                              ],
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color.withValues(alpha: 0.25),
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            isHigh
                                ? Icons.verified_rounded
                                : isMedium
                                ? Icons.warning_amber_rounded
                                : Icons.error_outline_rounded,
                            size: 36,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceHistoryItemCard extends StatefulWidget {
  final AttendanceEntity record;

  const _AttendanceHistoryItemCard({required this.record});

  @override
  State<_AttendanceHistoryItemCard> createState() =>
      _AttendanceHistoryItemCardState();
}

class _AttendanceHistoryItemCardState
    extends State<_AttendanceHistoryItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final formattedDate = DateFormat(
      'EEEE، d MMMM yyyy',
      'ar',
    ).format(record.date);

    final statusColor = switch (record.status) {
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
              width: 1,
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
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Row(
            children: [
              // Date Icon Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('d', 'ar').format(record.date),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      DateFormat('MMM', 'ar').format(record.date),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s16),

              // Session Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (record.groupName != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        'المجموعة: ${record.groupName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (record.note != null && record.note!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8,
                          vertical: AppSpacing.s4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                        child: Text(
                          'ملاحظة: ${record.note}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Status Badge
              AttendanceStatusBadge(status: record.status),
            ],
          ),
        ),
      ),
    );
  }
}
