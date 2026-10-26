import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';
import 'student_exams_overview_hub.dart';

/// Search and filter chips bar for the Student Exams Page.
class StudentExamsFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final void Function(String query) onSearchChanged;
  final VoidCallback onClearSearch;
  final List<ExamEntity> folderScopedExams;
  final StudentExamFilter activeFilter;
  final void Function(StudentExamFilter filter) onFilterChanged;

  const StudentExamsFilterBar({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.folderScopedExams,
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final availableCount = folderScopedExams
        .where(
            (e) => !e.hasAttempted || (!e.isFullyCompleted && !e.hasActiveAttempt))
        .length;
    final inProgressCount =
        folderScopedExams.where((e) => e.hasActiveAttempt).length;
    final completedCount =
        folderScopedExams.where((e) => e.isFullyCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: context.l10n.examSearchPlaceholder,
              hintStyle:
                  const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      tooltip: context.l10n.clearSearchTooltip,
                      onPressed: onClearSearch,
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s10,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.s6),

        // Filter chips row
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s6,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: context.l10n.filterAll,
                  filter: StudentExamFilter.all,
                  count: folderScopedExams.length,
                ),
                const SizedBox(width: AppSpacing.s8),
                _buildFilterChip(
                  label: context.l10n.filterNotStarted,
                  filter: StudentExamFilter.available,
                  count: availableCount,
                ),
                const SizedBox(width: AppSpacing.s8),
                _buildFilterChip(
                  label: context.l10n.attemptStatusInProgress,
                  filter: StudentExamFilter.inProgress,
                  count: inProgressCount,
                ),
                const SizedBox(width: AppSpacing.s8),
                _buildFilterChip(
                  label: context.l10n.filterCompleted,
                  filter: StudentExamFilter.completed,
                  count: completedCount,
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required StudentExamFilter filter,
    required int count,
  }) {
    final isSelected = activeFilter == filter;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppColors.primary.withAlpha(25),
      backgroundColor: Colors.transparent,
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
      onSelected: (_) => onFilterChanged(filter),
    );
  }
}
