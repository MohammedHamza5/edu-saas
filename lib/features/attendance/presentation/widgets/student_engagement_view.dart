import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../domain/entities/attendance_entity.dart';
import 'attendance_stat_card.dart';
import 'student_lecture_engagement_card.dart';

class StudentEngagementView extends StatefulWidget {
  final StudentEngagementSummary summary;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final String? selectedGroupId;
  final ValueChanged<String?> onGroupChanged;

  const StudentEngagementView({
    super.key,
    required this.summary,
    required this.scrollController,
    required this.onRefresh,
    required this.selectedGroupId,
    required this.onGroupChanged,
  });

  @override
  State<StudentEngagementView> createState() => _StudentEngagementViewState();
}

class _StudentEngagementViewState extends State<StudentEngagementView> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    // Filter items to ONLY show lectures that have actually been watched!
    final watchedItems = summary.items
        .where((item) => item.hasWatchedAny)
        .toList();

    // Filter items based on active status filter (all watched, completed, in_progress)
    final filteredItems = watchedItems.where((item) {
      if (_statusFilter == 'completed') return item.isFullyWatched;
      if (_statusFilter == 'in_progress') return !item.isFullyWatched;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ResponsiveContainer(
        child: ListView(
          controller: widget.scrollController,
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

            // Status Filter Chips Bar (only when there are watched lectures)
            if (watchedItems.isNotEmpty) ...[
              _buildStatusFilterBar(
                context,
                summary,
                watchedCount: watchedItems.length,
              ),
              const SizedBox(height: AppSpacing.s16),
            ],

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
                if (watchedItems.isNotEmpty)
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
                      '${filteredItems.length} / ${watchedItems.length}',
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
            if (watchedItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                child: AppEmptyView(
                  message: context.l10n.noWatchedLecturesYet,
                  subtitle: context.l10n.noWatchedLecturesSubtitle,
                  icon: Icons.history_toggle_off_rounded,
                ),
              )
            else if (filteredItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s24),
                child: AppEmptyView(
                  message: context.l10n.noEngagementLecturesFilterEmpty,
                  icon: Icons.filter_list_off_rounded,
                ),
              )
            else
              ...filteredItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.s10),
                  child: StudentLectureEngagementCard(item: item),
                );
              }),

            const SizedBox(height: AppSpacing.s32),
          ],
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
          value:
              '${summary.completedLecturesCount} / ${summary.totalLecturesCount}',
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
            selected: widget.selectedGroupId == null,
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: widget.selectedGroupId == null
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: widget.selectedGroupId == null
                  ? AppColors.primary
                  : AppColors.textPrimary,
            ),
            onSelected: (val) {
              if (val) widget.onGroupChanged(null);
            },
          ),
          const SizedBox(width: AppSpacing.s8),
          ...groups.map((g) {
            final isSelected = widget.selectedGroupId == g.id;
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
                  widget.onGroupChanged(val ? g.id : null);
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
    StudentEngagementSummary summary, {
    required int watchedCount,
  }) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          FilterChip(
            label: Text(context.l10n.filterAllLecturesCount(watchedCount)),
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
              () => _statusFilter = _statusFilter == 'completed'
                  ? null
                  : 'completed',
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          FilterChip(
            label: Text(
              context.l10n.filterInProgressCount(
                summary.inProgressLecturesCount,
              ),
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
              () => _statusFilter = _statusFilter == 'in_progress'
                  ? null
                  : 'in_progress',
            ),
          ),
        ],
      ),
    );
  }
}
