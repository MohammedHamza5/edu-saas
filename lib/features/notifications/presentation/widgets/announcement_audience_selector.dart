import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';

/// Target audience selector dropdown and scope indicator for announcements.
class AnnouncementAudienceSelector extends StatelessWidget {
  final String? selectedGroupId;
  final ValueChanged<String?> onGroupChanged;

  const AnnouncementAudienceSelector({
    super.key,
    required this.selectedGroupId,
    required this.onGroupChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<GroupsCubit, GroupsState>(
      builder: (context, groupsState) {
        final List<GroupEntity> groups = groupsState is GroupsLoaded
            ? groupsState.groups
            : <GroupEntity>[];

        GroupEntity? selectedGroup;
        if (selectedGroupId != null && groups.isNotEmpty) {
          try {
            selectedGroup = groups.firstWhere(
              (g) => g.id == selectedGroupId,
            );
          } catch (_) {}
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String?>(
              initialValue: selectedGroupId,
              decoration: InputDecoration(
                labelText: l10n.targetAudienceLabel,
                prefixIcon: const Icon(
                  Icons.group_rounded,
                  color: AppColors.primary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusMedium,
                  ),
                ),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(
                    l10n.allPlatformStudents,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                ...groups.map((g) {
                  return DropdownMenuItem<String?>(
                    value: g.id,
                    child: Text('${g.name} (${g.level})'),
                  );
                }),
              ],
              onChanged: onGroupChanged,
            ),
            const SizedBox(height: AppSpacing.s8),
            // Audience indicator pill
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10,
                vertical: AppSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusSmall,
                ),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selectedGroupId == null
                        ? Icons.public_rounded
                        : Icons.groups_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  Text(
                    selectedGroupId == null
                        ? l10n.audienceScopeGeneral
                        : l10n.audienceScopeGroup(
                            selectedGroup?.name ?? '',
                            selectedGroup?.membersCount ?? 0,
                          ),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
