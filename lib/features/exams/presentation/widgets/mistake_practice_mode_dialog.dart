import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class MistakePracticeModeDialog extends StatelessWidget {
  final int unresolvedCount;
  final int resolvedCount;
  final int totalCount;
  final ValueChanged<String> onSelectMode;

  const MistakePracticeModeDialog({
    super.key,
    required this.unresolvedCount,
    required this.resolvedCount,
    required this.totalCount,
    required this.onSelectMode,
  });

  static Future<void> show({
    required BuildContext context,
    required int unresolvedCount,
    required int resolvedCount,
    required int totalCount,
    required ValueChanged<String> onSelectMode,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => MistakePracticeModeDialog(
        unresolvedCount: unresolvedCount,
        resolvedCount: resolvedCount,
        totalCount: totalCount,
        onSelectMode: (mode) {
          Navigator.of(ctx).pop();
          onSelectMode(mode);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      backgroundColor: theme.colorScheme.surface,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.practiceModeDialogTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.practiceModeDialogSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),

              // Mode 1: Active Mistakes (Unresolved)
              _buildModeCard(
                context,
                title: l10n.practiceModeUnresolvedTitle,
                description: l10n.practiceModeUnresolvedDesc,
                badgeText: l10n.practiceModeBadgeQuestions(unresolvedCount),
                icon: Icons.pending_actions_rounded,
                color: AppColors.warning,
                isEnabled: unresolvedCount > 0,
                onTap: () => onSelectMode('unresolved'),
              ),
              const SizedBox(height: AppSpacing.s12),

              // Mode 2: Mastered Questions (Retention Review)
              _buildModeCard(
                context,
                title: l10n.practiceModeResolvedTitle,
                description: l10n.practiceModeResolvedDesc,
                badgeText: l10n.practiceModeBadgeMastered(resolvedCount),
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                isEnabled: resolvedCount > 0,
                onTap: () => onSelectMode('resolved'),
              ),
              const SizedBox(height: AppSpacing.s12),

              // Mode 3: Mixed Challenge
              _buildModeCard(
                context,
                title: l10n.practiceModeAllTitle,
                description: l10n.practiceModeAllDesc,
                badgeText: l10n.practiceModeBadgeQuestions(totalCount),
                icon: Icons.shuffle_rounded,
                color: theme.colorScheme.primary,
                isEnabled: totalCount > 0,
                onTap: () => onSelectMode('all'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard(
    BuildContext context, {
    required String title,
    required String description,
    required String badgeText,
    required IconData icon,
    required Color color,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: isEnabled ? 1.0 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: isEnabled
                  ? color.withValues(alpha: 0.05)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: isEnabled
                    ? color.withValues(alpha: 0.25)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isEnabled ? color : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
