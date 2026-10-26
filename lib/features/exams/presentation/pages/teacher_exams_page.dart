import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../pages/create_exam_page.dart';
import '../utils/teacher_exams_actions_coordinator.dart';
import '../widgets/exam_folders_bar.dart';
import '../widgets/teacher_exams_filter_bar.dart';
import '../widgets/teacher_exams_grid_view.dart';
import '../widgets/teacher_exams_stats_banner.dart';

class TeacherExamsPage extends StatefulWidget {
  final String? groupId;
  final String? groupName;
  final String? initialExamId;

  const TeacherExamsPage({
    super.key,
    this.groupId,
    this.groupName,
    this.initialExamId,
  });

  @override
  State<TeacherExamsPage> createState() => _TeacherExamsPageState();
}

class _TeacherExamsPageState extends State<TeacherExamsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _activeStatusFilter = 'all'; // 'all', 'published', 'draft'
  String _activeTypeFilter = 'all'; // 'all', 'general', 'lecture'
  String _activeLectureSubFilter = 'all'; // 'all', 'linked', 'unlinked'
  String? _selectedGroupId;
  String? _selectedGroupName;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final initialId =
        widget.groupId ?? TeacherGroupFilterBar.lastSelectedGroupId;
    GroupsState? groupsState;
    try {
      groupsState = context.read<GroupsCubit>().state;
    } catch (_) {}
    if (initialId != null) {
      _selectedGroupId = initialId;
      _selectedGroupName = widget.groupName;
      if (_selectedGroupName == null && groupsState is GroupsLoaded) {
        _selectedGroupName = groupsState.groups
            .where((g) => g.id == initialId)
            .firstOrNull
            ?.name;
      }
    } else if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
      _selectedGroupId = groupsState.groups.first.id;
      _selectedGroupName = groupsState.groups.first.name;
    }

    if (_selectedGroupId != null) {
      _loadExams().then((_) {
        if (!mounted || widget.initialExamId == null) return;
        final state = context.read<ExamsCubit>().state;
        if (state is TeacherExamsLoaded) {
          try {
            final exam = state.exams.firstWhere(
              (e) => e.id == widget.initialExamId,
            );
            if (mounted) _openExamDetails(exam);
          } catch (_) {}
        }
      });
    }
    try {
      if (mounted) context.read<GroupsCubit>().loadGroups();
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<ExamsCubit>().loadMoreTeacherExams();
    }
  }

  void _onGroupChanged(GroupEntity group) {
    if (!mounted || _selectedGroupId == group.id) return;
    TeacherGroupFilterBar.lastSelectedGroupId = group.id;
    setState(() {
      _selectedGroupId = group.id;
      _selectedGroupName = group.name;
    });
    _loadExams();
  }

  void _openExamDetails(ExamEntity exam) {
    if (!mounted) return;
    TeacherExamsActionsCoordinator.showExamDetailsSheet(
      context: context,
      exam: exam,
      cubit: context.read<ExamsCubit>(),
      selectedGroupId: _selectedGroupId,
      onReload: () => _loadExams(forceRefresh: true),
    );
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (!mounted || _selectedGroupId == null) return;
    await context.read<ExamsCubit>().loadGroupExams(
          _selectedGroupId!,
          forceRefresh: forceRefresh,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backTooltip,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.teacherDashboard),
        ),
        title: Text(
          _selectedGroupName != null
              ? context.l10n.groupExamsTitle(_selectedGroupName!)
              : context.l10n.teacherExamsTitle,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refreshTooltip,
            onPressed: () => _loadExams(forceRefresh: true),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context)
              .push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider.value(
                    value: context.read<ExamsCubit>(),
                    child: CreateExamPage(
                      groupId: _selectedGroupId,
                      groupName: _selectedGroupName,
                    ),
                  ),
                ),
              )
              .then((_) {
                if (context.mounted) {
                  _loadExams(forceRefresh: true);
                }
              });
        },
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          context.l10n.buildExamAction,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: _buildBodyContent(context),
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    GroupsCubit? groupsCubit;
    try {
      groupsCubit = context.read<GroupsCubit>();
    } catch (_) {
      groupsCubit = null;
    }

    Widget bodyContent = BlocBuilder<ExamsCubit, ExamsState>(
      builder: (context, state) {
        final groupFilterBar = TeacherGroupFilterBar(
          selectedGroupId: _selectedGroupId,
          onGroupChanged: _onGroupChanged,
          onRefresh: () => _loadExams(forceRefresh: true),
        );

        if (state is ExamsLoading) {
          return Column(
            children: [
              groupFilterBar,
              const SizedBox(height: AppSpacing.s16),
              const Expanded(
                child: AppLoadingView.cardsGrid(count: 4, columns: 2),
              ),
            ],
          );
        }

        if (state is ExamsError) {
          return Column(
            children: [
              groupFilterBar,
              const SizedBox(height: AppSpacing.s16),
              Expanded(
                child: Center(
                  child: AppErrorView(
                    message: state.message,
                    onRetry: () => _loadExams(forceRefresh: true),
                  ),
                ),
              ),
            ],
          );
        }

        if (state is TeacherExamsLoaded) {
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

          if (_activeTypeFilter == 'general') {
            filteredExams = filteredExams.where((e) => e.isGeneralExam).toList();
          } else if (_activeTypeFilter == 'lecture') {
            filteredExams = filteredExams.where((e) => e.isLectureExam).toList();
            if (_activeLectureSubFilter == 'linked') {
              filteredExams =
                  filteredExams.where((e) => e.isLinkedToLesson).toList();
            } else if (_activeLectureSubFilter == 'unlinked') {
              filteredExams =
                  filteredExams.where((e) => !e.isLinkedToLesson).toList();
            }
          }

          if (_activeStatusFilter == 'published') {
            filteredExams =
                filteredExams.where((e) => e.isPublished).toList();
          } else if (_activeStatusFilter == 'draft') {
            filteredExams =
                filteredExams.where((e) => !e.isPublished).toList();
          }

          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            filteredExams = filteredExams.where((e) {
              final titleMatch = e.title.toLowerCase().contains(q);
              final lessonMatch =
                  (e.linkedLessonTitle ?? '').toLowerCase().contains(q);
              return titleMatch || lessonMatch;
            }).toList();
          }

          final hasActiveFilters = _searchQuery.isNotEmpty ||
              _activeStatusFilter != 'all' ||
              _activeTypeFilter != 'all' ||
              _activeLectureSubFilter != 'all' ||
              state.selectedFolderId != null;

          if (allExams.isEmpty) {
            return Column(
              children: [
                groupFilterBar,
                const SizedBox(height: AppSpacing.s16),
                Expanded(
                  child: Center(
                    child: AppEmptyView(
                      message: context.l10n.noExamsForGroup,
                      subtitle: context.l10n.noExamsForGroupSubtitle,
                      actionText: context.l10n.buildFirstExam,
                      onAction: () {
                        Navigator.of(context)
                            .push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<ExamsCubit>(),
                                  child: CreateExamPage(
                                    groupId: _selectedGroupId,
                                    groupName: _selectedGroupName,
                                  ),
                                ),
                              ),
                            )
                            .then((_) {
                              if (context.mounted) {
                                _loadExams(forceRefresh: true);
                              }
                            });
                      },
                      icon: Icons.quiz_outlined,
                    ),
                  ),
                ),
              ],
            );
          }

          return RefreshIndicator(
            onRefresh: () => _loadExams(forceRefresh: true),
            child: SingleChildScrollView(
              controller: _scrollController,
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
                    activeTypeFilter: _activeTypeFilter,
                    onSelectFilter: (filter) {
                      setState(() {
                        _activeTypeFilter = filter;
                        _activeLectureSubFilter = 'all';
                      });
                    },
                    onAlertTap: unlinkedLectureCount > 0
                        ? () {
                            setState(() {
                              _activeTypeFilter = 'lecture';
                              _activeLectureSubFilter = 'unlinked';
                            });
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
                    onSelectFolder: (fId) =>
                        cubit.selectFolder(fId),
                    onCreateFolder: () =>
                        TeacherExamsActionsCoordinator.showCreateFolderDialog(
                      context: context,
                      cubit: cubit,
                      selectedGroupId: _selectedGroupId,
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
                    activeTypeFilter: _activeTypeFilter,
                    activeLectureSubFilter: _activeLectureSubFilter,
                    activeStatusFilter: _activeStatusFilter,
                    searchQuery: _searchQuery,
                    hasActiveFilters: hasActiveFilters,
                    searchController: _searchController,
                    onTypeFilterChanged: (filter) {
                      setState(() {
                        _activeTypeFilter = filter;
                        _activeLectureSubFilter = 'all';
                      });
                    },
                    onLectureSubFilterChanged: (subFilter) {
                      setState(() {
                        _activeLectureSubFilter = subFilter;
                      });
                    },
                    onStatusFilterChanged: (status) {
                      setState(() {
                        _activeStatusFilter = status;
                      });
                    },
                    onSearchChanged: (query) {
                      setState(() {
                        _searchQuery = query;
                      });
                    },
                    onClearSearch: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                    onResetAllFilters: () {
                      _searchController.clear();
                      setState(() {
                        _activeStatusFilter = 'all';
                        _activeTypeFilter = 'all';
                        _activeLectureSubFilter = 'all';
                        _searchQuery = '';
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // 4. Exams Grid
                  TeacherExamsGridView(
                    filteredExams: filteredExams,
                    selectedFolderId: state.selectedFolderId,
                    isLoadingMore: state.isLoadingMore,
                    onClearFilters: () {
                      cubit.selectFolder(null);
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _activeStatusFilter = 'all';
                        _activeTypeFilter = 'all';
                        _activeLectureSubFilter = 'all';
                      });
                    },
                    onTapExam: (exam) => _openExamDetails(exam),
                    onEditQuestions: (exam) =>
                        TeacherExamsActionsCoordinator.openEditDraftExam(
                      context: context,
                      exam: exam,
                      cubit: cubit,
                      selectedGroupId: _selectedGroupId,
                      onReload: () => _loadExams(forceRefresh: true),
                    ),
                    onLinkLecture: (exam) {
                      if (_selectedGroupId != null) {
                        TeacherExamsActionsCoordinator.showLinkExamDialog(
                          context: context,
                          exam: exam,
                          groupId: _selectedGroupId!,
                          cubit: cubit,
                        );
                      }
                    },
                    onUnlinkLecture: (exam) {
                      if (_selectedGroupId != null) {
                        TeacherExamsActionsCoordinator.confirmUnlinkExam(
                          context: context,
                          exam: exam,
                          groupId: _selectedGroupId!,
                          cubit: cubit,
                        );
                      }
                    },
                    onConvertToLecture: (exam) {
                      if (_selectedGroupId != null) {
                        TeacherExamsActionsCoordinator.convertToLectureExam(
                          context: context,
                          exam: exam,
                          groupId: _selectedGroupId!,
                          cubit: cubit,
                        );
                      }
                    },
                    onConvertToGeneral: (exam) {
                      if (_selectedGroupId != null) {
                        TeacherExamsActionsCoordinator.confirmUnlinkExam(
                          context: context,
                          exam: exam,
                          groupId: _selectedGroupId!,
                          cubit: cubit,
                        );
                      }
                    },
                    onPublish: (exam) =>
                        TeacherExamsActionsCoordinator.publishExam(
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

        return Column(
          children: [
            groupFilterBar,
            const SizedBox(height: AppSpacing.s16),
            const Expanded(
              child: AppLoadingView.cardsGrid(count: 4, columns: 2),
            ),
          ],
        );
      },
    );

    if (groupsCubit != null) {
      bodyContent = BlocListener<GroupsCubit, GroupsState>(
        bloc: groupsCubit,
        listenWhen: (prev, curr) => mounted,
        listener: (context, groupsState) {
          if (!mounted) return;
          if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
            if (_selectedGroupId == null ||
                !groupsState.groups.any((g) => g.id == _selectedGroupId)) {
              final targetGroup = (widget.groupId != null &&
                      groupsState.groups.any((g) => g.id == widget.groupId))
                  ? groupsState.groups.firstWhere((g) => g.id == widget.groupId)
                  : groupsState.groups.first;
              TeacherGroupFilterBar.lastSelectedGroupId = targetGroup.id;
              if (!mounted) return;
              setState(() {
                _selectedGroupId = targetGroup.id;
                _selectedGroupName = targetGroup.name;
              });
              _loadExams();
            }
          }
        },
        child: bodyContent,
      );
    }

    return bodyContent;
  }
}
