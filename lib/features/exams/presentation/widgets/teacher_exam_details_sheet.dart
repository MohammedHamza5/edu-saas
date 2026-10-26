import 'package:go_router/go_router.dart';
import 'edit_exam_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import 'student_attempts_group_card.dart';

class TeacherExamDetailsSheetContent extends StatefulWidget {
  final ExamEntity exam;
  final ExamsCubit cubit;
  final VoidCallback onLinkLecture;
  final VoidCallback onUnlinkLecture;
  final VoidCallback onDeleteExam;
  final VoidCallback? onEditQuestions;

  const TeacherExamDetailsSheetContent({
    super.key,
    required this.exam,
    required this.cubit,
    required this.onLinkLecture,
    required this.onUnlinkLecture,
    required this.onDeleteExam,
    this.onEditQuestions,
  });

  @override
  State<TeacherExamDetailsSheetContent> createState() =>
      TeacherExamDetailsSheetContentState();
}

class TeacherExamDetailsSheetContentState extends State<TeacherExamDetailsSheetContent> {
  bool _isPublishing = false;
  bool _isUnpublishing = false;
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (ctx, scrollController) {
        return BlocBuilder<ExamsCubit, ExamsState>(
          builder: (context, state) {
            if (state is! TeacherExamsLoaded) {
              return const AppLoadingView.list(count: 3);
            }

            final exam = (state.selectedExam?.id == widget.exam.id ? state.selectedExam : null) ??
                state.exams.where((e) => e.id == widget.exam.id).firstOrNull ??
                widget.exam;
            final isLecture = exam.isLectureExam;
            final isPublished = exam.isPublished;
            final activeVersionNumber = exam.activeVersion?.versionNumber ?? 1;

            final attempts = state.attempts;
            final isLoading = state.isLoadingAttempts;

            return Column(
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              exam.title,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),

                      // Badges Row
                      const SizedBox(height: AppSpacing.s8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Type badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isLecture
                                      ? const Color(0xFF0284C7)
                                      : const Color(0xFF7C3AED))
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSmall),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLecture
                                      ? Icons.menu_book_rounded
                                      : Icons.assignment_rounded,
                                  size: 13,
                                  color: isLecture
                                      ? const Color(0xFF0284C7)
                                      : const Color(0xFF7C3AED),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isLecture
                                      ? context.l10n.badgeLectureQuiz
                                      : context.l10n.badgeGeneralExam,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isLecture
                                        ? const Color(0xFF0284C7)
                                        : const Color(0xFF7C3AED),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Lecture linkage badge
                          if (isLecture) ...[
                            if (exam.isLinkedToLesson)
                              InkWell(
                                onTap: widget.onLinkLecture,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.link_rounded,
                                        size: 13,
                                        color: AppColors.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        context.l10n.linkedToLecturePill(
                                          exam.linkedLessonTitle ?? '',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.edit_outlined,
                                        size: 11,
                                        color: AppColors.success,
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              InkWell(
                                onTap: widget.onLinkLecture,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.warning
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                    border: Border.all(
                                      color: AppColors.warning
                                          .withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 13,
                                        color: AppColors.warning,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        context.l10n.unlinkedQuizPill,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '(${context.l10n.linkToLectureNowAction})',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0284C7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],

                          // Version status badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isPublished
                                      ? AppColors.success
                                      : AppColors.warning)
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSmall),
                            ),
                            child: Text(
                              'v$activeVersionNumber (${isPublished ? context.l10n.versionPublishedPill : context.l10n.versionDraftPill})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPublished
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      // Draft notice if not published
                      if (!isPublished) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s10),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSmall),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    size: 16,
                                    color: AppColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      context.l10n.draftVersionNotice,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.onEditQuestions != null) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    label: Text(
                                      context.l10n.editQuestionsNow,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    onPressed: widget.onEditQuestions,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s12),
                      ],

                      // Action Buttons: Edit, Create v2, Publish, Link/Unlink
                      Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s8,
                        children: [
                          // Prominent Edit Questions button (always available)
                          if (widget.onEditQuestions != null)
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(
                                Icons.edit_note_rounded,
                                size: 16,
                              ),
                              label: Text(context.l10n.editDraftQuestionsAction),
                              onPressed: widget.onEditQuestions,
                            ),

