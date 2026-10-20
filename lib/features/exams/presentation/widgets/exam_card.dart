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
  final VoidCallback? onMoveToFolder;

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
    this.onMoveToFolder,
  });

  @override
  Widget build(BuildContext context) {
    final isLecture = exam.isLectureExam || isLessonQuiz;
    final isCompleted = !isTeacher && exam.isFullyCompleted;
    final isInProgress = !isTeacher && exam.hasActiveAttempt;

    final Color themeColor = !isTeacher
        ? (isCompleted
              ? AppColors.success
              : (isInProgress
                    ? AppColors.warning
                    : (isLecture
                          ? const Color(0xFF0284C7)
                          : Theme.of(context).colorScheme.primary)))
        : (isLecture ? const Color(0xFF0284C7) : const Color(0xFF7C3AED));

    final Color? cardBgColor = isCompleted
        ? AppColors.success.withValues(alpha: 0.035)
        : (isInProgress ? AppColors.warning.withValues(alpha: 0.02) : null);

    final Color? cardBorderColor = isCompleted
        ? AppColors.success.withValues(alpha: 0.35)
        : (isInProgress ? AppColors.warning.withValues(alpha: 0.35) : null);

    final IconData leadingIcon = !isTeacher
        ? (isCompleted
              ? Icons.check_circle_rounded
              : (isInProgress
                    ? Icons.hourglass_top_rounded
                    : (isLecture
                          ? Icons.menu_book_rounded
                          : Icons.assignment_rounded)))
        : (isLecture ? Icons.menu_book_rounded : Icons.assignment_rounded);

    return LayoutBuilder(
      builder: (context, constraints) {
        return AppCard(
          onTap: onTap,
          variant: AppCardVariant.elevated,
          backgroundColor: cardBgColor,
          borderColor: cardBorderColor,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Icon, Title, Status badge & actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      border: Border.all(
                        color: themeColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(leadingIcon, color: themeColor, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: isTeacher ? 0 : 38,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              exam.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: isTeacher ? 0 : 16,
                          ),
                          child: Text(
                            exam.groupName != null
                                ? context.l10n.groupColon(exam.groupName!)
                                : (isLecture
                                      ? context.l10n.badgeLectureQuiz
                                      : context.l10n.badgeGeneralExam),
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
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
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
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
                              icon: const Icon(
                                Icons.more_vert,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              padding: EdgeInsets.zero,
                              tooltip: context.l10n.settingsTitle,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                              onSelected: (val) {
                                if (val == 'details') {
                                  onTap();
                                } else if (val == 'publish' &&
                                    onPublish != null) {
                                  onPublish!();
                                } else if (val == 'unpublish' &&
                                    onUnpublish != null) {
                                  onUnpublish!();
                                } else if (val == 'edit_questions' &&
                                    onEditQuestions != null) {
                                  onEditQuestions!();
                                } else if (val == 'edit' && onEdit != null) {
                                  onEdit!();
                                } else if (val == 'link' &&
                                    onLinkLecture != null) {
                                  onLinkLecture!();
                                } else if (val == 'unlink' &&
                                    onUnlinkLecture != null) {
                                  onUnlinkLecture!();
                                } else if (val == 'to_lecture' &&
                                    onConvertToLecture != null) {
                                  onConvertToLecture!();
                                } else if (val == 'to_general' &&
                                    onConvertToGeneral != null) {
                                  onConvertToGeneral!();
                                } else if (val == 'delete' &&
                                    onDelete != null) {
                                  onDelete!();
                                } else if (val == 'dispatch_results' &&
                                    onDispatchResults != null) {
                                  onDispatchResults!();
                                } else if (val == 'move_folder' &&
                                    onMoveToFolder != null) {
                                  onMoveToFolder!();
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
                                ] else if (exam.isPublished &&
                                    onUnpublish != null) ...[
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
                                      const Icon(
                                        Icons.analytics_outlined,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
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
                                        const Icon(
                                          Icons.send_rounded,
                                          size: 18,
                                          color: Color(0xFF16A34A),
                                        ),
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
                                if (exam.canEditQuestions &&
                                    onEditQuestions != null)
                                  PopupMenuItem(
                                    value: 'edit_questions',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.edit_note_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
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
                                        const Icon(
                                          Icons.tune_rounded,
                                          size: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(ctx.l10n.editExamSettingsAction),
                                      ],
                                    ),
                                  ),
                                if (onMoveToFolder != null)
                                  PopupMenuItem(
                                    value: 'move_folder',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.drive_file_move_outlined,
                                          size: 18,
                                          color: Color(0xFF5B4FE0),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(ctx.l10n.moveExamToFolderAction),
                                      ],
                                    ),
                                  ),
                                const PopupMenuDivider(),
                                if (onLinkLecture != null)
                                  PopupMenuItem(
                                    value: 'link',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.link_rounded,
                                          size: 18,
                                          color: Color(0xFF0284C7),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          ctx.l10n.linkOrChangeLectureAction,
                                        ),
                                      ],
                                    ),
                                  ),
                                if (exam.isLinkedToLesson &&
                                    onUnlinkLecture != null)
                                  PopupMenuItem(
                                    value: 'unlink',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.link_off_rounded,
                                          size: 18,
                                          color: AppColors.error,
                                        ),
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
                                        const Icon(
                                          Icons.menu_book_rounded,
                                          size: 18,
                                          color: Color(0xFF0284C7),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          ctx.l10n.convertToLectureQuizAction,
                                        ),
                                      ],
                                    ),
                                  ),
                                if (isLecture &&
                                    !exam.isLinkedToLesson &&
                                    onConvertToGeneral != null)
                                  PopupMenuItem(
                                    value: 'to_general',
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.assignment_rounded,
                                          size: 18,
                                          color: Color(0xFF7C3AED),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          ctx.l10n.convertToGeneralExamAction,
                                        ),
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
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
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
                              padding: EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Icon(
                                Icons.swap_horiz_rounded,
                                size: 16,
                                color: Color(0xFF0284C7),
                              ),
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
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
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
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
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

              if (!isTeacher) ...[
                // Student questions progress bar & counters
                const SizedBox(height: AppSpacing.s10),
                _buildStudentQuestionsProgress(context, themeColor),

                // Student clean unified meta metrics bar (Questions • Duration • Score)
                const SizedBox(height: AppSpacing.s8),
                _buildStudentMetaBar(context),

                // Flexible expansion if inside bounded GridView, or clean spacing
                if (constraints.hasBoundedHeight)
                  const Spacer()
                else
                  const SizedBox(height: AppSpacing.s8),

                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.s8),

                // Student action footer
                _buildStudentFooter(context),
              ] else ...[
                // Teacher meta tags & administration actions
                const SizedBox(height: AppSpacing.s12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.s12),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s6,
                  children: [
                    if (exam.folderName != null &&
                        exam.folderName!.trim().isNotEmpty)
                      _buildMetaTag(
                        Icons.folder_rounded,
                        exam.folderName!,
                        customColor:
                            _parseFolderColor(exam.folderColor) ??
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
                if (onDispatchResults != null) ...[
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentQuestionsProgress(
    BuildContext context,
    Color themeColor,
  ) {
    final total = exam.totalQuestions;
    final solved = exam.solvedQuestionsCount;
    final progress = exam.completionProgress;
    final isCompleted = exam.isFullyCompleted;
    final isInProgress = exam.hasActiveAttempt;

    final Color progressColor = isCompleted
        ? AppColors.success
        : (isInProgress
              ? AppColors.warning
              : Theme.of(context).colorScheme.primary);

    final String progressText = isCompleted
        ? (total > 0 && solved >= total
              ? context.l10n.examQuestionsAllSolved(total)
              : context.l10n.examQuestionsSolvedProgress(solved, total))
        : (isInProgress
              ? context.l10n.examQuestionsSolvedProgress(solved, total)
              : context.l10n.examNotStartedYet(total));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: progressColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: progressColor.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isCompleted
                          ? Icons.check_circle_rounded
                          : (isInProgress
                                ? Icons.pending_actions_rounded
                                : Icons.quiz_outlined),
                      size: 15,
                      color: progressColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        progressText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: progressColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: progressColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentMetaBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s6,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // 1. Duration
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  exam.isUntimed
                      ? context.l10n.unlimitedTime
                      : context.l10n.minutesDuration(exam.durationMinutes),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Container(width: 1, height: 12, color: AppColors.border),
            // 2. Max Score
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.grade_outlined,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  context.l10n.scorePoints(exam.maxScore),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (exam.passingScore != null) ...[
              Container(width: 1, height: 12, color: AppColors.border),
              // 3. Passing Score
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.verified_outlined,
                    size: 13,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${context.l10n.passingScoreLabel}: ${exam.passingScore}%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentFooter(BuildContext context) {
    final isCompleted = exam.isFullyCompleted;
    final isInProgress = exam.hasActiveAttempt;

    if (isCompleted) {
      final attempt = exam.myLatestAttempt;
      final displayScore = exam.myBestScore ?? attempt?.score;
      return Wrap(
        spacing: AppSpacing.s8,
        runSpacing: AppSpacing.s8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (displayScore != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.military_tech_rounded,
                    size: 14,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.examScoreAchieved(
                      displayScore,
                      exam.maxScore,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: AppSpacing.s4,
            runSpacing: AppSpacing.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (exam.canTakeExam)
                IconButton(
                  onPressed: onTap,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  tooltip: context.l10n.tryAgainExamAction,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.all(AppSpacing.s6),
                  ),
                ),
              if (onReview != null)
                FilledButton.tonalIcon(
                  onPressed: onReview,
                  icon: const Icon(Icons.fact_check_outlined, size: 14),
                  label: Text(context.l10n.viewExamResultAction),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success.withValues(alpha: 0.14),
                    foregroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s10,
                      vertical: AppSpacing.s6,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    }

    if (isInProgress) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 280;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        context.l10n.attemptStatusInProgress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s6),
                FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s10,
                      vertical: AppSpacing.s6,
                    ),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.examResumeAction,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_top_rounded,
                      size: 14,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        context.l10n.attemptStatusInProgress,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s6,
                  ),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.examResumeAction,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 280;
        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      context.l10n.availableToStart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s6),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s6,
                  ),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.startExamAction,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      context.l10n.availableToStart,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s6,
                ),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.startExamAction,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
              isPublished
                  ? context.l10n.publishedBadge
                  : context.l10n.draftBadge,
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
    final displayScore = exam.myBestScore ?? attempt?.score;
    if (exam.isFullyCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              size: 13,
              color: AppColors.success,
            ),
            const SizedBox(width: 4),
            Text(
              displayScore != null
                  ? '${context.l10n.examCompletedCheck} ($displayScore/${exam.maxScore})'
                  : context.l10n.examCompletedCheck,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    if (exam.hasActiveAttempt || (attempt != null && attempt.isInProgress && !exam.isFullyCompleted)) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.hourglass_top_rounded,
              size: 12,
              color: AppColors.warning,
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.attemptStatusInProgress,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s8,
        vertical: AppSpacing.s4,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.rocket_launch_outlined,
            size: 12,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            context.l10n.availableToStart,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
