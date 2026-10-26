import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_card.dart';
import 'package:edu_saas/features/exams/domain/entities/saved_question_entity.dart';

class SavedQuestionCard extends StatelessWidget {
  final SavedQuestionEntity question;
  final VoidCallback onRemove;
  final VoidCallback onEditNote;
  final VoidCallback onSolve;

  const SavedQuestionCard({
    super.key,
    required this.question,
    required this.onRemove,
    required this.onEditNote,
    required this.onSolve,
  });

  @override
  Widget build(BuildContext context) {
    final isMistake = question.userAnswerOptionId != null &&
        question.correctOptionId != null &&
        question.userAnswerOptionId != question.correctOptionId;

    return AppCard(
      onTap: onSolve,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  question.examTitle.isNotEmpty ? question.examTitle : 'SAT Math',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              _buildStatusBadge(context, isMistake),
              const SizedBox(width: AppSpacing.s8),
              IconButton(
                icon: const Icon(Icons.bookmark_remove_rounded, color: AppColors.error, size: 20),
                tooltip: context.l10n.removeFromVault,
                onPressed: onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),

          // Question Content (Handles Text, Math, or PDF Exam)
          _buildQuestionContent(context),

          const SizedBox(height: AppSpacing.s12),

          // Note & Smart Solve Action
          Row(
            children: [
              if (question.personalNote != null && question.personalNote!.isNotEmpty)
                Expanded(child: _buildPersonalNoteBox(context))
              else
                Expanded(
                  child: TextButton.icon(
                    onPressed: onEditNote,
                    icon: const Icon(Icons.note_add_outlined, size: 16),
                    label: Text(context.l10n.addPersonalNote, style: const TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      alignment: AlignmentDirectional.centerStart,
                    ),
                  ),
                ),
              const SizedBox(width: AppSpacing.s8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s14,
                    vertical: AppSpacing.s8,
                  ),
                  minimumSize: const Size(0, 36),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(
                  context.l10n.solveQuestionAction,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: onSolve,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isMistake) {
    if (question.isMastered) {
      return _badge(
        label: context.l10n.masteredBadge,
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
      );
    }
    if (question.isDueToday) {
      return _badge(
        label: context.l10n.reviewDueTodayBadge,
        color: AppColors.warning,
        icon: Icons.bolt_rounded,
      );
    }
    if (question.nextReviewAt != null) {
      final days = question.daysUntilReview;
      final label = days <= 1
          ? context.l10n.reviewDueTomorrowBadge
          : context.l10n.reviewDueInDaysBadge(days);
      return _badge(
        label: label,
        color: AppColors.primary,
        icon: Icons.schedule_rounded,
      );
    }
    if (isMistake) {
      return _badge(
        label: context.l10n.previousExamMistakeBadge,
        color: AppColors.error,
        icon: Icons.error_outline_rounded,
      );
    }
    return _badge(
      label: context.l10n.filterNeedsReview,
      color: AppColors.warning,
      icon: Icons.access_time_rounded,
    );
  }

  Widget _badge({required String label, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionContent(BuildContext context) {
    if (question.isPdfQuestion && question.questionText.trim().isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s12),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                '${context.l10n.pdfExamQuestionNotice}${question.questionIndex != null ? ' (#${question.questionIndex})' : ''}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      question.questionText,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
        height: 1.4,
      ),
    );
  }

  Widget _buildPersonalNoteBox(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sticky_note_2_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: AppSpacing.s6),
          Expanded(
            child: Text(
              question.personalNote!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ),
          InkWell(
            onTap: onEditNote,
            child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
