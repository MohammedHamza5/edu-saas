import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/materials_library_cubit.dart';
import '../cubit/materials_library_state.dart';

/// Responsive search field and file type filter chips for Materials Library.
class TeacherMaterialsFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  const TeacherMaterialsFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isFilterNarrow = constraints.maxWidth < 540;

        final filterChips = BlocBuilder<MaterialsLibraryCubit, MaterialsLibraryState>(
          buildWhen: (prev, curr) => prev.mimeTypeFilter != curr.mimeTypeFilter,
          builder: (context, state) {
            return Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l10n.allMaterialsFilter),
                  selected: state.mimeTypeFilter == null,
                  onSelected: (_) =>
                      context.read<MaterialsLibraryCubit>().setFilter(null),
                ),
                ChoiceChip(
                  label: Text(l10n.pdfFilesFilter),
                  selected: state.mimeTypeFilter == 'pdf',
                  onSelected: (_) =>
                      context.read<MaterialsLibraryCubit>().setFilter('pdf'),
                ),
              ],
            );
          },
        );

        final searchField = TextField(
          controller: searchController,
          onChanged: onSearchChanged,
          decoration: InputDecoration(
            hintText: l10n.materialsSearchHint,
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 22,
            ),
            suffixIcon: searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: onClearSearch,
                  )
                : null,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        );

        if (isFilterNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: AppSpacing.s10),
              filterChips,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: AppSpacing.s12),
            filterChips,
          ],
        );
      },
    );
  }
}
