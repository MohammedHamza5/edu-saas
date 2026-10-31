import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../cubit/question_bank_state.dart';

class DocumentQuestionsHeader extends StatelessWidget {
  final DocumentEntity doc;
  final List<QuestionEntity> questions;
  final QuestionBankDocumentQuestionsLoaded state;
  final String selectedFilter;
  final VoidCallback onRefresh;
  final ValueChanged<String> onFilterChanged;
  final VoidCallback onDeployExam;

  const DocumentQuestionsHeader({
    super.key,
    required this.doc,
    required this.questions,
    required this.state,
    required this.selectedFilter,
    required this.onRefresh,
    required this.onFilterChanged,
    required this.onDeployExam,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy/MM/dd  HH:mm');

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s24,
        AppSpacing.s16,
        AppSpacing.s24,
        AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button + Document name + Action buttons (Responsive)
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 680;

              final titleWidget = Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.displayName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${doc.originalFilename}  •  ${dateFormat.format(doc.createdAt)}'
                          '${doc.pageCount != null ? '  •  ${l10n.pageCountBadge(doc.pageCount!)}' : ''}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final actionsWidget = Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (questions.isNotEmpty)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                          vertical: AppSpacing.s8,
                        ),
                      ),
                      icon: const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(l10n.createInstantExamAction),
                      onPressed: onDeployExam,
                    ),
                  IconButton.filledTonal(
                    tooltip: l10n.refreshTooltip,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    onPressed: onRefresh,
                  ),
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: AppSpacing.s12),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 48,
                      ),
                      child: actionsWidget,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleWidget),
                  const SizedBox(width: AppSpacing.s12),
                  actionsWidget,
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.s16),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  label: l10n.filterAll,
                  count: state.questions.length,
                  isSelected: selectedFilter == 'all',
                  onSelected: () => onFilterChanged('all'),
                ),
                const SizedBox(width: AppSpacing.s6),
                _buildFilterChip(
                  label: l10n.filterExtracted,
                  count: state.extractedCount,
                  isSelected: selectedFilter == 'extracted',
                  onSelected: () => onFilterChanged('extracted'),
                ),
                const SizedBox(width: AppSpacing.s6),
                _buildFilterChip(
                  label: l10n.filterReviewRequired,
                  count: state.reviewCount,
                  isSelected: selectedFilter == 'review_required',
                  activeColor: AppColors.warning,
                  onSelected: () => onFilterChanged('review_required'),
                ),
                const SizedBox(width: AppSpacing.s6),
                _buildFilterChip(
                  label: l10n.filterApproved,
                  count: state.approvedCount,
                  isSelected: selectedFilter == 'approved',
                  activeColor: AppColors.primary,
                  onSelected: () => onFilterChanged('approved'),
                ),
                const SizedBox(width: AppSpacing.s6),
                _buildFilterChip(
                  label: l10n.filterPublished,
                  count: state.publishedCount,
                  isSelected: selectedFilter == 'published',
                  activeColor: AppColors.success,
                  onSelected: () => onFilterChanged('published'),
                ),
                const SizedBox(width: AppSpacing.s6),
                _buildFilterChip(
                  label: l10n.statusQuarantined,
                  count: state.quarantinedCount,
                  isSelected: selectedFilter == 'quarantined',
                  activeColor: AppColors.error,
                  onSelected: () => onFilterChanged('quarantined'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? AppColors.primary;

    return FilterChip(
      selected: isSelected,
      selectedColor: effectiveColor.withValues(alpha: 0.15),
      checkmarkColor: effectiveColor,
      side: BorderSide(color: isSelected ? effectiveColor : AppColors.border),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? effectiveColor : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected
                  ? effectiveColor
                  : AppColors.surfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      onSelected: (_) => onSelected(),
    );
  }
}
