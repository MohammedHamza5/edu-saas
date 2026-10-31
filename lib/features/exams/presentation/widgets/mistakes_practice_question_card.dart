import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/mistake_entities.dart';

class MistakesPracticeQuestionCard extends StatelessWidget {
  final MistakeQuestionEntity question;
  final List<MistakeOptionEntity> options;
  final String? selectedOptionId;
  final ValueChanged<String> onSelectOption;

  const MistakesPracticeQuestionCard({
    super.key,
    required this.question,
    required this.options,
    required this.selectedOptionId,
    required this.onSelectOption,
  });

  void _openImageDialog(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.s16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                memCacheWidth: 800,
                memCacheHeight: 800,
                maxWidthDiskCache: 1200,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => const SizedBox(
                  height: 250,
                  child: Center(
                    child: Icon(Icons.broken_image, color: Colors.white, size: 40),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Contextual Badge (Mastered vs Wrong answer vs Skipped question)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s12),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: (question.isResolved
                      ? AppColors.success
                      : question.isSkipped
                          ? AppColors.warning
                          : AppColors.error)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(
                AppSpacing.radiusSmall,
              ),
              border: Border.all(
                color: (question.isResolved
                        ? AppColors.success
                        : question.isSkipped
                            ? AppColors.warning
                            : AppColors.error)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  question.isResolved
                      ? Icons.check_circle_rounded
                      : question.isSkipped
                          ? Icons.pause_circle_outline_rounded
                          : Icons.cancel_outlined,
                  color: question.isResolved
                      ? AppColors.success
                      : question.isSkipped
                          ? AppColors.warning
                          : AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    question.isResolved
                        ? '${l10n.badgeMastered} - ${l10n.practiceModeResolvedDesc}'
                        : question.isSkipped
                            ? l10n.practiceHeaderSkippedNote
                            : l10n.practiceHeaderWrongNote,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: question.isResolved
                          ? AppColors.success
                          : question.isSkipped
                              ? AppColors.warning
                              : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Stem
          if (question.questionText.isNotEmpty) ...[
            Text(
              question.questionText,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
          ],

          // Image if present
          if (question.imageUrl != null &&
              question.imageUrl!.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _openImageDialog(
                context,
                question.imageUrl!,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusMedium,
                ),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.04),
                  child: CachedNetworkImage(
                    imageUrl: question.imageUrl!,
                    memCacheWidth: 800,
                    memCacheHeight: 800,
                    maxWidthDiskCache: 1200,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.s24),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(AppSpacing.s16),
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
          ],

          // Instruction
          Text(
            l10n.practiceExamInstruction,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // Options (with session-level shuffling)
          ...options.map((opt) {
            final isSelected = selectedOptionId == opt.id;
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(
                        alpha: 0.08,
                      )
                    : theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusMedium,
                ),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : Colors.grey.withValues(alpha: 0.25),
                  width: isSelected ? 1.8 : 1.0,
                ),
              ),
              child: InkWell(
                onTap: () => onSelectOption(opt.id),
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusMedium,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: Text(
                          opt.optionText,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : null,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
