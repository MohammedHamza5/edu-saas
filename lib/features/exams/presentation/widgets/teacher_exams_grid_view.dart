import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../domain/entities/exam_entity.dart';
import 'edit_exam_dialog.dart';
import 'exam_card.dart';

/// Virtualized Sliver Grid of exam cards with empty state handling.
/// Renders only cards currently in the viewport with isolated repaint boundaries.
class TeacherExamsGridView extends StatelessWidget {
  final List<ExamEntity> filteredExams;
  final String? selectedFolderId;
  final bool isLoadingMore;
  final VoidCallback onClearFilters;
  final void Function(ExamEntity exam) onTapExam;
  final void Function(ExamEntity exam) onEditQuestions;
  final void Function(ExamEntity exam) onLinkLecture;
  final void Function(ExamEntity exam) onUnlinkLecture;
  final void Function(ExamEntity exam) onConvertToLecture;
  final void Function(ExamEntity exam) onConvertToGeneral;
  final void Function(ExamEntity exam) onPublish;
  final void Function(ExamEntity exam) onUnpublish;
  final void Function(ExamEntity exam) onDelete;
  final void Function(ExamEntity exam) onDispatchResults;
  final void Function(ExamEntity exam) onMoveToFolder;
  final void Function(ExamEntity exam, ExamCategory targetCategory)? onMoveCategory;

  const TeacherExamsGridView({
    super.key,
    required this.filteredExams,
    required this.selectedFolderId,
    required this.isLoadingMore,
    required this.onClearFilters,
    required this.onTapExam,
    required this.onEditQuestions,
    required this.onLinkLecture,
    required this.onUnlinkLecture,
    required this.onConvertToLecture,
    required this.onConvertToGeneral,
    required this.onPublish,
    required this.onUnpublish,
    required this.onDelete,
    required this.onDispatchResults,
    required this.onMoveToFolder,
    this.onMoveCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (filteredExams.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: AppEmptyView(
              icon: Icons.search_off_rounded,
              message: selectedFolderId != null
                  ? context.l10n.emptyFolderTitle
                  : context.l10n.noMatchingExamsFound,
              subtitle: selectedFolderId != null
                  ? context.l10n.emptyFolderSubtitle
                  : null,
              actionText: context.l10n.clearSearchAction,
              onAction: onClearFilters,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 420,
          mainAxisSpacing: AppSpacing.s16,
          crossAxisSpacing: AppSpacing.s16,
          mainAxisExtent: 360,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final exam = filteredExams[index];
            return RepaintBoundary(
              key: ValueKey('teacher_exam_${exam.id}'),
              child: ExamCard(
                exam: exam,
                isTeacher: true,
                onTap: () => onTapExam(exam),
                onEdit: () => EditExamDialog.show(context, exam),
                onEditQuestions: () => onEditQuestions(exam),
                onLinkLecture: () => onLinkLecture(exam),
                onUnlinkLecture: () => onUnlinkLecture(exam),
                onConvertToLecture: () => onConvertToLecture(exam),
                onConvertToGeneral: () => onConvertToGeneral(exam),
                onPublish: () => onPublish(exam),
                onUnpublish: () => onUnpublish(exam),
                onDelete: () => onDelete(exam),
                onDispatchResults: () => onDispatchResults(exam),
                onMoveToFolder: () => onMoveToFolder(exam),
                onMoveCategory: onMoveCategory != null
                    ? (cat) => onMoveCategory!(exam, cat)
                    : null,
              ),
            );
          },
          childCount: filteredExams.length,
        ),
      ),
    );
  }
}
