import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/mistake_entities.dart';
import '../utils/question_image_resolver.dart';
import 'exam_image_viewer.dart';
import 'mistake_reflection_selector.dart';
import 'question_audio_player.dart';

/// Card widget displaying a mistake question stem, media, previous wrong answer,
/// error reflection taxonomy selector, and individual practice CTA.
class StudentMistakeQuestionCard extends StatelessWidget {
  final MistakeQuestionEntity question;
  final int index;
  final void Function(String imageUrl)? onOpenImage;

  const StudentMistakeQuestionCard({
    super.key,
    required this.question,
    required this.index,
    this.onOpenImage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final q = question;
    final lastDate = q.lastFailedAt != null
        ? '${q.lastFailedAt!.year}-${q.lastFailedAt!.month.toString().padLeft(2, '0')}-${q.lastFailedAt!.day.toString().padLeft(2, '0')}'
        : '-';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: q.isResolved
              ? AppColors.success.withValues(alpha: 0.3)
              : q.isSkipped
              ? AppColors.warning.withValues(alpha: 0.35)
              : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Exam Title & Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.sourceExamTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (q.lessonTitle != null && q.lessonTitle!.isNotEmpty)
                      Text(
                        q.lessonTitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),

              // Distinctive Type Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: q.isSkipped
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: q.isSkipped
                        ? AppColors.warning.withValues(alpha: 0.35)
                        : AppColors.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      q.isSkipped
                          ? Icons.pause_circle_outline_rounded
                          : Icons.cancel_outlined,
                      size: 13,
                      color: q.isSkipped ? AppColors.warning : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      q.isSkipped
                          ? l10n.skippedQuestionBadge
                          : l10n.wrongAnswerBadge,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: q.isSkipped
                            ? AppColors.warning
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s6),

              // Status Badge (Mastered vs Needs Review)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: q.isResolved
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      q.isResolved
                          ? Icons.check_circle_rounded
                          : Icons.pending_actions_rounded,
                      size: 13,
                      color: q.isResolved
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      q.isResolved
                          ? l10n.badgeMastered
                          : l10n.badgeNeedsPractice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: q.isResolved
                            ? AppColors.success
                            : AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),

          // Metadata row: failure count, last attempt date
          Row(
            children: [
              Text(
                l10n.timesFailedLabel(q.failureCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Text(
                l10n.lastMistakeDate(lastDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),

          // Detailed Context Notice Banner
          if (q.isSkipped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.questionWasSkippedNotice,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.cancel_outlined,
                    size: 15,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      q.selectedOptionText != null &&
                              q.selectedOptionText!.isNotEmpty
                          ? l10n.previousWrongChoice(q.selectedOptionText!)
                          : l10n.wrongAnswerBadge,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: AppSpacing.s16),

          // Resolve Image & Question Stem
          Builder(
            builder: (context) {
              final effectiveImageUrl =
                  QuestionImageResolver.resolveEffectiveImageUrl(
                imageUrl: q.imageUrl,
                questionText: q.questionText,
              );
              final shouldShowText =
                  QuestionImageResolver.shouldShowQuestionText(
                q.questionText,
                effectiveImageUrl,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (shouldShowText) ...[
                    Text(
                      q.questionText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                  ],
                  if (effectiveImageUrl != null &&
                      effectiveImageUrl.isNotEmpty) ...[
                    ExamImageViewer(
                      key: ValueKey(
                        'mistake_card_${q.questionId}_$effectiveImageUrl',
                      ),
                      imageUrl: effectiveImageUrl,
                      imageMeta: q.imageMeta,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                  ],
                ],
              );
            },
          ),

          // Question Audio Explanation (if any)
          if (q.audioUrl != null && q.audioUrl!.trim().isNotEmpty) ...[
            QuestionAudioPlayer(
              key: ValueKey('mistake_audio_${q.questionId}'),
              audioUrl: q.audioUrl,
              initialDurationSeconds: q.audioDurationSeconds,
            ),
            const SizedBox(height: AppSpacing.s8),
          ],

          // Options List with subtle previous selection indicator
          ...q.options.map((opt) {
            final wasChosen = opt.id == q.lastSelectedOptionId;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: wasChosen
                      ? AppColors.error.withValues(alpha: 0.05)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: wasChosen
                      ? Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      wasChosen
                          ? Icons.cancel_rounded
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: wasChosen ? AppColors.error : Colors.grey,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Expanded(
                      child: Text(
                        opt.optionText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: wasChosen
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: wasChosen ? AppColors.error : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.s12),

          // Error Reflection Taxonomy (Concept Gap / Careless / Misread / Time)
          MistakeReflectionSelector(question: q),

          const SizedBox(height: AppSpacing.s12),

          // Individual Question Practice Button
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: () {
                final modeParam = q.isResolved ? 'resolved' : 'unresolved';
                context.push(
                  '${AppRoutes.mistakesPractice}?examId=${q.sourceExamId}&mode=$modeParam',
                );
              },
              icon: Icon(
                q.isResolved
                    ? Icons.restart_alt_rounded
                    : Icons.fitness_center_rounded,
                size: 16,
              ),
              label: Text(
                q.isResolved
                    ? l10n.practiceSingleQuestionAction
                    : l10n.practiceThisQuestion,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: q.isResolved
                    ? AppColors.success
                    : theme.colorScheme.primary,
                side: BorderSide(
                  color:
                      (q.isResolved
                              ? AppColors.success
                              : theme.colorScheme.primary)
                          .withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
