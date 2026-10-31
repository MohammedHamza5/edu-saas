import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../question_bank/presentation/widgets/question_display_widgets.dart';
import '../../domain/entities/exam_entity.dart';
import 'exam_image_viewer.dart';

class ExamReviewQuestionView extends StatelessWidget {
  final ExamQuestionEntity question;
  final ExamAnswerEntity? answer;
  final int currentIndex;
  final int totalQuestions;
  final bool isSavedInVault;
  final VoidCallback onToggleSaveVault;

  const ExamReviewQuestionView({
    super.key,
    required this.question,
    required this.answer,
    required this.currentIndex,
    required this.totalQuestions,
    required this.isSavedInVault,
    required this.onToggleSaveVault,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question Header Card
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      context.l10n.reviewQuestionIndex(
                        currentIndex + 1,
                        totalQuestions,
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (answer?.isCorrect == true
                                    ? AppColors.success
                                    : AppColors.error)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            context.l10n.pointsEarnedOutOf(
                              (answer?.pointsEarned ?? 0).toInt(),
                              question.points,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: answer?.isCorrect == true
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        IconButton(
                          icon: Icon(
                            isSavedInVault
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: isSavedInVault
                                ? AppColors.warning
                                : AppColors.textSecondary,
                            size: 20,
                          ),
                          tooltip: isSavedInVault
                              ? context.l10n.removeFromVault
                              : context.l10n.saveToMistakeVaultAction,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onToggleSaveVault,
                        ),
                      ],
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final hasExplicitImage = question.imageUrl != null &&
                        question.imageUrl!.trim().isNotEmpty;
                    final isTextAnImageUrl = QuestionStemView.isImageUrl(
                      question.questionText.trim(),
                    );
                    final effectiveImageUrl = hasExplicitImage
                        ? question.imageUrl!
                        : (isTextAnImageUrl
                              ? question.questionText.trim()
                              : null);
                    final shouldShowText =
                        question.questionText.trim().isNotEmpty &&
                        !isTextAnImageUrl;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (shouldShowText) ...[
                          const SizedBox(height: AppSpacing.s12),
                          Text(
                            question.questionText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                        if (effectiveImageUrl != null &&
                            effectiveImageUrl.isNotEmpty)
                          ExamImageViewer(
                            key: ValueKey(
                              'review_q_${question.id}_$effectiveImageUrl',
                            ),
                            imageUrl: effectiveImageUrl,
                            imageMeta: question.imageMeta,
                            caption: context.l10n.reviewQuestionIndex(
                              currentIndex + 1,
                              totalQuestions,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s16),

          if (answer == null || answer?.selectedOptionId == null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: AppSpacing.s12),
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusMedium,
                ),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      context.l10n.unansweredQuestion,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Options List ──────────────────────────────────────────
          ...question.options.asMap().entries.map((entry) {
            final optIndex = entry.key;
            final opt = entry.value;

            final isChosen = opt.id == answer?.selectedOptionId;
            final isModelCorrect = opt.isCorrect == true;

            Color borderCol = AppColors.border;
            Color bgCol = AppColors.surface;
            Widget? statusBadge;

            if (isChosen && isModelCorrect) {
              borderCol = AppColors.success;
              bgCol = AppColors.success.withValues(alpha: 0.08);
              statusBadge = _buildBadge(
                context.l10n.yourCorrectAnswer,
                Icons.check_circle_rounded,
                AppColors.success,
              );
            } else if (isChosen && !isModelCorrect) {
              borderCol = AppColors.error;
              bgCol = AppColors.error.withValues(alpha: 0.08);
              statusBadge = _buildBadge(
                context.l10n.yourWrongAnswer,
                Icons.cancel_rounded,
                AppColors.error,
              );
            } else if (isModelCorrect) {
              borderCol = AppColors.success;
              bgCol = AppColors.success.withValues(alpha: 0.05);
              statusBadge = _buildBadge(
                context.l10n.correctAnswerLabel,
                Icons.check_circle_outline_rounded,
                AppColors.success,
              );
            }

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.s10),
              padding: const EdgeInsets.all(AppSpacing.s14),
              decoration: BoxDecoration(
                color: bgCol,
                borderRadius: BorderRadius.circular(
                  AppSpacing.radiusMedium,
                ),
                border: Border.all(
                  color: borderCol,
                  width: (isChosen || isModelCorrect) ? 1.8 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: (isChosen || isModelCorrect)
                              ? borderCol
                              : AppColors.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _getOptionLetter(context, optIndex),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: (isChosen || isModelCorrect)
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          opt.optionText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: (isChosen || isModelCorrect)
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (opt.imageUrl != null && opt.imageUrl!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.s8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: opt.imageUrl!,
                        height: 120,
                        memCacheWidth: 400,
                        memCacheHeight: 250,
                        maxWidthDiskCache: 600,
                        fit: BoxFit.contain,
                        placeholder: (ctx, _) => Container(
                          height: 120,
                          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                          child: const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                  if (statusBadge != null) ...[
                    const SizedBox(height: AppSpacing.s8),
                    statusBadge,
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getOptionLetter(BuildContext context, int index) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final labels = isAr
        ? const ['أ', 'ب', 'ج', 'د', 'هـ', 'و']
        : const ['A', 'B', 'C', 'D', 'E', 'F'];
    if (index >= 0 && index < labels.length) {
      return labels[index];
    }
    return '${index + 1}';
  }
}
