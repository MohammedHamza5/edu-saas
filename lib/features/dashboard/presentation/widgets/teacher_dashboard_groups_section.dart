import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';
import '../../../groups/presentation/widgets/interactive_group_card.dart';

/// Section showing the teacher's active study groups with responsive grid and creation dialog trigger.
class TeacherDashboardGroupsSection extends StatelessWidget {
  final List<GroupEntity> groups;

  const TeacherDashboardGroupsSection({
    super.key,
    required this.groups,
  });

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s32),
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 450;
            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.layers_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          context.l10n.currentlyActiveStudyGroups,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(context.l10n.addGroup),
                      onPressed: () => CreateGroupDialog.show(context),
                    ),
                  ),
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.layers_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          context.l10n.currentlyActiveStudyGroups,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(context.l10n.addGroup),
                  onPressed: () => CreateGroupDialog.show(context),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.s12),
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 3,
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s16,
          children: groups
              .map(
                (group) => InteractiveGroupCard(
                  group: group,
                  onTap: () => context.push(
                    '${AppRoutes.groupsList}/${group.id}',
                    extra: group,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
