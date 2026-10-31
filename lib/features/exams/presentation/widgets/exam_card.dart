import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';
import 'exam_card_status_badge.dart';
import 'exam_card_student_footer.dart';
import 'exam_card_student_metrics.dart';
import 'exam_card_teacher_footer.dart';
import 'exam_card_teacher_linkage_banner.dart';
import 'exam_card_teacher_menu.dart';

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
                            ExamCardTeacherMenu(
                              exam: exam,
                              onTap: onTap,
                              onPublish: onPublish,
                              onUnpublish: onUnpublish,
                              onEditQuestions: onEditQuestions,
                              onEdit: onEdit,
                              onLinkLecture: onLinkLecture,
                              onUnlinkLecture: onUnlinkLecture,
                              onConvertToLecture: onConvertToLecture,
                              onConvertToGeneral: onConvertToGeneral,
                              onDelete: onDelete,
                              onDispatchResults: onDispatchResults,
                              onMoveToFolder: onMoveToFolder,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // Distinct Linkage Banner for Teachers
              if (isTeacher)
                ExamCardTeacherLinkageBanner(
                  exam: exam,
                  isLecture: isLecture,
                  onLinkLecture: onLinkLecture,
                ),

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
                ExamCardTeacherFooter(
                  exam: exam,
                  onDispatchResults: onDispatchResults,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
