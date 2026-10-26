import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class BulkFillOptionsSheet extends StatelessWidget {
  final void Function(String pattern, {required bool onlyEmpty}) onSelectPattern;

  const BulkFillOptionsSheet({
    super.key,
    required this.onSelectPattern,
  });

  static Future<void> show(
    BuildContext context, {
    required void Function(String pattern, {required bool onlyEmpty}) onSelectPattern,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (ctx) => BulkFillOptionsSheet(
        onSelectPattern: onSelectPattern,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.auto_fix_high_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.bulkFillOptionsTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.bulkFillOptionsSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.format_list_bulleted_rounded,
                color: AppColors.primary,
              ),
              title: Text(context.l10n.fillAllQuestionsAbcd),
              subtitle: const Text('A, B, C, D'),
              onTap: () {
                Navigator.pop(context);
                onSelectPattern('abcd', onlyEmpty: false);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.check_box_outline_blank_rounded,
                color: Color(0xFF0EA5E9),
              ),
              title: Text(context.l10n.fillEmptyQuestionsAbcd),
              subtitle: const Text('A, B, C, D'),
              onTap: () {
                Navigator.pop(context);
                onSelectPattern('abcd', onlyEmpty: true);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.sync_alt_rounded,
                color: Color(0xFF8B5CF6),
              ),
              title: Text(context.l10n.fillActAlternatingPattern),
              subtitle: const Text('Q1: A,B,C,D  •  Q2: F,G,H,J ...'),
              onTap: () {
                Navigator.pop(context);
                onSelectPattern('act', onlyEmpty: false);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.translate_rounded,
                color: Color(0xFF10B981),
              ),
              title: Text(context.l10n.fillArabicLettersPattern),
              subtitle: const Text('أ ، ب ، ج ، د'),
              onTap: () {
                Navigator.pop(context);
                onSelectPattern('ar', onlyEmpty: false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
