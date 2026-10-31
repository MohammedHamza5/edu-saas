import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Small academic disclaimer card at the bottom of the material viewer.
class MaterialViewerSecurityNotice extends StatelessWidget {
  final bool isTeacher;

  const MaterialViewerSecurityNotice({
    super.key,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(10),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.primary.withAlpha(25)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.shield_outlined,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.s6),
          Expanded(
            child: Text(
              isTeacher
                  ? context.l10n.contentSecurityDisclaimer
                  : context.l10n.contentSecurityDisclaimerStudent,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.primary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
