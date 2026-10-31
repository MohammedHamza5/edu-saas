import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';

/// Fullscreen modal overlay shown while batch saving staged lectures.
class LessonStudioProgressOverlay extends StatelessWidget {
  final bool isSaving;
  final String? savingProgressMessage;

  const LessonStudioProgressOverlay({
    super.key,
    required this.isSaving,
    this.savingProgressMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (!isSaving) return const SizedBox.shrink();

    final l10n = context.l10n;

    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: AppCard(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppLoadingView.signature(),
                const SizedBox(height: AppSpacing.s20),
                Text(
                  savingProgressMessage ?? l10n.savingChanges,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
