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
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/utils/group_slug_resolver.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/entities/attendance_entity.dart';
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
  final ScrollController _scrollController = ScrollController();
  late final AttendanceCubit _attendanceCubit;
  String? _resolvedStudentId;
  String? _selectedGroupId;
  String? _statusFilter; // null or 'all', 'completed', 'in_progress', 'not_started'
  AttendanceStatus? _historyFilter;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
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

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _attendanceCubit.loadMoreStudentAttendance();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    if (widget.attendanceCubit == null) {
      _attendanceCubit.close();
    }
    super.dispose();
  }

  void _loadData() {
    if (_resolvedStudentId != null) {
      _attendanceCubit.loadStudentAttendance(
        studentId: _resolvedStudentId!,
        groupId: _selectedGroupId,
      );
    }
  }

  void _onGroupChanged(String? newGroupId) {
    if (newGroupId == _selectedGroupId) return;
    setState(() {
      _selectedGroupId = newGroupId;
    });
    if (_resolvedStudentId != null) {
      _attendanceCubit.filterStudentByGroup(newGroupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _attendanceCubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: context.l10n.backTooltip,
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go(AppRoutes.studentDashboard);
              }
            },
          ),
          title: Text(context.l10n.studentEngagementPageTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: context.l10n.refreshDashboard,
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
              final summary = state.engagementSummary;

              // If engagement telemetry is loaded, present the Online Engagement Dashboard
              if (summary != null) {
                return _buildEngagementView(context, state, summary);
              }

              // Fallback for tests or environments with pure physical attendance records
              return _buildLegacyAttendanceView(context, state);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  /// Modern Academic Online SaaS Engagement View
  Widget _buildEngagementView(
    BuildContext context,
    StudentAttendanceLoaded state,
    StudentEngagementSummary summary,
  ) {
    final hasLectures = summary.totalLecturesCount > 0;

    // Filter items based on active status filter
    final filteredItems = summary.items.where((item) {
      if (_statusFilter == 'completed') return item.isFullyWatched;
      if (_statusFilter == 'in_progress') {
        return !item.isFullyWatched && item.hasWatchedAny;
      }
      if (_statusFilter == 'not_started') return !item.hasWatchedAny;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: Center(
        child: ResponsiveContainer(
          maxWidth: ResponsiveBreakpoints.maxContentWidth,
          child: ListView(
            controller: _scrollController,
            padding: context.responsivePagePadding,
            children: [
              // Hero Header with Telemetry Badge
              _buildHeroHeader(context),
              const SizedBox(height: AppSpacing.s16),

              // Top 4 Academic Engagement Metric Cards (Responsive Grid)
              _buildMetricCards(context, summary),
              const SizedBox(height: AppSpacing.s20),

              // Group Selection Bar (if student belongs to multiple groups)
              if (summary.enrolledGroups.length > 1) ...[
                _buildGroupSelectorBar(context, summary.enrolledGroups),
                const SizedBox(height: AppSpacing.s16),
              ],

              // Status Filter Chips Bar
              _buildStatusFilterBar(context, summary),
              const SizedBox(height: AppSpacing.s16),

              // Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.video_library_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        context.l10n.lectureWatchTimelineTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s10,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${filteredItems.length} / ${summary.totalLecturesCount}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // Lecture Items List or Empty View
              if (!hasLectures)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                  child: AppEmptyView(
                    message: context.l10n.noEngagementLecturesEmpty,
                    icon: Icons.video_library_outlined,
                    actionText: context.l10n.goToStudyMaterialsAction,
                    onAction: () => context.go(AppRoutes.studentDashboard),
                  ),
                )
              else if (filteredItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                  child: AppEmptyView(
                    message: context.l10n.noEngagementLecturesFilterEmpty,
                    icon: Icons.filter_list_off_rounded,
                    actionText: context.l10n.viewAllSessionsAction,
                    onAction: () => setState(() => _statusFilter = null),
                  ),
                )
              else
                ...filteredItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.s10),
                    child: _StudentLectureEngagementCard(item: item),
                  );
                }),

              const SizedBox(height: AppSpacing.s32),
            ],
          ),
        ),
      ),
    );
  }

  /// Modern SaaS Hero Header
  Widget _buildHeroHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: AppColors.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.studentEngagementPageTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.success.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        context.l10n.studentEngagementBadge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.studentEngagementPageSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Top 4 Academic Engagement Metric Cards
  Widget _buildMetricCards(
    BuildContext context,
    StudentEngagementSummary summary,
  ) {
    final commitmentPct = summary.overallCommitmentPercentage;
    final isCommittedHigh = commitmentPct >= 80.0;
    final isCommittedMed = commitmentPct >= 50.0 && commitmentPct < 80.0;

    final commitmentColor = isCommittedHigh
        ? AppColors.success
        : isCommittedMed
        ? AppColors.warning
        : AppColors.info;

    final commitmentNote = isCommittedHigh
        ? context.l10n.excellentCommitment
        : isCommittedMed
        ? context.l10n.goodCommitment
        : context.l10n.needsFollowupCommitment;

    final remainingLectures =
        summary.notStartedLecturesCount + summary.inProgressLecturesCount;

    final formattedLastActive = summary.lastActiveAt != null
        ? DateFormat(
            'd MMM, hh:mm a',
            Localizations.localeOf(context).languageCode,
          ).format(summary.lastActiveAt!)
        : context.l10n.noActivityRecordedYet;

    return ResponsiveGrid(
      mobileColumns: 2,
      tabletColumns: 4,
      desktopColumns: 4,
      spacing: AppSpacing.s10,
      runSpacing: AppSpacing.s10,
      children: [
        AttendanceStatCard(
          title: context.l10n.totalWatchTimeTitle,
          value: summary.formattedTotalWatchHours,
          subtitle: context.l10n.totalCourseDurationSubtitle(
            summary.formattedTotalDurationHours,
          ),
          color: AppColors.primary,
          icon: Icons.timer_outlined,
        ),
        AttendanceStatCard(
          title: context.l10n.completedLecturesStatTitle,
          value: '${summary.completedLecturesCount} / ${summary.totalLecturesCount}',
          subtitle: context.l10n.remainingLecturesSubtitle(remainingLectures),
          color: AppColors.success,
          icon: Icons.check_circle_rounded,
        ),
        AttendanceStatCard(
          title: context.l10n.watchCommitmentRateTitle,
          value: '${commitmentPct.toStringAsFixed(0)}%',
          subtitle: commitmentNote,
          color: commitmentColor,
          icon: Icons.trending_up_rounded,
        ),
        AttendanceStatCard(
          title: context.l10n.lastPlatformActivityTitle,
          value: formattedLastActive,
          subtitle: context.l10n.recentWatchSession,
          color: AppColors.info,
          icon: Icons.history_rounded,
        ),
      ],
    );
  }

  /// Group Selector Bar
  Widget _buildGroupSelectorBar(
    BuildContext context,
    List<StudentGroupInfo> groups,
  ) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: Text(context.l10n.filterAllGroups),
            selected: _selectedGroupId == null,
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight:
                  _selectedGroupId == null ? FontWeight.bold : FontWeight.normal,
              color: _selectedGroupId == null
                  ? AppColors.primary
                  : AppColors.textPrimary,
            ),
            onSelected: (val) {
              if (val) _onGroupChanged(null);
            },
          ),
          const SizedBox(width: AppSpacing.s8),
          ...groups.map((g) {
            final isSelected = _selectedGroupId == g.id;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s8),
              child: ChoiceChip(
                label: Text(g.name),
                selected: isSelected,
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
                onSelected: (val) {
                  _onGroupChanged(val ? g.id : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Status Filter Chips Bar
  Widget _buildStatusFilterBar(
    BuildContext context,
    StudentEngagementSummary summary,
  ) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: Text(
              context.l10n.filterAllLecturesCount(summary.totalLecturesCount),
            ),
            selected: _statusFilter == null || _statusFilter == 'all',
            selectedColor: AppColors.primaryLight.withValues(alpha: 0.25),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              color: (_statusFilter == null || _statusFilter == 'all')
                  ? AppColors.primary
                  : AppColors.textPrimary,
              fontWeight: (_statusFilter == null || _statusFilter == 'all')
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 12,
            ),
            onSelected: (_) => setState(() => _statusFilter = null),
          ),
          const SizedBox(width: AppSpacing.s8),
          FilterChip(
            label: Text(
              context.l10n.filterCompletedCount(summary.completedLecturesCount),
            ),
            selected: _statusFilter == 'completed',
            selectedColor: AppColors.success.withValues(alpha: 0.2),
            checkmarkColor: AppColors.success,
            labelStyle: TextStyle(
              color: _statusFilter == 'completed'
                  ? AppColors.success
                  : AppColors.textPrimary,
              fontWeight: _statusFilter == 'completed'
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 12,
            ),
            onSelected: (_) => setState(
              () => _statusFilter =
                  _statusFilter == 'completed' ? null : 'completed',
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          FilterChip(
            label: Text(
              context.l10n.filterInProgressCount(summary.inProgressLecturesCount),
            ),
            selected: _statusFilter == 'in_progress',
            selectedColor: AppColors.warning.withValues(alpha: 0.2),
            checkmarkColor: AppColors.warning,
            labelStyle: TextStyle(
              color: _statusFilter == 'in_progress'
                  ? AppColors.warning
                  : AppColors.textPrimary,
              fontWeight: _statusFilter == 'in_progress'
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 12,
            ),
            onSelected: (_) => setState(
              () => _statusFilter =
                  _statusFilter == 'in_progress' ? null : 'in_progress',
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          FilterChip(
            label: Text(
              context.l10n.filterNotStartedCount(summary.notStartedLecturesCount),
            ),
            selected: _statusFilter == 'not_started',
            selectedColor: AppColors.border.withValues(alpha: 0.4),
            checkmarkColor: AppColors.textSecondary,
            labelStyle: TextStyle(
              color: _statusFilter == 'not_started'
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: _statusFilter == 'not_started'
                  ? FontWeight.bold
                  : FontWeight.normal,
              fontSize: 12,
            ),
            onSelected: (_) => setState(
              () => _statusFilter =
                  _statusFilter == 'not_started' ? null : 'not_started',
            ),
          ),
        ],
      ),
    );
  }

  /// Fallback view for pure physical records in test suites
  Widget _buildLegacyAttendanceView(
    BuildContext context,
    StudentAttendanceLoaded state,
  ) {
    final records = state.records;
    final stats = state.stats;

    if (records.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => _loadData(),
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
            controller: _scrollController,
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
                  child: _AttendanceHistoryItemCard(record: record),
                );
              }),
            ],
          ),
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

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: AcademicShimmer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 140,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Container(
                  width: 80,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
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
              child: AcademicShimmer(
                child: Container(
                  height: 60,
                  color: const Color(0xFFE2E8F0),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single Lecture Engagement Card with Watch Progress Telemetry
class _StudentLectureEngagementCard extends StatefulWidget {
  final StudentLectureEngagementItem item;

  const _StudentLectureEngagementCard({required this.item});

  @override
  State<_StudentLectureEngagementCard> createState() =>
      _StudentLectureEngagementCardState();
}

class _StudentLectureEngagementCardState
    extends State<_StudentLectureEngagementCard> {
  bool _isHovered = false;

  void _navigateToLecture(BuildContext context) {
    final slug = GroupSlugResolver.toSlug(
      widget.item.groupId,
      widget.item.groupName,
    );
    context.go(
      AppRoutes.studentGroupContent.replaceAll(':groupId', slug),
      extra: widget.item.lectureTitle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isCompleted = item.isFullyWatched;
    final hasStarted = item.hasWatchedAny;

    final statusColor = isCompleted
        ? AppColors.success
        : hasStarted
        ? AppColors.warning
        : AppColors.textSecondary;

    final statusBadge = isCompleted
        ? context.l10n.lectureCompletedBadge
        : hasStarted
        ? context.l10n.lectureInProgressBadge
        : context.l10n.lectureNotStartedBadge;

    final actionLabel = isCompleted
        ? context.l10n.rewatchLectureAction
        : hasStarted
        ? context.l10n.resumeLectureAction
        : context.l10n.startLectureAction;

    final actionIcon = isCompleted
        ? Icons.replay_rounded
        : Icons.play_arrow_rounded;

    final lastWatchedText = item.lastWatchedAt != null
        ? context.l10n.lastWatchedAtLabel(
            DateFormat(
              'd MMMM yyyy, hh:mm a',
              Localizations.localeOf(context).languageCode,
            ).format(item.lastWatchedAt!),
          )
        : context.l10n.notWatchedYetLabel;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(0, _isHovered ? -2.0 : 0.0, 0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: _isHovered
                ? statusColor.withValues(alpha: 0.35)
                : AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isHovered ? 0.05 : 0.02),
              blurRadius: _isHovered ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, Group Badge & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.verified_rounded
                        : hasStarted
                        ? Icons.play_arrow_rounded
                        : Icons.play_circle_outline_rounded,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.lectureTitle,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Text(
                              statusBadge,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.groupName.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.groupName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            // Middle: Watch Progress & Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.formattedDuration.isNotEmpty
                      ? context.l10n.watchedTimeOutOfTotal(
                          item.formattedWatchTime,
                          item.formattedDuration,
                        )
                      : item.formattedWatchTime,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '${item.watchProgressPercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s6),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (item.watchProgressPercent / 100.0).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Bottom Row: Last Watched Date & Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lastWatchedText,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                AppButton(
                  text: actionLabel,
                  icon: actionIcon,
                  variant: isCompleted
                      ? AppButtonVariant.outlined
                      : AppButtonVariant.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s8,
                  ),
                  onPressed: () => _navigateToLecture(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Fallback card for legacy attendance unit tests
class _AttendanceHistoryItemCard extends StatelessWidget {
  final AttendanceEntity record;

  const _AttendanceHistoryItemCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final formattedDate = DateFormat(
      'EEEE, d MMMM yyyy',
      locale,
    ).format(record.date);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (record.groupName != null)
                  Text(
                    record.groupName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          AttendanceStatusBadge(status: record.status),
        ],
      ),
    );
  }
}
