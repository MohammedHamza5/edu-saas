import 'package:flutter/material.dart';
import '../localization/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';

class AppErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const AppErrorView({
    super.key,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayMessage = message ?? (l10n != null ? l10n.errorOccurred : 'An error occurred');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2), // Red 100
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 40,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              displayMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s20),
              AppButton(
                text: l10n != null ? l10n.retry : 'Retry',
                onPressed: onRetry,
                variant: AppButtonVariant.outlined,
                icon: Icons.refresh_rounded,
                width: 160,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
