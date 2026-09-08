import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/attendance_stat_card.dart';
import '../widgets/attendance_status_badge.dart';

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

  @override
  void initState() {
    super.initState();
    _attendanceCubit = widget.attendanceCubit ?? InjectionContainer.createAttendanceCubit();

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
              return const AppLoadingView(message: 'جارٍ تحميل سجل الحضور...');
            }

            if (state is AttendanceError) {
              return AppErrorView(
                message: state.message,
                onRetry: _loadData,
              );
            }

            if (state is StudentAttendanceLoaded) {
              final records = state.records;
              final stats = state.stats;

              if (records.isEmpty) {
                return const AppEmptyView(
                  message: 'لا يوجد سجلات حضور\nلم يتم تسجيل أي حضور أو غياب لك في المجموعات حتى الآن.',
                  icon: Icons.event_available_rounded,
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _loadData(),
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  children: [
                    // Top Highlight Card: Attendance Percentage
                    _buildPercentageCard(stats.attendancePercentage),
                    const SizedBox(height: AppSpacing.s16),

                    // Metrics Breakdown
                    Row(
                      children: [
                        Expanded(
                          child: AttendanceStatCard(
                            title: 'حاضر',
                            value: '${stats.presentCount}',
                            color: AppColors.success,
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: AttendanceStatCard(
                            title: 'غياب',
                            value: '${stats.absentCount}',
                            color: AppColors.error,
                            icon: Icons.cancel_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: AttendanceStatCard(
                            title: 'تأخير',
                            value: '${stats.lateCount}',
                            color: AppColors.warning,
                            icon: Icons.access_time_filled_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: AttendanceStatCard(
                            title: 'معذور',
                            value: '${stats.excusedCount}',
                            color: AppColors.info,
                            icon: Icons.info_rounded,
                          ),
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

                    // History list
                    ...records.map((record) {
                      final formattedDate =
                          DateFormat('EEEE، d MMMM yyyy', 'ar').format(record.date);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.s16),
                          child: Row(
                            children: [
                              // Date Icon Badge
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
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
                                          borderRadius:
                                              BorderRadius.circular(AppSpacing.radiusSmall),
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
                      );
                    }),
                  ],
                ),
              );
            }

            return const SizedBox.shrink();
          },
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

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نسبة الالتزام بالحضور',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: AppTypography.statFigureLarge.copyWith(
                    color: color,
                    fontSize: 36,
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
              color: color.withAlpha(25),
              shape: BoxShape.circle,
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
    );
  }
}
