import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';

/// Toolbar combining view-mode switcher, search input, and content type filter chips
class StudentContentToolbar extends StatelessWidget {
  final bool isRoadmapMode;
  final ValueChanged<bool> onToggleViewMode;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final List<LessonAssignmentEntity> allPublished;
  final ContentType? selectedTypeFilter;
  final ValueChanged<ContentType?> onSelectTypeFilter;

  const StudentContentToolbar({
    super.key,
    required this.isRoadmapMode,
    required this.onToggleViewMode,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.allPublished,
    required this.selectedTypeFilter,
    required this.onSelectTypeFilter,
  });

  Widget _buildViewModeButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withAlpha(35),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. View Switcher (Roadmap vs Syllabus List)
        if (allPublished.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.s4,
              bottom: AppSpacing.s8,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildViewModeButton(
                          icon: Icons.alt_route_rounded,
                          label: l10n.syllabusViewRoadmap,
                          isActive: isRoadmapMode,
                          onTap: () => onToggleViewMode(true),
                        ),
                        _buildViewModeButton(
                          icon: Icons.format_list_numbered_rounded,
                          label: l10n.syllabusViewList,
                          isActive: !isRoadmapMode,
                          onTap: () => onToggleViewMode(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 2. Search Bar
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.s4,
            bottom: AppSpacing.s16,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: AppTextField(
              controller: searchController,
              hintText: l10n.searchContentPlaceholder,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryLight,
                size: 20,
              ),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      onPressed: onClearSearch,
                    )
                  : null,
              onChanged: onSearchChanged,
            ),
          ),
        ),

        // 3. Type Filter Chips Row (Only displayed if multiple media types exist)
        if (allPublished.any((i) => i.type == ContentType.pdf) ||
            allPublished.any((i) => i.type == ContentType.image))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    label: l10n.filterAllWithCount(allPublished.length),
                    isSelected: selectedTypeFilter == null,
                    onSelected: () => onSelectTypeFilter(null),
                  ),
                  if (allPublished.any((i) => i.type == ContentType.pdf)) ...[
                    const SizedBox(width: AppSpacing.s8),
                    _buildFilterChip(
                      label: l10n.filterPdfsWithCount(
                        allPublished
                            .where((i) => i.type == ContentType.pdf)
                            .length,
                      ),
                      isSelected: selectedTypeFilter == ContentType.pdf,
                      onSelected: () => onSelectTypeFilter(ContentType.pdf),
                    ),
                  ],
                  if (allPublished.any((i) => i.type == ContentType.image)) ...[
                    const SizedBox(width: AppSpacing.s8),
                    _buildFilterChip(
                      label: l10n.filterImagesWithCount(
                        allPublished
                            .where((i) => i.type == ContentType.image)
                            .length,
                      ),
                      isSelected: selectedTypeFilter == ContentType.image,
                      onSelected: () => onSelectTypeFilter(ContentType.image),
                    ),
                  ],
                  if (allPublished.any((i) => i.type == ContentType.video)) ...[
                    const SizedBox(width: AppSpacing.s8),
                    _buildFilterChip(
                      label: l10n.filterVideosWithCount(
                        allPublished
                            .where((i) => i.type == ContentType.video)
                            .length,
                      ),
                      isSelected: selectedTypeFilter == ContentType.video,
                      onSelected: () => onSelectTypeFilter(ContentType.video),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}
