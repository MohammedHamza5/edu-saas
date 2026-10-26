import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../groups/domain/entities/group_entity.dart';

class StudentGroupSwitcherBar extends StatelessWidget {
  final List<GroupEntity> groups;
  final String activeGroupId;
  final ValueChanged<GroupEntity> onGroupSelected;

  const StudentGroupSwitcherBar({
    super.key,
    required this.groups,
    required this.activeGroupId,
    required this.onGroupSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: groups.map((g) {
            final isSelected = g.id == activeGroupId;
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.s8),
              child: ChoiceChip(
                avatar: Icon(
                  Icons.school_rounded,
                  size: 16,
                  color: isSelected ? Colors.white : AppColors.primary,
                ),
                label: Text(g.name),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                onSelected: (selected) {
                  if (selected && activeGroupId != g.id) {
                    onGroupSelected(g);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
