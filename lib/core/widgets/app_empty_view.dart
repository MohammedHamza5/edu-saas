import 'package:flutter/material.dart';
import '../localization/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

class AppEmptyView extends StatelessWidget {
  final String? message;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData icon;

  const AppEmptyView({
    super.key,
    this.message,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayMessage = message ?? (l10n != null ? l10n.emptyData : 'No data');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.textMuted,
                size: 48,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
            if (onAction != null && actionText != null) ...[
              const SizedBox(height: AppSpacing.s20),
              AppButton(
                text: actionText!,
                onPressed: onAction,
                variant: AppButtonVariant.primary,
                width: 160,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
