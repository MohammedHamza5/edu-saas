import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../utils/teacher_exams_actions_coordinator.dart';
import 'exam_folders_bar.dart';
import 'teacher_exams_filter_bar.dart';
import 'teacher_exams_grid_view.dart';
import 'teacher_exams_stats_banner.dart';

/// Loaded content view of TeacherExamsPage displaying stats banner, folders, filters, and exam cards grid.
class TeacherExamsLoadedView extends StatelessWidget {
  final TeacherExamsLoaded state;
  final ScrollController scrollController;
  final String? selectedGroupId;
  final String activeTypeFilter;
  final String activeLectureSubFilter;
  final String activeStatusFilter;
  final String searchQuery;
  final TextEditingController searchController;
  final ValueChanged<String> onTypeFilterChanged;
  final ValueChanged<String> onLectureSubFilterChanged;
  final ValueChanged<String> onStatusFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final VoidCallback onResetAllFilters;
  final Future<void> Function() onRefresh;
  final void Function(ExamEntity exam) onOpenExamDetails;
  final TeacherGroupFilterBar groupFilterBar;

  const TeacherExamsLoadedView({
    super.key,
    required this.state,
    required this.scrollController,
    required this.selectedGroupId,
    required this.activeTypeFilter,
    required this.activeLectureSubFilter,
    required this.activeStatusFilter,
    required this.searchQuery,
    required this.searchController,
    required this.onTypeFilterChanged,
    required this.onLectureSubFilterChanged,
    required this.onStatusFilterChanged,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onResetAllFilters,
    required this.onRefresh,
    required this.onOpenExamDetails,
    required this.groupFilterBar,
  });

  @override
  Widget build(BuildContext context) {
    final allExams = state.exams;
    final cubit = context.read<ExamsCubit>();

    // Categorized Counts
    final generalCount = allExams.where((e) => e.isGeneralExam).length;
    final lectureCount = allExams.where((e) => e.isLectureExam).length;
    final linkedLectureCount =
        allExams.where((e) => e.isLectureExam && e.isLinkedToLesson).length;
    final unlinkedLectureCount =
        allExams.where((e) => e.isLectureExam && !e.isLinkedToLesson).length;
    final publishedCount = allExams.where((e) => e.isPublished).length;
    final draftCount = allExams.where((e) => !e.isPublished).length;

    // Multi-dimensional Filtering
    var filteredExams = state.filteredExams;

    if (activeTypeFilter == 'general') {
      filteredExams = filteredExams.where((e) => e.isGeneralExam).toList();
    } else if (activeTypeFilter == 'lecture') {
      filteredExams = filteredExams.where((e) => e.isLectureExam).toList();
      if (activeLectureSubFilter == 'linked') {
        filteredExams =
            filteredExams.where((e) => e.isLinkedToLesson).toList();
      } else if (activeLectureSubFilter == 'unlinked') {
        filteredExams =
            filteredExams.where((e) => !e.isLinkedToLesson).toList();
      }
    }

    if (activeStatusFilter == 'published') {
      filteredExams = filteredExams.where((e) => e.isPublished).toList();
    } else if (activeStatusFilter == 'draft') {
      filteredExams = filteredExams.where((e) => !e.isPublished).toList();
    }

    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filteredExams = filteredExams.where((e) {
        final titleMatch = e.title.toLowerCase().contains(q);
        final lessonMatch =
            (e.linkedLessonTitle ?? '').toLowerCase().contains(q);
        return titleMatch || lessonMatch;
      }).toList();
    }

    final hasActiveFilters = searchQuery.isNotEmpty ||
        activeStatusFilter != 'all' ||
        activeTypeFilter != 'all' ||
        activeLectureSubFilter != 'all' ||
        state.selectedFolderId != null;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            groupFilterBar,
            const SizedBox(height: AppSpacing.s16),

            // 1. Stats Banner
            TeacherExamsStatsBanner(
              totalCount: allExams.length,
              generalCount: generalCount,
              lectureCount: lectureCount,
              unlinkedLectureCount: unlinkedLectureCount,
              activeTypeFilter: activeTypeFilter,
              onSelectFilter: (filter) {
                onTypeFilterChanged(filter);
                onLectureSubFilterChanged('all');
              },
              onAlertTap: unlinkedLectureCount > 0
                  ? () {
                      onTypeFilterChanged('lecture');
                      onLectureSubFilterChanged('unlinked');
                    }
                  : null,
            ),
            const SizedBox(height: AppSpacing.s12),

