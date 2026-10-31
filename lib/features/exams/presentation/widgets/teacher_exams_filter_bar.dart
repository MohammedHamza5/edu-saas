import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';

class TeacherExamsFilterBar extends StatelessWidget {
  final int totalCount;
  final int generalCount;
  final int lectureCount;
  final int linkedLectureCount;
  final int unlinkedLectureCount;
  final int publishedCount;
  final int draftCount;
  final String activeTypeFilter;
  final String activeLectureSubFilter;
  final String activeStatusFilter;
  final String searchQuery;
  final bool hasActiveFilters;
  final TextEditingController searchController;
  final ValueChanged<String> onTypeFilterChanged;
  final ValueChanged<String> onLectureSubFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onResetAllFilters;

  const TeacherExamsFilterBar({
    super.key,
    required this.totalCount,
    required this.generalCount,
    required this.lectureCount,
    required this.linkedLectureCount,
    required this.unlinkedLectureCount,
    required this.publishedCount,
    required this.draftCount,
    required this.activeTypeFilter,
    required this.activeLectureSubFilter,
    required this.activeStatusFilter,
    required this.searchQuery,
    required this.hasActiveFilters,
    required this.searchController,
    required this.onTypeFilterChanged,
    required this.onLectureSubFilterChanged,
    required this.onStatusFilterChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onResetAllFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTypeFilterTabs(context),
        if (activeTypeFilter == 'lecture') ...[
          const SizedBox(height: AppSpacing.s12),
          _buildLectureSubFilters(context),
        ],
        const SizedBox(height: AppSpacing.s12),
        _buildSearchAndStatusFilters(context),
      ],
    );
  }

  Widget _buildTypeFilterTabs(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTypePill(
              title: context.l10n.examFilterTabAll(totalCount),
              isSelected: activeTypeFilter == 'all',
              accentColor: AppColors.primary,
              icon: Icons.all_inclusive_rounded,
              onTap: () => onTypeFilterChanged('all'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTypePill(
              title: context.l10n.examFilterTabGeneral(generalCount),
              isSelected: activeTypeFilter == 'general',
              accentColor: const Color(0xFF7C3AED),
              icon: Icons.assignment_rounded,
              onTap: () => onTypeFilterChanged('general'),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTypePill(
              title: context.l10n.examFilterTabLectureQuizzes(lectureCount),
              isSelected: activeTypeFilter == 'lecture',
              accentColor: const Color(0xFF0284C7),
              icon: Icons.ondemand_video_rounded,
              onTap: () => onTypeFilterChanged('lecture'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill({
    required String title,
    required bool isSelected,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.border.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? accentColor : AppColors.textMuted,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? accentColor : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLectureSubFilters(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.l10n.examFilterSubAll),
            selected: activeLectureSubFilter == 'all',
            onSelected: (_) => onLectureSubFilterChanged('all'),
            selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.2),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: activeLectureSubFilter == 'all'
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: activeLectureSubFilter == 'all'
                  ? const Color(0xFF0284C7)
                  : AppColors.textPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: activeLectureSubFilter == 'all'
                    ? const Color(0xFF0284C7)
                    : AppColors.border,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          ChoiceChip(
            avatar: const Icon(
              Icons.link_rounded,
              size: 14,
              color: AppColors.success,
            ),
            label: Text(context.l10n.examFilterSubLinked(linkedLectureCount)),
            selected: activeLectureSubFilter == 'linked',
            onSelected: (_) => onLectureSubFilterChanged('linked'),
            selectedColor: AppColors.success.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: activeLectureSubFilter == 'linked'
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: activeLectureSubFilter == 'linked'
                  ? AppColors.success
                  : AppColors.textPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: activeLectureSubFilter == 'linked'
                    ? AppColors.success
                    : AppColors.border,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          ChoiceChip(
            avatar: const Icon(
              Icons.link_off_rounded,
              size: 14,
              color: AppColors.warning,
            ),
            label: Text(
              context.l10n.examFilterSubUnlinked(unlinkedLectureCount),
            ),
            selected: activeLectureSubFilter == 'unlinked',
            onSelected: (_) => onLectureSubFilterChanged('unlinked'),
            selectedColor: AppColors.warning.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: activeLectureSubFilter == 'unlinked'
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: activeLectureSubFilter == 'unlinked'
                  ? AppColors.warning
                  : AppColors.textPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: activeLectureSubFilter == 'unlinked'
                    ? AppColors.warning
                    : AppColors.border,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndStatusFilters(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: searchController,
          hintText: context.l10n.searchExamsHint,
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
        const SizedBox(height: AppSpacing.s10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: Text(context.l10n.filterAllExams(totalCount)),
                selected: activeStatusFilter == 'all',
                onSelected: (_) => onStatusFilterChanged('all'),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: activeStatusFilter == 'all'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: activeStatusFilter == 'all'
                      ? AppColors.primary
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
              ChoiceChip(
                avatar: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 14,
                  color: AppColors.success,
                ),
                label: Text(context.l10n.filterPublishedExams(publishedCount)),
                selected: activeStatusFilter == 'published',
                onSelected: (_) => onStatusFilterChanged('published'),
                selectedColor: AppColors.success.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: activeStatusFilter == 'published'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: activeStatusFilter == 'published'
                      ? AppColors.success
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: activeStatusFilter == 'published'
                        ? AppColors.success
                        : AppColors.border,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              ChoiceChip(
                avatar: const Icon(
                  Icons.edit_note_rounded,
                  size: 15,
                  color: AppColors.warning,
                ),
                label: Text(context.l10n.filterDraftExams(draftCount)),
                selected: activeStatusFilter == 'draft',
                onSelected: (_) => onStatusFilterChanged('draft'),
                selectedColor: AppColors.warning.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: activeStatusFilter == 'draft'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: activeStatusFilter == 'draft'
                      ? AppColors.warning
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: activeStatusFilter == 'draft'
                        ? AppColors.warning
                        : AppColors.border,
                  ),
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: AppSpacing.s8),
                TextButton.icon(
                  onPressed: onResetAllFilters,
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(
                    context.l10n.clearSearchAction,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
