import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';

/// Test preparation cohorts and study groups list view for the teacher dashboard.
class TeacherTestPrepCohortsList extends StatelessWidget {
  final GroupsState? groupsState;

  const TeacherTestPrepCohortsList({
    super.key,
    this.groupsState,
  });

  @override
  Widget build(BuildContext context) {
    if (groupsState is GroupsLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.s24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (groupsState is GroupsLoaded) {
      final groups = (groupsState as GroupsLoaded).groups;
      if (groups.isEmpty) {
        return AppCard(
          variant: AppCardVariant.standard,
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups_outlined,
                    color: AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Text(
                  context.l10n.noGroupsAvailable,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  context.l10n.createGroupFirstNotice(context.l10n.navGroups),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(context.l10n.createNewGroup),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s10,
                    ),
                  ),
                  onPressed: () => CreateGroupDialog.show(context),
                ),
              ],
            ),
          ),
        );
      }

      final colors = [
        const Color(0xFF818CF8), // Indigo
        const Color(0xFF2DD4BF), // Teal
        const Color(0xFFFB7185), // Rose
        const Color(0xFFA78BFA), // Purple
        const Color(0xFFFBBF24), // Amber
      ];

      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
        itemBuilder: (context, i) {
          final group = groups[i];
          final color = colors[i % colors.length];

          return AppCard(
            variant: AppCardVariant.elevated,
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: LayoutBuilder(
              builder: (context, cardConstraints) {
                final isNarrow = cardConstraints.maxWidth < 450;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isNarrow) ...[
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.8)],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '∑',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Text(
                        group.level,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppBadge(
                            label:
                                '${group.membersCount} ${context.l10n.navStudents}',
                            variant: AppBadgeVariant.active,
                          ),
                          Text(
                            group.description ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [color, color.withValues(alpha: 0.8)],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                '∑',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  group.level,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              AppBadge(
                                label:
                                    '${group.membersCount} ${context.l10n.navStudents}',
                                variant: AppBadgeVariant.active,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                group.description ?? '—',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.s12),
                    const Divider(height: 1),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: [
                        ActionChip(
                          avatar: const Icon(
                            Icons.folder_shared_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            context.l10n.chipHandoutsPdfs,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                          side: const BorderSide(color: AppColors.border),
                          onPressed: () => context.push(
                            '${AppRoutes.teacherGroupContent.replaceAll(':groupId', group.id)}?name=${Uri.encodeComponent(group.name)}',
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.assignment_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          label: Text(
                            context.l10n.chipDrillHomework,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                          side: const BorderSide(color: AppColors.border),
                          onPressed: () => context.push(
                            '${AppRoutes.teacherGroupAssignments.replaceAll(':groupId', group.id)}?name=${Uri.encodeComponent(group.name)}',
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.quiz_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          label: Text(
                            context.l10n.chipExamsSimulations,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                          side: const BorderSide(color: AppColors.border),
                          onPressed: () => context.push(
                            '${AppRoutes.teacherGroupExams.replaceAll(':groupId', group.id)}?name=${Uri.encodeComponent(group.name)}',
                          ),
                        ),
                        ActionChip(
                          avatar: const Icon(
                            Icons.fact_check_rounded,
                            size: 14,
                            color: AppColors.success,
                          ),
                          label: Text(
                            context.l10n.chipRecordAttendance,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          backgroundColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                          side: const BorderSide(color: AppColors.border),
                          onPressed: () => context.push(
                            '${AppRoutes.teacherAttendance}?groupId=${group.id}',
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          );
        },
      );
    }

    // Default Academic Test Prep Cohorts (shown when groups are not loaded or in standalone previews)
    final defaultCohorts = [
      {
        'title': 'Digital SAT Master (Target 800)',
        'target': 'Digital SAT • August',
        'level': 'SAT Module 1 & 2 Hard',
        'members': '5 Students',
        'score': '740 / 800',
        'focus': 'Desmos Shortcuts + Advanced Quadratics & Circles',
        'color': const Color(0xFF818CF8),
      },
      {
        'title': 'EST I & EST II Intensive',
        'target': 'Egyptian Universities • October EST',
        'level': 'EST Math I & II',
        'members': '5 Students',
        'score': '690 / 800',
        'focus': 'Coordinate Geometry & Exponential Modeling',
        'color': const Color(0xFF2DD4BF),
      },
      {
        'title': 'ACT Math Sprint Drills',
        'target': 'ACT Speed • 45Q in 50M',
        'level': 'Time-Constrained Drills',
        'members': '5 Students',
        'score': '32 / 36',
        'focus': 'Trigonometry & Rapid Problem Solving',
        'color': const Color(0xFFFB7185),
      },
      {
        'title': 'Advanced Math & Problem Solving',
        'target': 'Level 2 • High Scorers',
        'level': 'Algebra & Functions Mastery',
        'members': '5 Students',
        'score': '88% Mastery',
        'focus': 'Nonlinear equations & Systems',
        'color': const Color(0xFFA78BFA),
      },
      {
        'title': 'Basics & Foundations Cohort',
        'target': 'Level 1 • Diagnostic',
        'level': 'Core Foundations',
        'members': '5 Students',
        'score': '82% Mastery',
        'focus': 'Linear Equations, Ratios, & Percentages',
        'color': const Color(0xFFFBBF24),
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: defaultCohorts.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
      itemBuilder: (context, i) {
        final cohort = defaultCohorts[i];
        final color = cohort['color'] as Color;

        return AppCard(
          variant: AppCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: LayoutBuilder(
            builder: (context, cardConstraints) {
              final isNarrow = cardConstraints.maxWidth < 450;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isNarrow) ...[
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.8)],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '∑',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            cohort['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Text(
                      '${context.l10n.academicFocusLabel}${cohort['focus']}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppBadge(
                          label: cohort['target'] as String,
                          variant: AppBadgeVariant.active,
                        ),
                        Text(
                          '${context.l10n.averageScoreLabel}${cohort['score']}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [color, color.withValues(alpha: 0.8)],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              '∑',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cohort['title'] as String,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${context.l10n.academicFocusLabel}${cohort['focus']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AppBadge(
                              label: cohort['target'] as String,
                              variant: AppBadgeVariant.active,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${context.l10n.averageScoreLabel}${cohort['score']}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s12),
                  const Divider(height: 1),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: [
                      ActionChip(
                        avatar: const Icon(
                          Icons.folder_shared_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          context.l10n.chipHandoutsPdfs,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.surfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        onPressed: () => context.push(AppRoutes.groupsList),
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.assignment_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        label: Text(
                          context.l10n.chipDrillHomework,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.surfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        onPressed: () => context.push(AppRoutes.groupsList),
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.quiz_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          context.l10n.chipExamsSimulations,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.surfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        onPressed: () => context.push(AppRoutes.groupsList),
                      ),
                      ActionChip(
                        avatar: const Icon(
                          Icons.fact_check_rounded,
                          size: 14,
                          color: AppColors.success,
                        ),
                        label: Text(
                          context.l10n.chipRecordAttendance,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.surfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                        side: const BorderSide(color: AppColors.border),
                        onPressed: () =>
                            context.push(AppRoutes.teacherAttendance),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
