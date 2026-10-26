import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../domain/entities/assignment_entity.dart';
import 'assignment_card.dart';

/// Responsive grid displaying teacher assignments or a filtered empty state.
class TeacherAssignmentsGrid extends StatelessWidget {
  final List<AssignmentEntity> assignments;
  final bool isLoadingMore;
  final ValueChanged<AssignmentEntity> onAssignmentTap;
  final ValueChanged<AssignmentEntity> onAssignmentEdit;
  final VoidCallback onResetFilters;

  const TeacherAssignmentsGrid({
    super.key,
    required this.assignments,
    required this.isLoadingMore,
    required this.onAssignmentTap,
    required this.onAssignmentEdit,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: AppEmptyView(
            icon: Icons.search_off_rounded,
            message: context.l10n.noMatchingAssignmentsFound,
            actionText: context.l10n.clearSearchAction,
            onAction: onResetFilters,
          ),
        ),
      );
    }

    return Column(
      children: [
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 2,
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s16,
          children: assignments.map((assignment) {
            return AssignmentCard(
              assignment: assignment,
              isTeacher: true,
              onTap: () => onAssignmentTap(assignment),
              onEdit: () => onAssignmentEdit(assignment),
            );
          }).toList(),
        ),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
            child: Center(
              child: AppLoadingView.compact(size: 24),
            ),
          ),
      ],
    );
  }
}
