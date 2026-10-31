import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/mistake_entities.dart';
import '../cubit/mistakes_cubit.dart';
import '../cubit/mistakes_state.dart';

class StudentMistakesFilterBar extends StatelessWidget {
  final MistakesLoaded state;
  final TextEditingController searchController;

  const StudentMistakesFilterBar({
    super.key,
    required this.state,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<MistakesCubit>();
    final summary = state.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Prominent Status Segment Tabs (Needs Practice / Mastered / All)
        Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatusTab(
                  context,
                  title: l10n.mistakeTabUnresolved,
                  count: state.unresolvedCountInList,
                  isSelected:
                      state.statusFilter == MistakeStatusFilter.unresolved,
                  color: AppColors.warning,
                  onTap: () =>
                      cubit.setStatusFilter(MistakeStatusFilter.unresolved),
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: _buildStatusTab(
                  context,
                  title: l10n.mistakeTabResolved,
                  count: state.resolvedCountInList,
                  isSelected:
                      state.statusFilter == MistakeStatusFilter.resolved,
                  color: AppColors.success,
                  onTap: () =>
                      cubit.setStatusFilter(MistakeStatusFilter.resolved),
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: _buildStatusTab(
                  context,
                  title: l10n.mistakeTabAll,
                  count: state.totalCountInList,
                  isSelected: state.statusFilter == MistakeStatusFilter.all,
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => cubit.setStatusFilter(MistakeStatusFilter.all),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),

        // 2. Search Box
        TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: l10n.searchMistakesPlaceholder,
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
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2),
              ),
            ),
          ),
          onChanged: (val) {
            cubit.setSearchQuery(val);
          },
        ),
        const SizedBox(height: AppSpacing.s12),

        // 3. Type Filter Chips
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            // Mistake Type: All
            FilterChip(
              label: Text('${l10n.filterAllTypes} (${state.questions.length})'),
              selected: state.typeFilter == MistakeTypeFilter.all,
              onSelected: (_) => cubit.setTypeFilter(MistakeTypeFilter.all),
            ),
            // Mistake Type: Wrong Answers Only
            FilterChip(
              avatar: const Icon(
                Icons.cancel_outlined,
                size: 16,
                color: AppColors.error,
              ),
              label: Text(
                '${l10n.filterWrongAnswersOnly} (${state.wrongCountInList})',
              ),
              selected: state.typeFilter == MistakeTypeFilter.wrongOnly,
              selectedColor: AppColors.error.withValues(alpha: 0.15),
              onSelected: (_) =>
                  cubit.setTypeFilter(MistakeTypeFilter.wrongOnly),
            ),
            // Mistake Type: Skipped Questions Only
            FilterChip(
              avatar: const Icon(
                Icons.pause_circle_outline_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              label: Text(
                '${l10n.filterSkippedOnly} (${state.skippedCountInList})',
              ),
              selected: state.typeFilter == MistakeTypeFilter.skippedOnly,
              selectedColor: AppColors.warning.withValues(alpha: 0.15),
              onSelected: (_) =>
                  cubit.setTypeFilter(MistakeTypeFilter.skippedOnly),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),

        // Reflection Reason Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(l10n.filterAllTypes),
                selected: state.reasonFilter == MistakeReasonFilter.all,
                onSelected: (_) =>
                    cubit.setReasonFilter(MistakeReasonFilter.all),
              ),
              const SizedBox(width: AppSpacing.s6),
              FilterChip(
                avatar: const Icon(
                  Icons.psychology_outlined,
                  size: 15,
                  color: Color(0xFF7C3AED),
                ),
                label: Text(l10n.reflectionConceptGap),
                selected:
                    state.reasonFilter == MistakeReasonFilter.conceptGap,
                selectedColor:
                    const Color(0xFF7C3AED).withValues(alpha: 0.15),
                onSelected: (_) =>
                    cubit.setReasonFilter(MistakeReasonFilter.conceptGap),
              ),
              const SizedBox(width: AppSpacing.s6),
              FilterChip(
                avatar: const Icon(
                  Icons.bolt_outlined,
                  size: 15,
                  color: AppColors.error,
                ),
                label: Text(l10n.reflectionCarelessError),
                selected:
                    state.reasonFilter == MistakeReasonFilter.carelessError,
                selectedColor: AppColors.error.withValues(alpha: 0.15),
                onSelected: (_) =>
                    cubit.setReasonFilter(MistakeReasonFilter.carelessError),
              ),
              const SizedBox(width: AppSpacing.s6),
              FilterChip(
                avatar: const Icon(
                  Icons.menu_book_outlined,
                  size: 15,
                  color: Color(0xFF0284C7),
                ),
                label: Text(l10n.reflectionMisreadQuestion),
                selected:
                    state.reasonFilter == MistakeReasonFilter.misreadQuestion,
                selectedColor:
                    const Color(0xFF0284C7).withValues(alpha: 0.15),
                onSelected: (_) => cubit
                    .setReasonFilter(MistakeReasonFilter.misreadQuestion),
              ),
              const SizedBox(width: AppSpacing.s6),
              FilterChip(
                avatar: const Icon(
                  Icons.hourglass_top_outlined,
                  size: 15,
                  color: AppColors.warning,
                ),
                label: Text(l10n.reflectionTimePressure),
                selected:
                    state.reasonFilter == MistakeReasonFilter.timePressure,
                selectedColor: AppColors.warning.withValues(alpha: 0.15),
                onSelected: (_) =>
                    cubit.setReasonFilter(MistakeReasonFilter.timePressure),
              ),
            ],
          ),
        ),

        // 4. Exam Sources Dropdown (if multiple sources exist)
        if (summary.sources.length > 1) ...[
          const SizedBox(height: AppSpacing.s12),
          DropdownButtonFormField<String?>(
            initialValue: state.selectedExamId,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
            ),
            hint: Text(l10n.filterBySourceExam),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.allExamsFilter),
              ),
              ...summary.sources.map(
                (MistakeSourceEntity src) => DropdownMenuItem<String?>(
                  value: src.examId,
                  child: Text(
                    '${src.examTitle} (${src.unresolvedCount})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (val) => cubit.filterByExam(val),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusTab(
    BuildContext context, {
    required String title,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s8,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            border: isSelected
                ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
