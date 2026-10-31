import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_entity.dart';

class ExamCardTeacherFooter extends StatelessWidget {
  final ExamEntity exam;
  final VoidCallback? onDispatchResults;

  const ExamCardTeacherFooter({
    super.key,
    required this.exam,
    this.onDispatchResults,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.s12),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.s12),
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s6,
          children: [
            if (exam.folderName != null && exam.folderName!.trim().isNotEmpty)
              _buildMetaTag(
                Icons.folder_rounded,
                exam.folderName!,
                customColor: _parseFolderColor(exam.folderColor) ??
                    const Color(0xFF5B4FE0),
              ),
            if (exam.totalQuestions > 0)
              _buildMetaTag(
                Icons.quiz_outlined,
                context.l10n.questionsCountLabel(exam.totalQuestions),
              ),
            _buildMetaTag(
              Icons.timer_outlined,
              exam.isUntimed
                  ? context.l10n.unlimitedTime
                  : context.l10n.minutesDuration(exam.durationMinutes),
            ),
            _buildMetaTag(
              Icons.grade_outlined,
              context.l10n.scorePoints(exam.maxScore),
            ),
            if (exam.passingScore != null)
              _buildMetaTag(
                Icons.verified_outlined,
                '${context.l10n.passingScoreLabel}: ${exam.passingScore}%',
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Row(
          children: [
            const Icon(
              Icons.history_edu_outlined,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Text(
                context.l10n.examVersionAttempts(
                  exam.activeVersion?.versionNumber ?? 1,
                  exam.attemptsCount,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (onDispatchResults != null && exam.attemptsCount > 0) ...[
          const SizedBox(height: AppSpacing.s10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF16A34A),
                side: BorderSide(
                  color: const Color(
                    0xFF16A34A,
                  ).withValues(alpha: 0.35),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppSpacing.radiusSmall,
                  ),
                ),
              ),
              icon: const Icon(Icons.send_rounded, size: 14),
              label: Text(
                context.l10n.examParentDispatchHubTitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: onDispatchResults,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetaTag(IconData icon, String text, {Color? customColor}) {
    final color = customColor ?? AppColors.textSecondary;
    final bgColor = customColor != null
        ? customColor.withValues(alpha: 0.08)
        : AppColors.surfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: customColor != null
            ? Border.all(color: customColor.withValues(alpha: 0.2))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: customColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color? _parseFolderColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return null;
    try {
      final hex = colorStr.replaceAll('#', '');
      if (hex.length == 6) {
        return Color(int.parse('0xFF$hex'));
      } else if (hex.length == 8) {
        return Color(int.parse('0x$hex'));
      }
    } catch (_) {}
    return null;
  }
}
