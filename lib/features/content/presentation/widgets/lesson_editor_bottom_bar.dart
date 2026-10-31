import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';

/// Action buttons row (Cancel & Save) at the bottom of [LessonEditorPane].
class LessonEditorBottomBar extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const LessonEditorBottomBar({
    super.key,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 12,
            ),
          ),
          child: Text(l10n.cancel),
        ),
        const SizedBox(width: AppSpacing.s12),
        AppButton(
          text: l10n.save,
          icon: Icons.check_rounded,
          isLoading: isSaving,
          onPressed: onSave,
        ),
      ],
    );
  }
}
