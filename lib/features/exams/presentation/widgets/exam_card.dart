import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';

class ExamCard extends StatelessWidget {
  final ExamEntity exam;
  final VoidCallback onTap;
  final bool isTeacher;
  final bool isLessonQuiz;
  final VoidCallback? onReview;
  final VoidCallback? onEdit;
  final VoidCallback? onEditQuestions;
  final VoidCallback? onLinkLecture;
  final VoidCallback? onUnlinkLecture;
  final VoidCallback? onConvertToLecture;
  final VoidCallback? onConvertToGeneral;
  final VoidCallback? onPublish;
  final VoidCallback? onUnpublish;
  final VoidCallback? onDelete;
  final VoidCallback? onDispatchResults;

  const ExamCard({
    super.key,
    required this.exam,
    required this.onTap,
    this.isTeacher = false,
    this.isLessonQuiz = false,
    this.onReview,
    this.onEdit,
    this.onEditQuestions,
    this.onLinkLecture,
    this.onUnlinkLecture,
    this.onConvertToLecture,
    this.onConvertToGeneral,
    this.onPublish,
    this.onUnpublish,
    this.onDelete,
    this.onDispatchResults,
  });

  @override
  Widget build(BuildContext context) {
    final isLecture = exam.isLectureExam || isLessonQuiz;
    final themeColor = isLecture ? const Color(0xFF0284C7) : const Color(0xFF7C3AED);

    return AppCard(
      onTap: onTap,
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Icon, Title, Status badge & actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: themeColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  isLecture
                      ? Icons.menu_book_rounded
                      : Icons.assignment_rounded,
                  color: themeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (exam.groupName != null) ...[
                      const SizedBox(height: AppSpacing.s4),
                      Text(
                        context.l10n.groupColon(exam.groupName!),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Type badge (Visible for both teachers and students)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s8,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLecture
                              ? Icons.menu_book_rounded
                              : Icons.assignment_rounded,
                          size: 11,
                          color: themeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isLecture
                              ? context.l10n.badgeLectureQuiz
                              : context.l10n.badgeGeneralExam,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusBadge(context),
                      if (isTeacher) ...[
                        const SizedBox(width: 2),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textSecondary),
                          padding: EdgeInsets.zero,
                          tooltip: context.l10n.settingsTitle,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          ),
                          onSelected: (val) {
                            if (val == 'details') {
                              onTap();
                            } else if (val == 'publish' && onPublish != null) {
                              onPublish!();
                            } else if (val == 'unpublish' && onUnpublish != null) {
                              onUnpublish!();
                            } else if (val == 'edit_questions' && onEditQuestions != null) {
                              onEditQuestions!();
                            } else if (val == 'edit' && onEdit != null) {
                              onEdit!();
                            } else if (val == 'link' && onLinkLecture != null) {
                              onLinkLecture!();
                            } else if (val == 'unlink' && onUnlinkLecture != null) {
                              onUnlinkLecture!();
                            } else if (val == 'to_lecture' && onConvertToLecture != null) {
                              onConvertToLecture!();
                            } else if (val == 'to_general' && onConvertToGeneral != null) {
                              onConvertToGeneral!();
                            } else if (val == 'delete' && onDelete != null) {
                              onDelete!();
                            } else if (val == 'dispatch_results' && onDispatchResults != null) {
                              onDispatchResults!();
                            }
                          },
                          itemBuilder: (ctx) => [
                            if (!exam.isPublished && onPublish != null) ...[
                              PopupMenuItem(
                                value: 'publish',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 18,
                                      color: AppColors.success,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ctx.l10n.publishCurrentDraftAction,
                                      style: const TextStyle(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                            ] else if (exam.isPublished && onUnpublish != null) ...[
                              PopupMenuItem(
                                value: 'unpublish',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.visibility_off_outlined,
                                      size: 18,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ctx.l10n.unpublishExamAction,
                                      style: const TextStyle(
                                        color: AppColors.warning,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuDivider(),
                            ],
                            PopupMenuItem(
                              value: 'details',
                              child: Row(
                                children: [
                                  const Icon(Icons.analytics_outlined, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(ctx.l10n.viewExamDetailsAndAttempts),
                                ],
                              ),
                            ),
                            if (onDispatchResults != null)
                              PopupMenuItem(
                                value: 'dispatch_results',
                                child: Row(
                                  children: [
                                    const Icon(Icons.send_rounded, size: 18, color: Color(0xFF16A34A)),
                                    const SizedBox(width: 8),
                                    Text(
                                      ctx.l10n.examParentDispatchHubTitle,
                                      style: const TextStyle(
                                        color: Color(0xFF16A34A),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (exam.canEditQuestions && onEditQuestions != null)
                              PopupMenuItem(
                                value: 'edit_questions',
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.primary),
                                    const SizedBox(width: 8),
                                    Text(
                                      ctx.l10n.editDraftQuestionsAction,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (onEdit != null)
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    const Icon(Icons.tune_rounded, size: 18, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Text(ctx.l10n.editExamSettingsAction),
                                  ],
                                ),
                              ),
                            const PopupMenuDivider(),
                            if (onLinkLecture != null)
                              PopupMenuItem(
                                value: 'link',
                                child: Row(
                                  children: [
                                    const Icon(Icons.link_rounded, size: 18, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 8),
                                    Text(ctx.l10n.linkOrChangeLectureAction),
                                  ],
                                ),
                              ),
                            if (exam.isLinkedToLesson && onUnlinkLecture != null)
                              PopupMenuItem(
                                value: 'unlink',
                                child: Row(
                                  children: [
                                    const Icon(Icons.link_off_rounded, size: 18, color: AppColors.error),
                                    const SizedBox(width: 8),
                                    Text(ctx.l10n.unlinkFromLectureAction),
                                  ],
                                ),
                              ),
                            if (!isLecture && onConvertToLecture != null)
                              PopupMenuItem(
                                value: 'to_lecture',
                                child: Row(
                                  children: [
                                    const Icon(Icons.menu_book_rounded, size: 18, color: Color(0xFF0284C7)),
                                    const SizedBox(width: 8),
                                    Text(ctx.l10n.convertToLectureQuizAction),
                                  ],
                                ),
                              ),
                            if (isLecture && !exam.isLinkedToLesson && onConvertToGeneral != null)
                              PopupMenuItem(
                                value: 'to_general',
                                child: Row(
                                  children: [
                                    const Icon(Icons.assignment_rounded, size: 18, color: Color(0xFF7C3AED)),
                                    const SizedBox(width: 8),
                                    Text(ctx.l10n.convertToGeneralExamAction),
                                  ],
                                ),
                              ),
                            if (onDelete != null) ...[
                              const PopupMenuDivider(),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: AppColors.error,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      ctx.l10n.deleteExamAction,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Distinct Linkage Banner for Teachers
          if (isTeacher) ...[
            if (isLecture && exam.isLinkedToLesson)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.s10),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 15,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.linkedToLecturePill(
                          exam.linkedLessonTitle ?? '',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0284C7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onLinkLecture != null)
                      InkWell(
                        onTap: onLinkLecture,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF0284C7)),
                        ),
                      ),
                  ],
                ),
              )
            else if (isLecture && !exam.isLinkedToLesson)
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.s10),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 15,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.unlinkedQuizPill,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (onLinkLecture != null) ...[
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: onLinkLecture,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            context.l10n.linkToLectureNowAction,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.s10),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.public_rounded,
                      size: 13,
                      color: Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.l10n.statGeneralExamsDesc,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7C3AED),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: AppSpacing.s12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSpacing.s12),

          // Meta tags row: Duration, Max score, Passing score
          Wrap(
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s6,
            children: [
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

          // Teacher meta: Version & Attempts
          if (isTeacher) ...[
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
            if (onDispatchResults != null) ...[
              const SizedBox(height: AppSpacing.s10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16A34A),
                    side: BorderSide(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.35),
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

          // Student review action button
          if (!isTeacher &&
              exam.hasAttempted &&
              exam.myLatestAttempt?.isSubmitted == true &&
              onReview != null) ...[
            const SizedBox(height: AppSpacing.s10),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s6),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: onReview,
                icon: const Icon(Icons.fact_check_outlined, size: 16),
                label: Text(
                  context.l10n.reviewExamAnswersAction,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s4,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    if (isTeacher) {
      final isPublished = exam.isPublished;
      final badgeContent = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: (isPublished ? AppColors.success : AppColors.warning)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isPublished) ...[
              const Icon(
                Icons.cloud_upload_outlined,
                size: 11,
                color: AppColors.warning,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              isPublished ? context.l10n.publishedBadge : context.l10n.draftBadge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isPublished ? AppColors.success : AppColors.warning,
              ),
            ),
          ],
        ),
      );

      if (!isPublished && onPublish != null) {
        return InkWell(
          onTap: onPublish,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          child: Tooltip(
            message: context.l10n.publishCurrentDraftAction,
            child: badgeContent,
          ),
        );
      }

      return badgeContent;
    }

    // Student Status Badge
    final attempt = exam.myLatestAttempt;
    if (attempt == null) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Text(
          context.l10n.availableToStart,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      );
    }

    if (attempt.isInProgress) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Text(
          context.l10n.inProgressResume,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.warning,
          ),
        ),
      );
    }

    final isPassed = attempt.isPassed(exam.passingScore);
    final badgeColor = isPassed ? AppColors.success : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      ),
      child: Text(
        attempt.score != null
            ? '${attempt.score}/${exam.maxScore}'
            : (isPassed ? context.l10n.passed : context.l10n.notPassed),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }
}
