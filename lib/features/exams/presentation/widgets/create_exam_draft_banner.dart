import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class CreateExamDraftBanner extends StatelessWidget {
  final Map<String, dynamic>? savedDraftData;
  final VoidCallback onDiscard;
  final VoidCallback onRestore;

  const CreateExamDraftBanner({
    super.key,
    required this.savedDraftData,
    required this.onDiscard,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    final rawQuestions = savedDraftData?['questions'] as List?;
    final count = rawQuestions?.length ?? 0;
    final savedAtStr = savedDraftData?['savedAt'] as String?;
    String timeAgo = '';
    if (savedAtStr != null) {
      final savedAt = DateTime.tryParse(savedAtStr);
      if (savedAt != null) {
        final diff = DateTime.now().difference(savedAt);
        if (diff.inMinutes < 1) {
          timeAgo = '< 1m';
        } else if (diff.inHours < 1) {
          timeAgo = '${diff.inMinutes}m';
        } else if (diff.inDays < 1) {
          timeAgo = '${diff.inHours}h';
        } else {
          timeAgo = '${diff.inDays}d';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: const Color(0xFF5B4FE0).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: const Color(0xFF5B4FE0).withValues(alpha: 0.3),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;
          final header = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B4FE0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.history_edu_rounded,
                  color: Color(0xFF5B4FE0),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  context.l10n.examDraftFoundNotice(count, timeAgo),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          );

          final actions = Row(
            mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment:
                isNarrow ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              OutlinedButton(
                onPressed: onDiscard,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                child: Text(
                  context.l10n.discardExamDraftAction,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilledButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: Text(
                  context.l10n.restoreExamDraftAction,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  backgroundColor: const Color(0xFF5B4FE0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: AppSpacing.s10),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: header),
              const SizedBox(width: AppSpacing.s12),
              actions,
            ],
          );
        },
      ),
    );
  }
}
