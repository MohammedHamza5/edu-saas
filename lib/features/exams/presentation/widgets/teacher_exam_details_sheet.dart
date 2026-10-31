import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import 'teacher_exam_actions_toolbar.dart';
import 'teacher_exam_attempts_list.dart';
import 'teacher_exam_header_section.dart';

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

class TeacherExamDetailsSheetContentState
    extends State<TeacherExamDetailsSheetContent> {
  final DateFormat _dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');

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

            final exam = (state.selectedExam?.id == widget.exam.id
                    ? state.selectedExam
                    : null) ??
                state.exams
                    .where((e) => e.id == widget.exam.id)
                    .firstOrNull ??
                widget.exam;

            final attempts = state.attempts;
            final isLoading = state.isLoadingAttempts;

            return Column(
              children: [
                // Header & Badges & Draft notice
                TeacherExamHeaderSection(
                  exam: exam,
                  onLinkLecture: widget.onLinkLecture,
                  onEditQuestions: widget.onEditQuestions,
                  onClose: () => Navigator.of(ctx).pop(),
                ),

                // Action Buttons
                TeacherExamActionsToolbar(
                  exam: exam,
                  cubit: widget.cubit,
                  onLinkLecture: widget.onLinkLecture,
                  onUnlinkLecture: widget.onUnlinkLecture,
                  onDeleteExam: widget.onDeleteExam,
                  onEditQuestions: widget.onEditQuestions,
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),

                // Attempts List grouped by student
                Expanded(
                  child: isLoading
                      ? const AppLoadingView.list(count: 3)
                      : attempts.isEmpty
                          ? Center(
                              child: AppEmptyView(
                                message: context.l10n.noAttemptsYet,
                                subtitle:
                                    context.l10n.noAttemptsYetSubtitle,
                                icon: Icons.quiz_outlined,
                              ),
                            )
                          : TeacherExamAttemptsList(
                              attempts: attempts,
                              exam: exam,
                              scrollController: scrollController,
                              cubit: widget.cubit,
                              isLoadingMore: state.isLoadingMoreAttempts,
                              dateFormat: _dateFormat,
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
