import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../dialogs/academic_report_dialog.dart';

import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/student_entity.dart';
import '../cubit/students_cubit.dart';
import '../cubit/students_state.dart';
import '../widgets/student_360_header_card.dart';
import '../widgets/student_360_stats_grid.dart';
import '../widgets/student_account_actions_card.dart';
import '../widgets/student_activity_timeline_section.dart';
import '../widgets/student_smart_engagement_card.dart';
import '../widgets/student_video_insights_section.dart';
import '../widgets/student_whatsapp_report_card.dart';

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

  Future<void> _confirmDeleteStudent(
    BuildContext context,
    StudentEntity student,
  ) async {
    final l10n = context.l10n;
    final cubit = context.read<StudentsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteStudentConfirmTitle),
        content: Text(l10n.deleteStudentConfirmBody(student.fullName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.deleteStudentAction),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (confirmed == true) {
      final ok = await cubit.deleteStudent(student.id);
      if (!context.mounted) return;
      if (ok) {
        AppFeedback.showSuccess(context, l10n.studentDeletedSuccess);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.studentsList);
        }
      }
    }
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
              : context.go(AppRoutes.studentsList),
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
                context.go(AppRoutes.assignGroups, extra: widget.studentId),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refresh,
            onPressed: () =>
                context.read<StudentsCubit>().loadStudent360(widget.studentId),
          ),
          BlocBuilder<StudentsCubit, StudentsState>(
            builder: (context, state) {
              if (state is Student360Loaded) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.mark_chat_read_rounded,
                        color: Color(0xFF25D366),
                      ),
                      tooltip: context.l10n.whatsappQuickActionTooltip,
                      onPressed: () {
                        final student = state.student;
                        AcademicReportDialog.show(
                          context,
                          studentId: student.id,
                          studentName: student.fullName,
                          parentPhone: student.parentPhone,
                          studentPhone: student.phone,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                      ),
                      tooltip: context.l10n.deleteStudentAction,
                      onPressed: () => _confirmDeleteStudent(context, state.student),
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header card ─────────────────────────────────────────
                    Student360HeaderCard(student: student),

                    const SizedBox(height: AppSpacing.s16),

                    // ── One-Click WhatsApp Parent Progress Report ──
                    StudentWhatsAppReportCard(
                      student: student,
                      stats: stats,
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // ── Stats grid ─────────────────────────────────────────
                    Student360StatsGrid(stats: stats),

                    const SizedBox(height: AppSpacing.s20),

                    // ── Groups ─────────────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: StudentSectionTitle(
                            context.l10n.enrolledStudyGroups,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => context.push(
                            AppRoutes.assignGroups,
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
                                                  context.l10n.joinedDateLabel(
                                                    _formatDate(g.joinedAt),
                                                  ),
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
                    const StudentSectionTitle(
                      'تتبع الحضور والتفاعل الفعلي (Smart Telemetry)',
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    StudentSmartEngagementCard(stats: stats),

                    // ── Video Insights Section ────────────────────────────
                    if (stats.videoInsights.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s20),
                      StudentVideoInsightsSection(insights: stats.videoInsights),
                    ],

                    // ── Activity Timeline Section ─────────────────────────
                    if (stats.recentActivities.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.s20),
                      StudentActivityTimelineSection(
                        activities: stats.recentActivities,
                      ),
                    ],

                    // ── Last activity fallback ─────────────────────────────
                    if (stats.lastActivityAt != null &&
                        stats.recentActivities.isEmpty) ...[
                      const SizedBox(height: AppSpacing.s20),
                      StudentSectionTitle(context.l10n.lastRecordedActivity),
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
                    StudentSectionTitle(context.l10n.accountActionsTitle),
                    const SizedBox(height: AppSpacing.s8),
                    StudentAccountActionsCard(student: student),
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

  String _formatDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';

  String _formatDateTime(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
