import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'settings_section_card.dart';

/// Section for configuring the Video Streaming Provider
/// (Bunny Stream active vs YouTube locked).
class StreamingProviderSettingsSection extends StatelessWidget {
  const StreamingProviderSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SettingsSectionCard(
      title: l10n.streamingProviderSettingTitle,
      icon: Icons.video_settings_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.streamingProviderSettingDesc,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;
              final bunnyCard = _buildProviderOptionCard(
                context,
                providerKey: 'bunny',
                providerName: l10n.providerBunnyLabel,
                subtitle: l10n.providerBunnyDesc,
                icon: Icons.cloud_done_rounded,
                iconColor: const Color(0xFFF97316),
                isSelected: true,
                isLocked: false,
                onTap: null,
              );
              final youtubeCard = _buildProviderOptionCard(
                context,
                providerKey: 'youtube',
                providerName: l10n.providerYoutubeLabel,
                subtitle: l10n.providerYoutubeDesc,
                icon: Icons.play_circle_fill_rounded,
                iconColor: const Color(0xFFFF0000),
                isSelected: false,
                isLocked: true,
                onTap: null,
              );

              if (isCompact) {
                return Column(
                  children: [
                    bunnyCard,
                    const SizedBox(height: AppSpacing.s12),
                    youtubeCard,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: bunnyCard),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(child: youtubeCard),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProviderOptionCard(
    BuildContext context, {
    required String providerKey,
    required String providerName,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    bool isLocked = false,
    VoidCallback? onTap,
  }) {
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLocked
            ? () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Text(
                            l10n.providerLockedNoticeToast,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    backgroundColor: AppColors.surfaceElevated,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.borderDark),
                    ),
                  ),
                );
              }
            : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: isLocked ? 0.60 : 1.0,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.borderDark
                        .withValues(alpha: isLocked ? 0.5 : 1.0),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isLocked ? 0.06 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color:
                        isLocked ? iconColor.withValues(alpha: 0.6) : iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              providerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isSelected
                                    ? AppColors.primary
                                    : (isLocked
                                        ? AppColors.textSecondary
                                        : AppColors.textPrimary),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                l10n.providerActiveStatusBadge,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          else if (isLocked)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.borderDark
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.lock_rounded,
                                    size: 10,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    l10n.providerLockedByAdminBadge,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isLocked
                              ? AppColors.textMuted
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 22,
                  )
                else
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
