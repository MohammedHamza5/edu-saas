import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';
import 'exam_card_status_badge.dart';
import 'exam_card_student_footer.dart';
import 'exam_card_student_metrics.dart';

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
                          ExamCardStatusBadge(
                            exam: exam,
                            isTeacher: isTeacher,
                            onPublish: onPublish,
                          ),
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
                                if (onDispatchResults != null && exam.attemptsCount > 0)
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
                const SizedBox(height: AppSpacing.s10),
                ExamCardStudentMetrics(
                  exam: exam,
                  themeColor: themeColor,
                ),

                // Flexible expansion if inside bounded GridView, or clean spacing
                if (constraints.hasBoundedHeight)
                  const Spacer()
                else
                  const SizedBox(height: AppSpacing.s8),

                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: AppSpacing.s8),

                // Student action footer
                ExamCardStudentFooter(
                  exam: exam,
                  onTap: onTap,
                  onReview: onReview,
                ),
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
            ],
          ),
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
}