                          // Edit basic settings
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.tune_rounded,
                              size: 15,
                            ),
                            label: Text(context.l10n.editExamSettingsAction),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              EditExamDialog.show(context, exam);
                            },
                          ),

                          // Parent Dispatch Hub Action Button
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF16A34A),
                              side: BorderSide(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.5),
                              ),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 14),
                            label: Text(context.l10n.examParentDispatchHubTitle),
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              context.push(
                                '/teacher/exams/${exam.id}/parent-dispatch?title=${Uri.encodeComponent(exam.title)}',
                              );
                            },
                          ),

                            // Unpublish button to revert back to draft and hide from students
                            if (exam.activeVersion != null)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.warning,
                                  side: const BorderSide(color: AppColors.warning),
                                ),
                                icon: _isUnpublishing
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.warning,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.visibility_off_outlined,
                                        size: 15,
                                      ),
                                label: Text(
                                  _isUnpublishing
                                      ? context.l10n.unpublishingExamLoading
                                      : context.l10n.unpublishExamAction,
                                ),
                                onPressed: _isUnpublishing
                                    ? null
                                    : () async {
                                        final messenger = ScaffoldMessenger.of(context);
                                        final nav = Navigator.of(ctx);
                                        final successMsg = context.l10n.examUnpublishedSuccess;

                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (dialogCtx) => AlertDialog(
                                            title: Row(
                                              children: [
                                                const Icon(
                                                  Icons.visibility_off_outlined,
                                                  color: AppColors.warning,
                                                  size: 24,
                                                ),
                                                const SizedBox(width: AppSpacing.s8),
                                                Expanded(
                                                  child: Text(dialogCtx.l10n.confirmUnpublishExamTitle),
                                                ),
                                              ],
                                            ),
                                            content: Text(dialogCtx.l10n.confirmUnpublishExamBody(exam.title)),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(dialogCtx).pop(false),
                                                child: Text(dialogCtx.l10n.cancel),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.warning,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => Navigator.of(dialogCtx).pop(true),
                                                child: Text(dialogCtx.l10n.confirmUnpublishButton),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirmed != true) return;

                                        setState(() => _isUnpublishing = true);
                                        final success = await widget.cubit.unpublishVersion(
                                          examId: exam.id,
                                          versionId: exam.activeVersion!.id,
                                        );
                                        if (mounted && ctx.mounted) {
                                          setState(() => _isUnpublishing = false);
                                          if (success) {
                                            nav.pop();
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(successMsg),
                                                backgroundColor: AppColors.success,
                                              ),
                                            );
                                          }
                                        }
                                      },
                              ),

                          // If draft: Publish version button
                          if (!isPublished && exam.activeVersion != null) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                              ),
                              icon: _isPublishing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 15,
                                    ),
                              label: Text(
                                _isPublishing
                                    ? context.l10n.publishingVersionLoading
                                    : context.l10n.publishCurrentDraftAction,
                              ),
                              onPressed: _isPublishing
                                  ? null
                                  : () async {
                                      setState(() => _isPublishing = true);
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final nav = Navigator.of(ctx);
                                      final publishedSuccessMsg = context
                                          .l10n
                                          .versionPublishedSuccess;
                                      final success = await widget.cubit
                                          .publishVersion(
                                        exam.activeVersion!.id,
                                        exam.id,
                                      );
                                      if (mounted && ctx.mounted) {
                                        setState(() => _isPublishing = false);
                                        if (success) {
                                          nav.pop();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                publishedSuccessMsg,
                                              ),
                                              backgroundColor: AppColors.success,
                                            ),
                                          );
                                        }
                                      }
                                    },
                            ),
                          ],

                          // Link / Unlink shortcuts
                          if (isLecture) ...[
                            OutlinedButton.icon(
                              icon: const Icon(Icons.link_rounded, size: 15),
                              label: Text(
                                exam.isLinkedToLesson
                                    ? context.l10n.linkOrChangeLectureAction
                                    : context.l10n.linkToLectureNowAction,
                              ),
                              onPressed: widget.onLinkLecture,
                            ),
                            if (exam.isLinkedToLesson)
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.link_off_rounded,
                                  size: 15,
                                  color: AppColors.warning,
                                ),
                                label: Text(
                                  context.l10n.unlinkFromLectureAction,
                                  style: const TextStyle(
                                    color: AppColors.warning,
                                  ),
                                ),
                                onPressed: widget.onUnlinkLecture,
                              ),
                          ],

                          // Delete / Archive Exam
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.error),
                            ),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 15,
                              color: AppColors.error,
                            ),
                            label: Text(
                              context.l10n.deleteExamAction,
                              style: const TextStyle(color: AppColors.error),
                            ),
                            onPressed: widget.onDeleteExam,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),



                // Attempts List grouped by student
                Expanded(
                  child: isLoading
                      ? const AppLoadingView.list(count: 3)
                      : attempts.isEmpty
                          ? Center(
                              child: AppEmptyView(
                                message: context.l10n.noAttemptsYet,
                                subtitle: context.l10n.noAttemptsYetSubtitle,
                                icon: Icons.quiz_outlined,
                              ),
                            )
                          : _buildGroupedAttemptsList(
                              attempts: attempts,
                              exam: exam,
                              scrollController: scrollController,
                              context: context,
                              isLoadingMore: state.isLoadingMoreAttempts,
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildGroupedAttemptsList({
    required List<ExamAttemptEntity> attempts,
    required ExamEntity exam,
    required ScrollController scrollController,
    required BuildContext context,
    required bool isLoadingMore,
  }) {
    // Sort attempts by date descending
    final sorted = List<ExamAttemptEntity>.from(attempts)
      ..sort((a, b) {
        final dateA = a.submittedAt ?? a.startedAt;
        final dateB = b.submittedAt ?? b.startedAt;
        return dateB.compareTo(dateA);
      });

    final Map<String, StudentAttemptsGroup> groupsMap = {};
    for (final att in sorted) {
      final key = att.studentId.isNotEmpty ? att.studentId : (att.studentName ?? 'unknown');
      if (!groupsMap.containsKey(key)) {
        groupsMap[key] = StudentAttemptsGroup(
          studentId: att.studentId,
          studentName: att.studentName != null && att.studentName!.trim().isNotEmpty
              ? att.studentName!.trim()
              : context.l10n.studentFallbackName,
          attempts: [],
        );
      }
      groupsMap[key]!.attempts.add(att);
    }

    final groups = groupsMap.values.toList();

    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          widget.cubit.loadMoreExamAttempts();
        }
        return false;
      },
      child: ListView.builder(
        controller: scrollController,
        cacheExtent: 350.0,
        padding: const EdgeInsets.all(AppSpacing.s16),
        itemCount: groups.length + 1 + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.people_alt_outlined,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      context.l10n.studentsCountSummary(groups.length),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.history_edu_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Text(
                      context.l10n.totalAttemptsSummary(attempts.length),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (index == groups.length + 1) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
              child: Center(
                child: AppLoadingView.compact(size: 24),
              ),
            );
          }

          final group = groups[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: StudentAttemptsGroupCard(
              group: group,
              exam: exam,
              dateFormat: _dateFormat,
            ),
          );
        },
      ),
    );
  }
}

