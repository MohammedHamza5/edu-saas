import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/exam_dispatch_cubit.dart';
import '../cubit/exam_dispatch_state.dart';

/// Search input and filter pills bar for exam parent dispatch hub.
class ExamDispatchFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ExamDispatchCubit cubit;
  final ExamDispatchLoaded state;

  const ExamDispatchFilterBar({
    super.key,
    required this.searchController,
    required this.cubit,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final stats = state.roster.stats;
    final total = stats.totalAssignedStudents;
    final submitted = stats.submittedCount;
    final passed = stats.passedCount;
    final failed = stats.failedCount;
    final notStarted = stats.notStartedCount + stats.inProgressCount;
    final unnotified = total - state.notifiedCount;
    final notified = state.notifiedCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input Field
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: context.l10n.searchStudentOrPhoneHint,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      searchController.clear();
                      cubit.setSearchQuery('');
                    },
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onChanged: cubit.setSearchQuery,
        ),
        const SizedBox(height: AppSpacing.s12),

        // Filter Pills Scroll
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                label: context.l10n.filterAllRoster(total),
                isSelected: state.activeFilter == ExamDispatchFilter.all,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.all),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterSubmittedRoster(submitted),
                isSelected: state.activeFilter == ExamDispatchFilter.submitted,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.submitted),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterPassedRoster(passed),
                isSelected: state.activeFilter == ExamDispatchFilter.passed,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.passed),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterNeedsAttentionRoster(failed),
                isSelected:
                    state.activeFilter == ExamDispatchFilter.needsAttention,
                onSelected: () =>
                    cubit.setFilter(ExamDispatchFilter.needsAttention),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterNotStartedRoster(notStarted),
                isSelected: state.activeFilter == ExamDispatchFilter.notStarted,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.notStarted),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterUnnotifiedRoster(unnotified),
                isSelected: state.activeFilter == ExamDispatchFilter.unnotified,
                onSelected: () =>
                    cubit.setFilter(ExamDispatchFilter.unnotified),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterNotifiedRoster(notified),
                isSelected: state.activeFilter == ExamDispatchFilter.notified,
                onSelected: () => cubit.setFilter(ExamDispatchFilter.notified),
              ),
              const SizedBox(width: 6),
              _buildFilterChip(
                label: context.l10n.filterMissingPhoneRoster,
                isSelected:
                    state.activeFilter == ExamDispatchFilter.missingPhone,
                onSelected: () =>
                    cubit.setFilter(ExamDispatchFilter.missingPhone),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.border,
        ),
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
