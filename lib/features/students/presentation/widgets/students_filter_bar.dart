import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class StudentsFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String? selectedStatus;
  final ValueChanged<String> onSearch;
  final VoidCallback onClearSearch;
  final ValueChanged<String?> onFilterTap;

  const StudentsFilterBar({
    super.key,
    required this.searchController,
    required this.selectedStatus,
    required this.onSearch,
    required this.onClearSearch,
    required this.onFilterTap,
  });

  List<({String label, String? value})> _getStatusFilters(
    BuildContext context,
  ) => [
    (label: context.l10n.all, value: null),
    (label: context.l10n.active, value: 'active'),
    (label: context.l10n.pending, value: 'pending'),
    (label: context.l10n.rejected, value: 'rejected'),
    (label: context.l10n.suspended, value: 'suspended'),
  ];

  @override
  Widget build(BuildContext context) {
    final statusFilters = _getStatusFilters(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Search bar ───────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s16,
            AppSpacing.s12,
            AppSpacing.s16,
            0,
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearch,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: context.l10n.searchStudentsHint,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: onClearSearch,
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusMedium,
                ),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Status filter chips ──────────────────────────────────────────
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s8,
            ),
            itemCount: statusFilters.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: AppSpacing.s8),
            itemBuilder: (context, i) {
              final f = statusFilters[i];
              final selected = selectedStatus == f.value;
              return FilterChip(
                label: Text(f.label),
                selected: selected,
                selectedColor: AppColors.primaryLight.withValues(
                  alpha: 0.2,
                ),
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: selected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  fontWeight: selected
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 12,
                ),
                onSelected: (_) => onFilterTap(f.value),
              );
            },
          ),
        ),

        const Divider(height: 1),
      ],
    );
  }
}
