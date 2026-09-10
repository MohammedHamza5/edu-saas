import 'package:flutter/material.dart';
import '../localization/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'app_skeleton.dart';
import 'math_loading_indicator.dart';

enum AppLoadingStyle { spinner, skeletonCard, skeletonList, mathCurve }

class AppLoadingView extends StatelessWidget {
  final String? message;
  final AppLoadingStyle style;

  const AppLoadingView({
    super.key,
    this.message,
    this.style = AppLoadingStyle.spinner,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final displayMessage = message ?? (l10n != null ? l10n.loading : 'Loading...');

    return switch (style) {
      AppLoadingStyle.mathCurve => Center(
          child: MathLoadingIndicator(
            message: displayMessage,
            size: 110,
          ),
        ),
      AppLoadingStyle.spinner => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                displayMessage,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      AppLoadingStyle.skeletonCard => Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppSkeleton.rect(height: 24, width: 180),
              const SizedBox(height: AppSpacing.s12),
              const AppSkeleton.rect(height: 16, width: double.infinity),
              const SizedBox(height: AppSpacing.s8),
              AppSkeleton.rect(height: 16, width: MediaQuery.of(context).size.width * 0.6),
            ],
          ),
        ),
      AppLoadingStyle.skeletonList => ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.s16),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
          itemBuilder: (_, __) => Row(
            children: [
              const AppSkeleton.circle(size: 40),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSkeleton.rect(height: 16, width: 140),
                    const SizedBox(height: AppSpacing.s8),
                    AppSkeleton.rect(height: 12, width: MediaQuery.of(context).size.width * 0.4),
                  ],
                ),
              ),
            ],
          ),
        ),
    };
  }
}
