import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/attached_lesson_exam_entity.dart';
import '../../domain/entities/content_entity.dart';

/// Video Status Badge shown on teacher cards when a video has been uploaded
class ContentVideoStatusBadge extends StatelessWidget {
  final String status; // 'uploading' | 'processing' | 'ready' | 'failed'
  final VoidCallback? onReplace;

  const ContentVideoStatusBadge({
    super.key,
    required this.status,
    this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = status == 'ready';
    final isFailed = status == 'failed';
    final isProcessing = status == 'uploading' || status == 'processing';

    final Color bgColor = isReady
        ? AppColors.success.withAlpha(22)
        : isFailed
        ? AppColors.error.withAlpha(22)
        : AppColors.warning.withAlpha(22);

    final Color borderColor = isReady
        ? AppColors.success.withAlpha(70)
        : isFailed
        ? AppColors.error.withAlpha(70)
        : AppColors.warning.withAlpha(70);

    final Color textColor = isReady
        ? AppColors.success
        : isFailed
        ? AppColors.error
        : AppColors.warning;

    final IconData icon = isReady
        ? Icons.check_circle_rounded
        : isFailed
        ? Icons.error_rounded
        : Icons.hourglass_top_rounded;

    final String label = isReady
        ? context.l10n.videoReadyBadge
        : isFailed
        ? context.l10n.videoFailedBadge
        : context.l10n.videoProcessingBadge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isProcessing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: textColor,
                  ),
                )
              else
                Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        if (onReplace != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: onReplace,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Tooltip(
                message: context.l10n.uploadUpdateLectureVideo,
                child: const Icon(
                  Icons.swap_horiz_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Item indicator inside the content pillars row
class ContentPillarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;

  const ContentPillarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// 3-Pillars row displaying video, handout, and quiz status for a lecture
class ContentPillarsRow extends StatelessWidget {
  final ContentEntity content;

  const ContentPillarsRow({
    super.key,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final hasVideo = content.type == ContentType.video || content.hasVideo;
    final hasHandout = content.file != null;
    final hasQuiz =
        content.attachedExams.isNotEmpty || content.associatedExamId != null;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          // 1. Video Pillar
          Expanded(
            child: ContentPillarItem(
              icon: Icons.play_circle_outline_rounded,
              label: hasVideo
                  ? (content.videoProvider == 'youtube'
                        ? context.l10n.videoSourceYoutube
                        : context.l10n.videoSourceBunny)
                  : context.l10n.videoSourceNone,
              isActive: hasVideo,
              color: hasVideo ? AppColors.primary : AppColors.textMuted,
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: AppColors.border.withValues(alpha: 0.5),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          // 2. Handout Pillar
          Expanded(
            child: ContentPillarItem(
              icon: Icons.picture_as_pdf_outlined,
              label: hasHandout ? 'PDF' : '—',
              isActive: hasHandout,
              color: hasHandout ? const Color(0xFFEA580C) : AppColors.textMuted,
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: AppColors.border.withValues(alpha: 0.5),
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
          // 3. Quiz Pillar
          Expanded(
            child: ContentPillarItem(
              icon: Icons.quiz_outlined,
              label: hasQuiz
                  ? '${content.prerequisitePassingScore ?? 60}%'
                  : '—',
              isActive: hasQuiz,
              color: hasQuiz ? AppColors.success : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner indicating attached quiz and its passing / gate status
class ContentAssociatedExamBanner extends StatelessWidget {
  final ContentEntity content;
  final bool isTeacher;

  const ContentAssociatedExamBanner({
    super.key,
    required this.content,
    required this.isTeacher,
  });

  @override
  Widget build(BuildContext context) {
    final isPassed = content.isExamPassed;
    final canTake = content.canTakeExam;
    final bannerColor = isPassed
        ? AppColors.success
        : canTake
        ? AppColors.primaryLight
        : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.08),
        border: Border.all(color: bannerColor.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            isPassed
                ? Icons.check_circle_outline_rounded
                : canTake
                ? Icons.quiz_outlined
                : Icons.lock_outline_rounded,
            size: 16,
            color: bannerColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content.attachedExams.length > 1
                      ? '${content.attachedExams.where((AttachedLessonExamEntity e) => e.isPassed).length}/${content.attachedExams.length} ${context.l10n.attachedQuizzesSection}'
                      : (content.attachedExams.isNotEmpty &&
                              content.attachedExams.first.examTitle.isNotEmpty
                          ? content.attachedExams.first.examTitle
                          : (content.associatedExamTitle ??
                              context.l10n.quizPrefix)),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: bannerColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isTeacher && !content.isLocked) ...[
                  const SizedBox(height: 2),
                  Text(
                    isPassed
                        ? context.l10n.quizPassedUnlockNext
                        : canTake
                        ? context.l10n.quizUnlockedReady
                        : context.l10n.quizGateNotice,
                    style: TextStyle(
                      fontSize: 10,
                      color: bannerColor.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isTeacher && !content.isLocked)
            TextButton(
              onPressed: () => context.push(AppRoutes.studentExams),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                isPassed
                    ? context.l10n.reviewQuizResultAction
                    : canTake
                    ? context.l10n.takeQuizNowAction
                    : context.l10n.takeRequiredExamAction,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: bannerColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
