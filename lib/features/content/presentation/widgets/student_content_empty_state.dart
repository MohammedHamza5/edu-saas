import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';

/// Empty state widget for the student course feed (handles empty course vs empty search).
class StudentContentEmptyState extends StatelessWidget {
  final bool isSearchEmpty;
  final String searchQuery;

  const StudentContentEmptyState({
    super.key,
    required this.isSearchEmpty,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSearchEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: AppEmptyView(
            message: context.l10n.courseBeingPreparedTitle,
            subtitle: context.l10n.courseBeingPreparedSubtitle,
            icon: Icons.school_outlined,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: AppSpacing.s12),
            Text(
              context.l10n.noMatchingContentFound(searchQuery),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
