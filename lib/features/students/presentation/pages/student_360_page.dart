import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../../core/utils/whatsapp_report_generator.dart';
import '../../domain/entities/student_entity.dart';
import '../../domain/entities/student_360_entity.dart';
import '../cubit/students_cubit.dart';
import '../cubit/students_state.dart';

/// T-04 — Student 360° Profile (Teacher view)
/// Shows: Groups + Attendance% + Assignments + Exam avg + Video% + Last activity
class Student360Page extends StatefulWidget {
  final String studentId;
  final StudentEntity? initialStudent;

  const Student360Page({
    super.key,
    required this.studentId,
    this.initialStudent,
  });

  @override
  State<Student360Page> createState() => _Student360PageState();
}

class _Student360PageState extends State<Student360Page> {
  @override
  void initState() {
    super.initState();
    context.read<StudentsCubit>().loadStudent360(widget.studentId);
  }

  Widget _buildSkeletonLoading() {
    return const AppLoadingView.profile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backToStudentsList,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRouter.studentsList),
        ),
        title: Text(
          widget.initialStudent?.fullName ?? context.l10n.studentProfileTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_rounded),
            tooltip: context.l10n.assignGroupsAction,
            onPressed: () =>
                context.go(AppRouter.assignGroups, extra: widget.studentId),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refresh,
            onPressed: () =>
                context.read<StudentsCubit>().loadStudent360(widget.studentId),
          ),
        ],
      ),
      body: BlocBuilder<StudentsCubit, StudentsState>(
        builder: (context, state) {
          if (state is Student360Loading) {
            return _buildSkeletonLoading();
          }

          if (state is StudentsError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<StudentsCubit>().loadStudent360(
                widget.studentId,
              ),
            );
          }

          if (state is Student360Loaded) {
            final student = state.student;
            final stats = state.stats;

            return SingleChildScrollView(
              padding: context.responsivePagePadding,
              child: ResponsiveContainer(
                maxWidth: ResponsiveBreakpoints.maxContentWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header card ─────────────────────────────────────────
                    AppCard(
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: AppColors.primaryLight.withValues(
                              alpha: 0.15,
                            ),
                            backgroundImage: student.avatarUrl != null
                                ? NetworkImage(student.avatarUrl!)
                                : null,
                            child: student.avatarUrl == null
                                ? Text(
                                    student.initials,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.s16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.fullName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        student.email,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (student.phone != null &&
                                    student.phone!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.phone_outlined,
                                        size: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          student.phone!,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 6),
                                _StatusBadge(status: student.status),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // ── One-Click WhatsApp Parent Progress Report ──
                    AppCard(
                      variant: AppCardVariant.elevated,
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 460;
                          if (isNarrow) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(AppSpacing.s8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.mark_chat_read_rounded,
                                        color: Color(0xFF25D366),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s12),
                                    Expanded(
                                      child: Text(
                                        context.l10n.whatsappParentReportTitle,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.s8),
                                Text(
                                  context.l10n.whatsappParentReportSubtitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.share_rounded, size: 16),
                                    label: Text(context.l10n.createAndShareReport),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF25D366),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.s8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusSmall,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      final report = WhatsAppReportGenerator.generateStudentWeeklyReport(
                                        studentName: student.fullName,
                                        groupName: stats.groups.isNotEmpty ? stats.groups.first.groupName : null,
                                        attendanceRate: (stats.attendancePercentage / 100).clamp(0.0, 1.0),
                                        videoWatchRate: (stats.videoCompletionPercentage / 100).clamp(0.0, 1.0),
                                        completedAssignments: stats.assignmentsSubmitted,
                                        totalAssignments: stats.assignmentsSubmitted > 0 ? stats.assignmentsSubmitted : 4,
                                        mockExamScore: stats.examAverage > 0 ? (stats.examAverage * 8).round() : 740,
                                        activeStudyMinutes: stats.todayActiveMinutes,
                                        engagementQualityText: _getEngagementText(stats.engagementQuality),
                                      );
                                      WhatsAppReportGenerator.showReportPreviewDialog(
                                        context,
                                        studentName: student.fullName,
                                        reportText: report,
                                        phone: student.phone,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.s8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366).withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mark_chat_read_rounded,
                                  color: Color(0xFF25D366),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.whatsappParentReportTitle,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      context.l10n.whatsappParentReportSubtitle,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.share_rounded, size: 16),
                                label: Text(context.l10n.createReport),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s16,
                                    vertical: AppSpacing.s8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  final report = WhatsAppReportGenerator.generateStudentWeeklyReport(
                                    studentName: student.fullName,
                                    groupName: stats.groups.isNotEmpty ? stats.groups.first.groupName : null,
                                    attendanceRate: (stats.attendancePercentage / 100).clamp(0.0, 1.0),
                                    videoWatchRate: (stats.videoCompletionPercentage / 100).clamp(0.0, 1.0),
                                    completedAssignments: stats.assignmentsSubmitted,
                                    totalAssignments: stats.assignmentsSubmitted > 0 ? stats.assignmentsSubmitted : 4,
                                    mockExamScore: stats.examAverage > 0 ? (stats.examAverage * 8).round() : 740,
                                    activeStudyMinutes: stats.todayActiveMinutes,
                                    engagementQualityText: _getEngagementText(stats.engagementQuality),
                                  );
                                  WhatsAppReportGenerator.showReportPreviewDialog(
                                    context,
                                    studentName: student.fullName,
                                    reportText: report,
                                    phone: student.phone,
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // ── Stats grid ─────────────────────────────────────────
                    _SectionTitle(context.l10n.statsOverviewTitle),
                    const SizedBox(height: AppSpacing.s8),
                    ResponsiveGrid(
                      mobileColumns: 2,
                      tabletColumns: 2,
                      desktopColumns: 4,
                      largeDesktopColumns: 4,
                      spacing: AppSpacing.s12,
                      runSpacing: AppSpacing.s12,
                      children: [
                        _StatCard(
                          icon: Icons.fact_check_rounded,
                          label: context.l10n.attendanceRateLabel,
                          value:
                              '${stats.attendancePercentage.toStringAsFixed(0)}%',
                          progress: (stats.attendancePercentage / 100).clamp(
                            0.0,
                            1.0,
                          ),
                          color: _pctColor(stats.attendancePercentage),
                        ),
                        _StatCard(
                          icon: Icons.assignment_turned_in_rounded,
                          label: context.l10n.submittedHomeworksLabel,
                          value: '${stats.assignmentsSubmitted}',
                          subtitle: context.l10n.reviewedSubtitle(stats.assignmentsReviewed),
                          progress: stats.assignmentsSubmitted > 0
                              ? (stats.assignmentsReviewed /
                                        stats.assignmentsSubmitted)
                                    .clamp(0.0, 1.0)
                              : null,
                          color: AppColors.info,
                        ),
                        _StatCard(
                          icon: Icons.quiz_rounded,
                          label: context.l10n.examAverageLabel,
                          value: '${stats.examAverage.toStringAsFixed(0)}%',
                          progress: (stats.examAverage / 100).clamp(0.0, 1.0),
                          color: _pctColor(stats.examAverage),
                        ),
                        _StatCard(
                          icon: Icons.play_circle_rounded,
                          label: context.l10n.videoCompletionLabel,
                          value:
                              '${stats.videoCompletionPercentage.toStringAsFixed(0)}%',
                          progress: (stats.videoCompletionPercentage / 100)
                              .clamp(0.0, 1.0),
                          color: _pctColor(stats.videoCompletionPercentage),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s20),

                    // ── Groups ─────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: _SectionTitle(context.l10n.enrolledStudyGroups),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push(
                            AppRouter.assignGroups,
                            extra: widget.studentId,
                          ),
                          icon: const Icon(Icons.edit_rounded, size: 14),
                          label: Text(
                            context.l10n.edit,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    stats.groups.isEmpty
                        ? AppEmptyView(
                            message: context.l10n.noGroupsAssignedToStudent,
                            icon: Icons.group_off_rounded,
                          )
                        : Column(
                            children: stats.groups
                                .map(
                                  (g) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.s8,
                                    ),
                                    child: AppCard(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.s16,
                                        vertical: AppSpacing.s12,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.groups_rounded,
                                            size: 18,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: AppSpacing.s12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  g.groupName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  context.l10n.joinedDateLabel(_formatDate(g.joinedAt)),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          AppBadge(
                                            label: g.groupLevel,
                                            variant: AppBadgeVariant.active,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),

                    const SizedBox(height: AppSpacing.s20),

                    // ── Smart Engagement Telemetry ────────────────────────
                    const _SectionTitle('تتبع الحضور والتفاعل الفعلي (Smart Telemetry)'),
                    const SizedBox(height: AppSpacing.s8),
                    _SmartEngagementCard(stats: stats),

                    // ── Video Insights Section ────────────────────────────
                    if (stats.videoInsights.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s20),
                      _VideoInsightsSection(insights: stats.videoInsights),
                    ],

                    // ── Activity Timeline Section ─────────────────────────
                    if (stats.recentActivities.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s20),
                      _ActivityTimelineSection(activities: stats.recentActivities),
                    ],

                    // ── Last activity fallback ─────────────────────────────
                    if (stats.lastActivityAt != null && stats.recentActivities.isEmpty) ...[
                      const SizedBox(height: AppSpacing.s20),
                      _SectionTitle(context.l10n.lastRecordedActivity),
                      const SizedBox(height: AppSpacing.s8),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.s12),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 16,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              _formatDateTime(stats.lastActivityAt!),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: AppSpacing.s24),

                    // ── Danger zone / Account actions ──────────────────────
                    _SectionTitle(context.l10n.accountActionsTitle),
                    const SizedBox(height: AppSpacing.s8),
                    _AccountActions(student: student),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  String _getEngagementText(EngagementQuality quality) {
    switch (quality) {
      case EngagementQuality.active:
        return 'حضور نشط ومتفاعل';
      case EngagementQuality.moderate:
        return 'تفاعل متوسط';
      case EngagementQuality.ghostPresence:
        return 'حضور شكلي / يحتاج متابعة';
      case EngagementQuality.noData:
        return 'لم يدخل المنصة اليوم';
    }
  }

  Color _pctColor(double pct) {
    if (pct >= 75) return AppColors.success;
    if (pct >= 50) return AppColors.warning;
    return AppColors.error;
  }

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  String _formatDateTime(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ── Sub-widgets ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.3,
    ),
  );
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;
  final double? progress;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.progress,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = context.screenWidth < 360;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            value,
            style:
                (isCompact
                        ? AppTypography.headingLarge
                        : AppTypography.statFigureLarge)
                    .copyWith(color: color),
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.s6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: LinearProgressIndicator(
                value: progress!,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.s4),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, variant) = switch (status) {
      'active' => (context.l10n.active, AppBadgeVariant.active),
      'pending' => (context.l10n.pendingApproval, AppBadgeVariant.pending),
      'suspended' => (context.l10n.suspended, AppBadgeVariant.suspended),
      _ => (context.l10n.rejected, AppBadgeVariant.neutral),
    };
    return AppBadge(label: label, variant: variant);
  }
}

class _AccountActions extends StatelessWidget {
  final StudentEntity student;
  const _AccountActions({required this.student});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          if (student.isActive)
            ListTile(
              leading: const Icon(
                Icons.pause_circle_outline_rounded,
                color: AppColors.warning,
              ),
              title: Text(context.l10n.suspendAccountTemporary),
              subtitle: Text(context.l10n.suspendAccountDesc),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () async {
                final ok = await _confirm(
                  context,
                  title: context.l10n.suspendStudentConfirmTitle,
                  body: context.l10n.suspendStudentConfirmBody(student.fullName),
                  label: context.l10n.suspendStudentAction,
                  color: AppColors.warning,
                );
                if (ok && context.mounted) {
                  await context.read<StudentsCubit>().changeStatus(
                    studentId: student.id,
                    action: 'suspend',
                  );
                  if (context.mounted) {
                    await context.read<StudentsCubit>().loadStudent360(
                      student.id,
                    );
                  }
                }
              },
            ),
          if (student.isSuspended)
            ListTile(
              leading: const Icon(
                Icons.play_circle_outline_rounded,
                color: AppColors.success,
              ),
              title: Text(context.l10n.reactivateAccountTitle),
              subtitle: Text(context.l10n.reactivateAccountDesc),
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
              onTap: () async {
                final ok = await _confirm(
                  context,
                  title: context.l10n.activateStudentConfirmTitle,
                  body: context.l10n.activateStudentConfirmBody(student.fullName),
                  label: context.l10n.activateStudentAction,
                  color: AppColors.success,
                );
                if (ok && context.mounted) {
                  await context.read<StudentsCubit>().changeStatus(
                    studentId: student.id,
                    action: 'activate',
                  );
                  if (context.mounted) {
                    await context.read<StudentsCubit>().loadStudent360(
                      student.id,
                    );
                  }
                }
              },
            ),
          if (student.isPending) ...[
            ListTile(
              leading: const Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
              ),
              title: Text(context.l10n.approveAndAdmitStudentTitle),
              onTap: () async {
                final ok = await _confirm(
                  context,
                  title: context.l10n.approveStudentConfirmTitle,
                  body: context.l10n.approveStudentConfirmBody(student.fullName),
                  label: context.l10n.approveStudentAction,
                  color: AppColors.success,
                );
                if (ok && context.mounted) {
                  await context.read<StudentsCubit>().changeStatus(
                    studentId: student.id,
                    action: 'approve',
                  );
                  if (context.mounted) {
                    await context.read<StudentsCubit>().loadStudent360(
                      student.id,
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.highlight_off, color: AppColors.error),
              title: Text(context.l10n.rejectRequestAction),
              onTap: () async {
                final ok = await _confirm(
                  context,
                  title: context.l10n.rejectStudentConfirmTitle,
                  body: context.l10n.rejectStudentConfirmBody(student.fullName),
                  label: context.l10n.rejectStudentAction,
                  color: AppColors.error,
                );
                if (ok && context.mounted) {
                  await context.read<StudentsCubit>().changeStatus(
                    studentId: student.id,
                    action: 'reject',
                  );
                  if (context.mounted) {
                    await context.read<StudentsCubit>().loadStudent360(
                      student.id,
                    );
                  }
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String label,
    required Color color,
  }) async {
    return (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: color),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(label),
              ),
            ],
          ),
        )) ??
        false;
  }
}

// ── Smart Engagement Telemetry Widgets ────────────────────────────────────────

class _SmartEngagementCard extends StatelessWidget {
  final Student360Entity stats;
  const _SmartEngagementCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final quality = stats.engagementQuality;
    final (qualityLabel, qualityColor, qualityIcon) = switch (quality) {
      EngagementQuality.active => (
        context.l10n.qualityActive,
        AppColors.success,
        Icons.verified_rounded,
      ),
      EngagementQuality.moderate => (
        context.l10n.qualityModerate,
        AppColors.warning,
        Icons.timelapse_rounded,
      ),
      EngagementQuality.ghostPresence => (
        context.l10n.qualityGhostPresence,
        AppColors.error,
        Icons.warning_amber_rounded,
      ),
      EngagementQuality.noData => (
        context.l10n.qualityNoData,
        AppColors.textMuted,
        Icons.bedtime_outlined,
      ),
    };

    final activeMins = stats.todayActiveMinutes;
    final idleMins = stats.todayIdleMinutes;
    final activeRatio = (stats.todayActiveRatio * 100).round();

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              final badgeWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: qualityColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(color: qualityColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(qualityIcon, size: 13, color: qualityColor),
                    const SizedBox(width: 4),
                    Text(
                      qualityLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: qualityColor,
                      ),
                    ),
                  ],
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                          ),
                          child: const Icon(
                            Icons.insights_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Text(
                            context.l10n.smartTelemetryTitle,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      context.l10n.smartTelemetryDesc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    badgeWidget,
                  ],
                );
              }

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.smartTelemetryTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          context.l10n.smartTelemetryDesc,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  badgeWidget,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.s16),
          // Progress bar of active vs idle
          if (activeMins > 0 || idleMins > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    Expanded(
                      flex: activeMins > 0 ? activeMins : 1,
                      child: Container(color: AppColors.success),
                    ),
                    if (idleMins > 0)
                      Expanded(
                        flex: idleMins,
                        child: Container(color: AppColors.warning.withValues(alpha: 0.7)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.activeMinutesWithRatio(activeMins, activeRatio),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.7), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.idleMinutesWithCount(idleMins),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
          ],
          // Metrics Grid
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MiniTelemetryItem(
                    icon: Icons.timer_outlined,
                    label: context.l10n.activeTodayLabel,
                    value: context.l10n.minutesShort(activeMins),
                    valueColor: AppColors.success,
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(
                  child: _MiniTelemetryItem(
                    icon: Icons.pause_circle_outline,
                    label: context.l10n.idleTodayLabel,
                    value: context.l10n.minutesShort(idleMins),
                    valueColor: AppColors.warning,
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(
                  child: _MiniTelemetryItem(
                    icon: Icons.login_rounded,
                    label: context.l10n.firstLoginLabel,
                    value: stats.firstSeenToday != null ? _formatTimeOnly(context, stats.firstSeenToday!) : '—',
                  ),
                ),
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(
                  child: _MiniTelemetryItem(
                    icon: Icons.date_range_rounded,
                    label: context.l10n.active7DaysLabel,
                    value: context.l10n.minutesShort(stats.totalActiveMinutes7d),
                    valueColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimeOnly(BuildContext context, DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? context.l10n.pmPeriod : context.l10n.amPeriod;
    return '${hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}

class _MiniTelemetryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _MiniTelemetryItem({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _VideoInsightsSection extends StatelessWidget {
  final List<StudentVideoInsight> insights;
  const _VideoInsightsSection({required this.insights});

  @override
  Widget build(BuildContext context) {
    if (insights.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(context.l10n.videoIntegrityTitle),
        const SizedBox(height: AppSpacing.s8),
        ...insights.map((item) {
          final isSkipped = item.isSuspicious;
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.completed ? Icons.check_circle_rounded : Icons.play_circle_fill_rounded,
                        color: item.completed ? AppColors.success : AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          item.videoTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSkipped)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.fast_forward_rounded, size: 12, color: AppColors.error),
                              const SizedBox(width: 3),
                              Text(
                                context.l10n.videoFastForwardWarning,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ],
                          ),
                        )
                      else if (item.completed)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            context.l10n.videoCompletedHonest,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                          ),
                          child: Text(
                            context.l10n.videoPercentageCompleted(item.percentage.toStringAsFixed(0)),
                            style: const TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  // Progress indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    child: LinearProgressIndicator(
                      value: (item.percentage / 100).clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: AppColors.border,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isSkipped ? AppColors.warning : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.actualWatchMinutesRatio(item.actualWatchMinutes, item.durationMinutes),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSkipped ? AppColors.error : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        context.l10n.lastWatchedLabel(_formatShortDate(item.lastWatchedAt)),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  static String _formatShortDate(DateTime dt) => '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
}

class _ActivityTimelineSection extends StatelessWidget {
  final List<StudentActivityItem> activities;
  const _ActivityTimelineSection({required this.activities});

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(context.l10n.activityTimelineTitle),
        const SizedBox(height: AppSpacing.s8),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
          child: Column(
            children: activities.take(8).map((act) {
              final (label, icon, color) = switch (act.eventType) {
                'login' => (context.l10n.eventLogin, Icons.login_rounded, AppColors.info),
                'content_opened' => (context.l10n.eventContentOpened, Icons.menu_book_rounded, AppColors.primary),
                'video_started' => (context.l10n.eventVideoStarted, Icons.play_circle_outline_rounded, AppColors.primary),
                'video_completed' => (context.l10n.eventVideoCompleted, Icons.check_circle_outline_rounded, AppColors.success),
                'assignment_submitted' => (context.l10n.eventAssignmentSubmitted, Icons.assignment_turned_in_outlined, AppColors.success),
                'exam_started' => (context.l10n.eventExamStarted, Icons.timer_outlined, AppColors.warning),
                'exam_submitted' => (context.l10n.eventExamSubmitted, Icons.grading_rounded, AppColors.success),
                _ => (act.eventType, Icons.circle, AppColors.textSecondary),
              };

              final itemTitle = act.contentTitle ?? act.groupName;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 14, color: color),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                          if (itemTitle != null)
                            Text(
                              itemTitle,
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Text(
                      _formatRelativeTime(context, act.createdAt),
                      style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  static String _formatRelativeTime(BuildContext context, DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return context.l10n.minutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return context.l10n.hoursAgo(diff.inHours);
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}
