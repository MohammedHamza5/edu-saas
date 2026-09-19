import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../../../../core/widgets/animated_math_background.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../attendance/presentation/widgets/attendance_status_badge.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../notifications/presentation/cubit/notifications_cubit.dart';
import '../../../notifications/presentation/widgets/notification_badge_button.dart';
import '../../../parent/presentation/cubit/parent_cubit.dart';
import '../../../parent/presentation/cubit/parent_state.dart';
import '../../../parent/presentation/widgets/child_selector_bar.dart';
import '../../../parent/presentation/widgets/parent_academic_overview_card.dart';

class ParentDashboardPage extends StatelessWidget {
  final ParentCubit? cubit;

  const ParentDashboardPage({super.key, this.cubit});

  @override
  Widget build(BuildContext context) {
    if (cubit != null) {
      return BlocProvider<ParentCubit>.value(
        value: cubit!,
        child: const _ParentDashboardView(),
      );
    }

    try {
      context.read<ParentCubit>();
      return const _ParentDashboardView();
    } catch (_) {
      return BlocProvider<ParentCubit>(
        create: (_) =>
            InjectionContainer.createParentCubit()..loadParentDashboard(),
        child: const _ParentDashboardView(),
      );
    }
  }
}

class _ParentDashboardView extends StatefulWidget {
  const _ParentDashboardView();

  @override
  State<_ParentDashboardView> createState() => _ParentDashboardViewState();
}

class _ParentDashboardViewState extends State<_ParentDashboardView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NotificationsCubit>().loadNotifications();
      }
    });
  }

  Widget _buildSkeletonLoading() {
    return const AppLoadingView.dashboard();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.parentDashboardTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refreshDashboard,
            onPressed: () => context.read<ParentCubit>().refresh(),
          ),
          NotificationBadgeButton(
            onPressed: () => context.push(AppRoutes.notificationsCenter),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: context.l10n.logout,
            onPressed: () {
              context.read<AuthCubit>().logout();
              context.go(AppRoutes.login);
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF8FAFC),
        child: AnimatedMathBackground(
          opacity: 0.032,
          gridColor: const Color(0xFF6366F1),
          waveColor: const Color(0xFF38BDF8),
          gridSpacing: 38,
          showAxes: false,
          showWave: true,
          showFormulas: false,
          showNodes: false,
          cycleDuration: const Duration(seconds: 32),
          child: BlocBuilder<ParentCubit, ParentState>(
            builder: (context, state) {
              if (state is ParentLoading || state is ParentInitial) {
                return _buildSkeletonLoading();
              }

              if (state is ParentNoChildren) {
                return AppEmptyView(
                  icon: Icons.family_restroom_rounded,
                  message: context.l10n.parentNoChildrenLinked,
                  actionText: context.l10n.refreshDashboardButton,
                  onAction: () =>
                      context.read<ParentCubit>().loadParentDashboard(),
                );
              }

              if (state is ParentError) {
                return AppErrorView(
                  message: state.message,
                  onRetry: () =>
                      context.read<ParentCubit>().loadParentDashboard(),
                );
              }

              if (state is ParentLoaded) {
                return RefreshIndicator(
                  onRefresh: () => context.read<ParentCubit>().refresh(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: context.responsivePagePadding,
                    child: ResponsiveContainer(
                      maxWidth: ResponsiveBreakpoints.maxContentWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Academic Hero Banner
                          AcademicHeroBanner(
                            title: context.l10n.academicOverviewTitle,
                            subtitle: context.l10n.childRecentActivity,
                            badgeText: context.l10n.roleParent,
                          ),
                          const SizedBox(height: AppSpacing.s16),

                          // P-02: Child Selector Bar
                          ChildSelectorBar(
                            children: state.children,
                            selectedChild: state.selectedChild,
                            onChildSelected: (child) {
                              context.read<ParentCubit>().selectChild(child);
                            },
                          ),

                          const SizedBox(height: AppSpacing.s16),

                          if (state.isLoadingSummary)
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.s32,
                              ),
                              child: Center(
                                child: AppLoadingView.signature(size: 60),
                              ),
                            )
                          else if (state.summary != null) ...[
                            // P-01 & P-03: Academic Overview Cards
                            ParentAcademicOverviewCard(summary: state.summary!),

                            const SizedBox(height: AppSpacing.s20),

                            // P-06: Recent Attendance Section
                            _buildRecentAttendanceSection(context, state),

                            const SizedBox(height: AppSpacing.s20),

                            // P-05: Exam Results Section
                            _buildExamResultsSection(context, state),

                            const SizedBox(height: AppSpacing.s20),

                            // Guidance Information Card
                            AppCard(
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              backgroundColor: AppColors.primary.withValues(
                                alpha: 0.04,
                              ),
                              borderColor: AppColors.primaryLight.withValues(
                                alpha: 0.3,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context.l10n.parentNoticeTitle,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.s4),
                                        Text(
                                          context.l10n.parentNoticeDesc,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                            height: 1.5,
                                          ),
                                        ),
                                      ],
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
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRecentAttendanceSection(
    BuildContext context,
    ParentLoaded state,
  ) {
    final summary = state.summary!;
    final records = summary.recentAttendance;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.calendar_month_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    context.l10n.recentAttendanceSessions,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  context.l10n.lastFiveSessions,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
              child: Center(
                child: Text(
                  context.l10n.noAttendanceRecordsYet,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = records[index];
                final dateStr = DateFormat('yyyy/MM/dd').format(item.date);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                        child: const Icon(
                          Icons.event_note_rounded,
                          size: 16,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dateStr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (item.groupName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.groupName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                            if (item.note != null && item.note!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                context.l10n.noteLabel(item.note!),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.warning,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      AttendanceStatusBadge(status: item.status),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildExamResultsSection(BuildContext context, ParentLoaded state) {
    final summary = state.summary!;
    final exams = summary.recentExams;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    context.l10n.examResultsTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  context.l10n.approvedResults,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (exams.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
              child: Center(
                child: Text(
                  context.l10n.noExamResultsYet,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exams.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final exam = exams[index];
                final dateStr = DateFormat(
                  'yyyy/MM/dd',
                ).format(exam.submittedAt);
                final isPassing = exam.percentage >= 60.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color:
                              (isPassing ? AppColors.success : AppColors.error)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                        child: Icon(
                          isPassing
                              ? Icons.verified_rounded
                              : Icons.pending_actions_rounded,
                          size: 16,
                          color: isPassing
                              ? AppColors.success
                              : AppColors.error,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exam.examTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.l10n.submissionDateLabel(dateStr),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${exam.score.toStringAsFixed(0)} / ${exam.maxScore.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isPassing
                                          ? AppColors.success
                                          : AppColors.error)
                                      .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${exam.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPassing
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