            // 2. Exam Folders Bar
            ExamFoldersBar(
              folders: state.folders,
              selectedFolderId: state.selectedFolderId,
              totalExamsCount: allExams.length,
              uncategorizedCount: allExams
                  .where((e) => e.folderId == null || e.folderId!.isEmpty)
                  .length,
              onSelectFolder: (fId) => cubit.selectFolder(fId),
              onCreateFolder: () =>
                  TeacherExamsActionsCoordinator.showCreateFolderDialog(
                context: context,
                cubit: cubit,
                selectedGroupId: selectedGroupId,
              ),
              onEditFolder: (f) =>
                  TeacherExamsActionsCoordinator.showEditFolderDialog(
                context: context,
                folder: f,
                cubit: cubit,
              ),
              onDeleteFolder: (f) =>
                  TeacherExamsActionsCoordinator.confirmDeleteFolder(
                context: context,
                folder: f,
                cubit: cubit,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // 3. Filter Bar
            TeacherExamsFilterBar(
              totalCount: allExams.length,
              generalCount: generalCount,
              lectureCount: lectureCount,
              linkedLectureCount: linkedLectureCount,
              unlinkedLectureCount: unlinkedLectureCount,
              publishedCount: publishedCount,
              draftCount: draftCount,
              activeTypeFilter: activeTypeFilter,
              activeLectureSubFilter: activeLectureSubFilter,
              activeStatusFilter: activeStatusFilter,
              searchQuery: searchQuery,
              hasActiveFilters: hasActiveFilters,
              searchController: searchController,
              onTypeFilterChanged: onTypeFilterChanged,
              onLectureSubFilterChanged: onLectureSubFilterChanged,
              onStatusFilterChanged: onStatusFilterChanged,
              onSearchChanged: onSearchChanged,
              onClearSearch: onClearSearch,
              onResetAllFilters: onResetAllFilters,
            ),
            const SizedBox(height: AppSpacing.s16),

            // 4. Exams Grid
            TeacherExamsGridView(
              filteredExams: filteredExams,
              selectedFolderId: state.selectedFolderId,
              isLoadingMore: state.isLoadingMore,
              onClearFilters: () {
                cubit.selectFolder(null);
                onResetAllFilters();
              },
              onTapExam: onOpenExamDetails,
              onEditQuestions: (exam) =>
                  TeacherExamsActionsCoordinator.openEditDraftExam(
                context: context,
                exam: exam,
                cubit: cubit,
                selectedGroupId: selectedGroupId,
                onReload: () => onRefresh(),
              ),
              onLinkLecture: (exam) {
                if (selectedGroupId != null) {
                  TeacherExamsActionsCoordinator.showLinkExamDialog(
                    context: context,
                    exam: exam,
                    groupId: selectedGroupId!,
                    cubit: cubit,
                  );
                }
              },
              onUnlinkLecture: (exam) {
                if (selectedGroupId != null) {
                  TeacherExamsActionsCoordinator.confirmUnlinkExam(
                    context: context,
                    exam: exam,
                    groupId: selectedGroupId!,
                    cubit: cubit,
                  );
                }
              },
              onConvertToLecture: (exam) {
                if (selectedGroupId != null) {
                  TeacherExamsActionsCoordinator.convertToLectureExam(
                    context: context,
                    exam: exam,
                    groupId: selectedGroupId!,
                    cubit: cubit,
                  );
                }
              },
              onConvertToGeneral: (exam) {
                if (selectedGroupId != null) {
                  TeacherExamsActionsCoordinator.confirmUnlinkExam(
                    context: context,
                    exam: exam,
                    groupId: selectedGroupId!,
                    cubit: cubit,
                  );
                }
              },
              onPublish: (exam) => TeacherExamsActionsCoordinator.publishExam(
                context: context,
                exam: exam,
                cubit: cubit,
              ),
              onUnpublish: (exam) =>
                  TeacherExamsActionsCoordinator.confirmUnpublish(
                context: context,
                exam: exam,
                cubit: cubit,
              ),
              onDelete: (exam) =>
                  TeacherExamsActionsCoordinator.handleDeleteExam(
                context: context,
                exam: exam,
                cubit: cubit,
              ),
              onDispatchResults: (exam) =>
                  TeacherExamsActionsCoordinator.openParentDispatch(
                context: context,
                exam: exam,
              ),
              onMoveToFolder: (exam) =>
                  TeacherExamsActionsCoordinator.showMoveExamFolderDialog(
                context: context,
                exam: exam,
                cubit: cubit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
