import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../domain/entities/exam_entity.dart';
import 'edit_exam_dialog.dart';
import 'exam_card.dart';

/// Grid view of exam cards with empty state handling and pagination spinner.
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
  });

  @override
  Widget build(BuildContext context) {
    if (filteredExams.isEmpty) {
      return Padding(
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
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ResponsiveGrid(
          mobileColumns: 1,
          tabletColumns: 2,
          desktopColumns: 3,
          largeDesktopColumns: 4,
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s16,
          children: filteredExams.map((exam) {
            return ExamCard(
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
            );
          }).toList(),
        ),
        if (isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
            child: Center(
              child: AppLoadingView.compact(size: 24),
            ),
          ),
      ],
    );
  }
}
