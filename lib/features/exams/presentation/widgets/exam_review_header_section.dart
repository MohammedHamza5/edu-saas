import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';
import '../extensions/exam_ui_extensions.dart';

class ExamReviewHeaderSection extends StatelessWidget {
  final String title;
  final bool isPassed;
  final ExamSubmissionReason submissionReason;
  final String scoreText;
  final List<ExamQuestionEntity> questions;
  final List<ExamAnswerEntity> answers;
  final int currentIndex;
  final ValueChanged<int> onSelectQuestion;

  const ExamReviewHeaderSection({
    super.key,
    required this.title,
    required this.isPassed,
    required this.submissionReason,
    required this.scoreText,
    required this.questions,
    required this.answers,
    required this.currentIndex,
    required this.onSelectQuestion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (isPassed
                                    ? AppColors.success
                                    : AppColors.error)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isPassed
                                ? context.l10n.statusCompleted
                                : context.l10n.statusFailed,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isPassed
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: submissionReason.color
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                submissionReason.icon,
                                size: 11,
                                color: submissionReason.color,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                submissionReason.localizedLabel(context),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: submissionReason.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          scoreText,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),

          // ── Question Jump Pills ─────────────────────────────────────────
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: questions.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(width: AppSpacing.s8),
              itemBuilder: (ctx, idx) {
                final q = questions[idx];
                final qAns = answers
                    .cast<ExamAnswerEntity?>()
                    .firstWhere(
                      (a) => a?.questionId == q.id,
                      orElse: () => null,
                    );
                final isAnsCorrect = qAns?.isCorrect == true;
                final isCurrent = idx == currentIndex;

                final bg = isAnsCorrect
                    ? AppColors.success.withValues(alpha: 0.15)
                    : AppColors.error.withValues(alpha: 0.15);
                final borderCol = isCurrent
                    ? AppColors.primary
                    : (isAnsCorrect ? AppColors.success : AppColors.error);
                final textCol = isAnsCorrect
                    ? AppColors.success
                    : AppColors.error;

                return InkWell(
                  onTap: () => onSelectQuestion(idx),
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusSmall,
                  ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      border: Border.all(
                        color: borderCol,
                        width: isCurrent ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent
                              ? FontWeight.w900
                              : FontWeight.bold,
                          color: isCurrent ? AppColors.primary : textCol,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
