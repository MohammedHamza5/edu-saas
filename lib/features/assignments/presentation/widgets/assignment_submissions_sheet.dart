import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/assignment_entity.dart';
import '../cubit/assignments_cubit.dart';
import '../cubit/assignments_state.dart';
import '../pages/grade_submission_page.dart';
import 'edit_assignment_dialog.dart';
import 'submission_tile.dart';

/// Modal bottom sheet content displaying student submissions for an assignment.
class AssignmentSubmissionsSheet extends StatefulWidget {
  final AssignmentEntity assignment;
  final ScrollController scrollController;

  const AssignmentSubmissionsSheet({
    super.key,
    required this.assignment,
    required this.scrollController,
  });

  /// Opens the submissions bottom sheet modal.
  static void show(BuildContext context, AssignmentEntity assignment) {
    final cubit = context.read<AssignmentsCubit>();
    cubit.selectAssignmentForTeacher(assignment);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (sheetContext) {
        return BlocProvider.value(
          value: cubit,
          child: DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (ctx, scrollController) {
              return AssignmentSubmissionsSheet(
                assignment: assignment,
                scrollController: scrollController,
              );
            },
          ),
        );
      },
    );
  }

  @override
  State<AssignmentSubmissionsSheet> createState() =>
      _AssignmentSubmissionsSheetState();
}

class _AssignmentSubmissionsSheetState
    extends State<AssignmentSubmissionsSheet> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (widget.scrollController.hasClients &&
        widget.scrollController.position.pixels >=
            widget.scrollController.position.maxScrollExtent - 200) {
      context.read<AssignmentsCubit>().loadMoreSubmissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssignmentsCubit, AssignmentsState>(
      builder: (context, state) {
        if (state is! TeacherAssignmentsLoaded) {
          return const AppLoadingView.list(count: 3);
        }

        final submissions = state.submissions;
        final isLoading = state.isLoadingSubmissions;
        final assignment = widget.assignment;

        return Column(
          children: [
            // Header
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          assignment.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: context.l10n.editAssignmentAction,
                        onPressed: () {
                          Navigator.of(context).pop();
                          EditAssignmentDialog.show(context, assignment);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  Text(
                    context.l10n.submissionsCountWithReviewed(
                      submissions.length.toString(),
                      assignment.reviewedCount.toString(),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Submissions List
            Expanded(
              child: isLoading
                  ? const AppLoadingView.list(count: 3)
                  : submissions.isEmpty
                  ? Center(
                      child: AppEmptyView(
                        message: context.l10n.noSubmissionsYetTitle,
                        subtitle: context.l10n.noSubmissionsYetSubtitle,
                        icon: Icons.assignment_turned_in_outlined,
                      ),
                    )
                  : ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      itemCount:
                          submissions.length +
                          (state.isLoadingMoreSubmissions ? 1 : 0),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s8),
                      itemBuilder: (context, index) {
                        if (index == submissions.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.s16,
                            ),
                            child: Center(
                              child: AppLoadingView.compact(size: 24),
                            ),
                          );
                        }
                        final sub = submissions[index];
                        return SubmissionTile(
                          submission: sub,
                          maxScore: assignment.maxScore,
                          onTap: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<AssignmentsCubit>(),
                                  child: GradeSubmissionPage(
                                    assignment: assignment,
                                    submission: sub,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
