import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../groups/domain/entities/group_entity.dart';

/// Card widget rendering a live study group / cohort with quick navigation chips.
class TeacherGroupCohortCard extends StatelessWidget {
  final GroupEntity group;
  final Color color;

  const TeacherGroupCohortCard({
    super.key,
    required this.group,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
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
  }
}
