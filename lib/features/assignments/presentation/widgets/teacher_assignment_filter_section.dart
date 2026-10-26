import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';

/// Filter and search section for teacher assignments list.
/// Displays the search input bar, status filter chips with badges,
/// and quick filter clear actions.
class TeacherAssignmentFilterSection extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final String activeStatusFilter;
  final int totalCount;
  final int openCount;
  final int needsGradingCount;
  final int pastDueCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onStatusFilterChanged;
  final VoidCallback onResetAllFilters;

  const TeacherAssignmentFilterSection({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.activeStatusFilter,
    required this.totalCount,
    required this.openCount,
    required this.needsGradingCount,
    required this.pastDueCount,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onStatusFilterChanged,
    required this.onResetAllFilters,
  });

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty || activeStatusFilter != 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar
        AppTextField(
          controller: searchController,
          hintText: context.l10n.searchAssignmentsHint,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: context.l10n.clearSearchAction,
                  onPressed: onClearSearch,
                )
              : null,
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: AppSpacing.s8),

        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(context.l10n.filterAllAssignments(totalCount)),
                selected: activeStatusFilter == 'all',
                onSelected: (_) => onStatusFilterChanged('all'),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: activeStatusFilter == 'all'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: activeStatusFilter == 'all'
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: activeStatusFilter == 'all'
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilterChip(
                avatar: Icon(
                  Icons.assignment_turned_in_rounded,
                  size: 16,
                  color: activeStatusFilter == 'open'
                      ? Colors.white
                      : AppColors.success,
                ),
                label: Text('${context.l10n.active} ($openCount)'),
                selected: activeStatusFilter == 'open',
                onSelected: (_) => onStatusFilterChanged('open'),
                selectedColor: AppColors.success,
                backgroundColor: AppColors.surfaceVariant,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: activeStatusFilter == 'open'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: activeStatusFilter == 'open'
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: activeStatusFilter == 'open'
                        ? AppColors.success
                        : AppColors.border,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilterChip(
                avatar: Icon(
                  Icons.rate_review_rounded,
                  size: 16,
                  color: activeStatusFilter == 'needs_grading'
                      ? Colors.white
                      : AppColors.warning,
                ),
                label: Text(
                  '${context.l10n.filterNeedsGrading} ($needsGradingCount)',
                ),
                selected: activeStatusFilter == 'needs_grading',
                onSelected: (_) => onStatusFilterChanged('needs_grading'),
                selectedColor: AppColors.warning,
                backgroundColor: AppColors.surfaceVariant,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: activeStatusFilter == 'needs_grading'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: activeStatusFilter == 'needs_grading'
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: activeStatusFilter == 'needs_grading'
                        ? AppColors.warning
                        : AppColors.border,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilterChip(
                avatar: Icon(
                  Icons.alarm_off_rounded,
                  size: 16,
                  color: activeStatusFilter == 'past_due'
                      ? Colors.white
                      : AppColors.error,
                ),
                label: Text(
                  '${context.l10n.filterPastDue} ($pastDueCount)',
                ),
                selected: activeStatusFilter == 'past_due',
                onSelected: (_) => onStatusFilterChanged('past_due'),
                selectedColor: AppColors.error,
                backgroundColor: AppColors.surfaceVariant,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: activeStatusFilter == 'past_due'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: activeStatusFilter == 'past_due'
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: activeStatusFilter == 'past_due'
                        ? AppColors.error
                        : AppColors.border,
                  ),
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: AppSpacing.s8),
                ActionChip(
                  avatar: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.error,
                  ),
                  label: Text(
                    context.l10n.clearSearchAction,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: AppColors.error.withAlpha(20),
                  side: BorderSide(
                    color: AppColors.error.withAlpha(50),
                  ),
                  onPressed: onResetAllFilters,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
