import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../domain/entities/assignment_entity.dart';
import 'assignment_card.dart';

/// Virtualized Responsive Sliver Grid displaying teacher assignments or a filtered empty state.
/// Renders only cards currently in the viewport with isolated repaint boundaries.
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
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: AppEmptyView(
              icon: Icons.search_off_rounded,
              message: context.l10n.noMatchingAssignmentsFound,
              actionText: context.l10n.clearSearchAction,
              onAction: onResetFilters,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 460,
          crossAxisSpacing: AppSpacing.s16,
          mainAxisSpacing: AppSpacing.s16,
          mainAxisExtent: 260,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final assignment = assignments[index];
            return RepaintBoundary(
              key: ValueKey('assignment_${assignment.id}'),
              child: AssignmentCard(
                assignment: assignment,
                isTeacher: true,
                onTap: () => onAssignmentTap(assignment),
                onEdit: () => onAssignmentEdit(assignment),
              ),
            );
          },
          childCount: assignments.length,
        ),
      ),
    );
  }
}
