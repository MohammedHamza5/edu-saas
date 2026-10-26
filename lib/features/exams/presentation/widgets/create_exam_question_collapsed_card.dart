import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../models/create_exam_draft_models.dart';
import '../extensions/exam_ui_extensions.dart';

class CreateExamQuestionCollapsedCard extends StatelessWidget {
  final int qIndex;
  final CreateExamDraftQuestion q;
  final bool isCreating;
  final bool canDelete;
  final VoidCallback onToggleExpanded;
  final VoidCallback onRemove;

  const CreateExamQuestionCollapsedCard({
    super.key,
    required this.qIndex,
    required this.q,
    required this.isCreating,
    required this.canDelete,
    required this.onToggleExpanded,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ||
        (q.localImageBytes != null);
    final text = q.textController.text.trim();
    final displayText = text.isNotEmpty
        ? text
        : (hasImage
            ? context.l10n.hasAttachedImage
            : context.l10n.questionSummaryEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: InkWell(
        onTap: onToggleExpanded,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Text(
                      context.l10n.questionNumberTitle(qIndex + 1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '${q.points} ${context.l10n.pointsField}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Text(
                      q.type.localizedLabel(context),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: AppSpacing.s8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (q.isUploadingImage) ...[
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0EA5E9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ] else ...[
                            const Icon(
                              Icons.image_rounded,
                              size: 14,
                              color: Color(0xFF0EA5E9),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            context.l10n.hasAttachedImage,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (canDelete)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      tooltip: context.l10n.removeOption,
                      onPressed: isCreating ? null : onRemove,
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    tooltip: context.l10n.clickToEditQuestion,
                    onPressed: onToggleExpanded,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: text.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                  fontStyle: text.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
