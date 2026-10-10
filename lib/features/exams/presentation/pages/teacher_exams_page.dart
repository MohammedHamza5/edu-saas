import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../widgets/edit_exam_dialog.dart';
import '../widgets/exam_card.dart';
import 'create_exam_page.dart';

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
    _showExamDetailsSheet(exam);
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (!mounted || _selectedGroupId == null) return;
    await context.read<ExamsCubit>().loadGroupExams(
      _selectedGroupId!,
      forceRefresh: forceRefresh,
    );
  }

  // ── Actions: Link, Unlink, Convert ─────────────────────────────────────────

  void _showLinkExamDialog(ExamEntity exam) {
    if (_selectedGroupId == null) return;
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
        return _LinkExamToLectureSheet(
          exam: exam,
          groupId: _selectedGroupId!,
          cubit: context.read<ExamsCubit>(),
        );
      },
    );
  }

  Future<void> _confirmUnlinkExam(ExamEntity exam) async {
    if (_selectedGroupId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmUnlinkDialogTitle),
        content: Text(context.l10n.confirmUnlinkDialogBody(exam.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.confirmUnlinkButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await context.read<ExamsCubit>().unlinkExamFromLesson(
        examId: exam.id,
        groupId: _selectedGroupId!,
        makeGeneralExam: true,
      );
      if (mounted && success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(context.l10n.examUnlinkedSuccessToast),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _convertToLectureExam(ExamEntity exam) async {
    if (_selectedGroupId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final success = await context.read<ExamsCubit>().convertExamType(
      examId: exam.id,
      contentId: exam.contentId,
      toLectureExam: true,
      groupId: _selectedGroupId!,
    );
    if (mounted && success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.l10n.examConvertedToLectureSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      _showLinkExamDialog(exam);
    }
  }

  Future<void> _publishExam(ExamEntity exam) async {
    if (exam.activeVersion == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final publishedSuccessMsg = context.l10n.versionPublishedSuccess;
    final success = await context.read<ExamsCubit>().publishVersion(
      exam.activeVersion!.id,
      exam.id,
    );
    if (mounted && success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(publishedSuccessMsg),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _confirmUnpublish(BuildContext context, ExamEntity exam) async {
    if (exam.activeVersion == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final successMsg = context.l10n.examUnpublishedSuccess;
    final cubit = context.read<ExamsCubit>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.visibility_off_outlined,
              color: AppColors.warning,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(ctx.l10n.confirmUnpublishExamTitle),
            ),
          ],
        ),
        content: Text(ctx.l10n.confirmUnpublishExamBody(exam.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.confirmUnpublishButton),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await cubit.unpublishVersion(
        examId: exam.id,
        versionId: exam.activeVersion!.id,
      );
      if (mounted && success) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteExam(ExamEntity exam) async {
    final hasAttempts = exam.attemptsCount > 0;
    final title = hasAttempts
        ? context.l10n.archiveOrDeleteExamDialogTitle
        : context.l10n.deleteExamDialogTitle;
    final body = hasAttempts
        ? context.l10n.archiveOrDeleteExamDialogBody(
            exam.title,
            exam.attemptsCount,
          )
        : context.l10n.deleteExamDialogBody(exam.title);
    final confirmBtnText = hasAttempts
        ? context.l10n.archiveExamConfirmButton
        : context.l10n.deleteExamConfirmButton;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              hasAttempts ? Icons.archive_outlined : Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 24,
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmBtnText),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final success = await context.read<ExamsCubit>().deleteExam(
            examId: exam.id,
          );
      if (mounted) {
        if (success) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                hasAttempts
                    ? context.l10n.examArchivedSuccessToast
                    : context.l10n.examDeletedSuccessToast,
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          final state = context.read<ExamsCubit>().state;
          final errorMsg = (state is TeacherExamsLoaded && state.message != null)
              ? state.message!
              : (state is ExamsError ? state.message : context.l10n.errorOccurred);
          messenger.showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _openEditDraftExam(ExamEntity exam) async {
    if (exam.attemptsCount > 0 && exam.isPublished) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.cannotEditPublishedExamWithAttempts),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final cubit = context.read<ExamsCubit>();

    ExamEntity examToEdit = exam;
    if (exam.activeVersion == null || exam.activeVersion!.questions.isEmpty) {
      final fullExam = await cubit.getExamDetails(exam.id);
      if (fullExam != null) {
        examToEdit = fullExam;
      }
    }

    if (!mounted) return;

    final updated = await Navigator.of(context).push<ExamEntity?>(
      MaterialPageRoute<ExamEntity?>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: CreateExamPage(
            groupId: examToEdit.groupId.isNotEmpty
                ? examToEdit.groupId
                : _selectedGroupId,
            groupName: examToEdit.groupName,
            initialTitle: examToEdit.title,
            existingExam: examToEdit,
          ),
        ),
      ),
    );

    if (mounted && updated != null) {
      await _loadExams(forceRefresh: true);
    }
  }

  void _openParentDispatch(ExamEntity exam) {
    context.push(
      '/teacher/exams/${exam.id}/parent-dispatch?title=${Uri.encodeComponent(exam.title)}',
    );
  }

  void _showExamDetailsSheet(ExamEntity exam) {
    final cubit = context.read<ExamsCubit>();
    cubit.selectExamForTeacher(exam);

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
          child: _ExamDetailsSheetContent(
            exam: exam,
            cubit: cubit,
            onLinkLecture: () {
              Navigator.of(sheetContext).pop();
              _showLinkExamDialog(exam);
            },
            onUnlinkLecture: () {
              Navigator.of(sheetContext).pop();
              _confirmUnlinkExam(exam);
            },
            onDeleteExam: () {
              Navigator.of(sheetContext).pop();
              _handleDeleteExam(exam);
            },
            onEditQuestions: () {
              Navigator.of(sheetContext).pop();
              _openEditDraftExam(exam);
            },
          ),
        );
      },
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
      body: Center(
        child: ResponsiveContainer(
          maxWidth: ResponsiveBreakpoints.maxContentWidth,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: _buildBodyContent(context),
        ),
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
          var filteredExams = allExams;

          // 1. Type filter
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

          // 2. Status filter
          if (_activeStatusFilter == 'published') {
            filteredExams =
                filteredExams.where((e) => e.isPublished).toList();
          } else if (_activeStatusFilter == 'draft') {
            filteredExams =
                filteredExams.where((e) => !e.isPublished).toList();
          }

          // 3. Search filter
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
              _activeLectureSubFilter != 'all';

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

                  // ── 1. Mathematical Stats Summary Banner ─────────────────
                  _buildStatsBanner(
                    context: context,
                    totalCount: allExams.length,
                    generalCount: generalCount,
                    lectureCount: lectureCount,
                    unlinkedLectureCount: unlinkedLectureCount,
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── 2. Primary Type Filter Tabs ──────────────────────────
                  _buildTypeFilterTabs(
                    context: context,
                    totalCount: allExams.length,
                    generalCount: generalCount,
                    lectureCount: lectureCount,
                  ),
                  const SizedBox(height: AppSpacing.s8),

                  // ── 3. Lecture Quizzes Sub-filters (when lecture tab is active)
                  if (_activeTypeFilter == 'lecture') ...[
                    _buildLectureSubFilters(
                      context: context,
                      totalCount: lectureCount,
                      linkedCount: linkedLectureCount,
                      unlinkedCount: unlinkedLectureCount,
                    ),
                    const SizedBox(height: AppSpacing.s8),
                  ],

                  // ── 4. Search Bar & Status Chips ─────────────────────────
                  _buildSearchAndStatusFilters(
                    context: context,
                    totalCount: allExams.length,
                    publishedCount: publishedCount,
                    draftCount: draftCount,
                    hasActiveFilters: hasActiveFilters,
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── 5. Exams Grid or Empty State ─────────────────────────
                  if (filteredExams.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: AppEmptyView(
                          icon: Icons.search_off_rounded,
                          message: context.l10n.noMatchingExamsFound,
                          actionText: context.l10n.clearSearchAction,
                          onAction: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                              _activeStatusFilter = 'all';
                              _activeTypeFilter = 'all';
                              _activeLectureSubFilter = 'all';
                            });
                          },
                        ),
                      ),
                    )
                  else
                    ResponsiveGrid(
                      mobileColumns: 1,
                      tabletColumns: 2,
                      desktopColumns: 2,
                      spacing: AppSpacing.s16,
                      runSpacing: AppSpacing.s16,
                      children: filteredExams.map((exam) {
                        return ExamCard(
                          exam: exam,
                          isTeacher: true,
                          onTap: () => _showExamDetailsSheet(exam),
                          onEdit: () => EditExamDialog.show(context, exam),
                          onEditQuestions: () => _openEditDraftExam(exam),
                          onLinkLecture: () => _showLinkExamDialog(exam),
                          onUnlinkLecture: () => _confirmUnlinkExam(exam),
                          onConvertToLecture: () => _convertToLectureExam(exam),
                          onConvertToGeneral: () => _confirmUnlinkExam(exam),
                          onPublish: () => _publishExam(exam),
                          onUnpublish: () => _confirmUnpublish(context, exam),
                          onDelete: () => _handleDeleteExam(exam),
                          onDispatchResults: () => _openParentDispatch(exam),
                        );
                      }).toList(),
                    ),

                  if (state.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                      child: Center(
                        child: AppLoadingView.compact(size: 24),
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

  // ── Stat Banner Widget ─────────────────────────────────────────────────────

  Widget _buildStatsBanner({
    required BuildContext context,
    required int totalCount,
    required int generalCount,
    required int lectureCount,
    required int unlinkedLectureCount,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        final cards = [
          _buildStatCard(
            title: context.l10n.statTotalExamsTitle,
            count: totalCount,
            subtitle: context.l10n.statTotalExamsDesc,
            color: AppColors.primary,
            icon: Icons.quiz_rounded,
            isSelected: _activeTypeFilter == 'all',
            onTap: () {
              setState(() {
                _activeTypeFilter = 'all';
                _activeLectureSubFilter = 'all';
              });
            },
          ),
          _buildStatCard(
            title: context.l10n.statGeneralExamsTitle,
            count: generalCount,
            subtitle: context.l10n.statGeneralExamsDesc,
            color: const Color(0xFF7C3AED),
            icon: Icons.assignment_rounded,
            isSelected: _activeTypeFilter == 'general',
            onTap: () {
              setState(() {
                _activeTypeFilter = 'general';
                _activeLectureSubFilter = 'all';
              });
            },
          ),
          _buildStatCard(
            title: context.l10n.statLectureQuizzesTitle,
            count: lectureCount,
            subtitle: context.l10n.statLectureQuizzesDesc,
            color: const Color(0xFF0284C7),
            icon: Icons.menu_book_rounded,
            alertText: unlinkedLectureCount > 0
                ? context.l10n.statUnlinkedAlert(unlinkedLectureCount)
                : null,
            isSelected: _activeTypeFilter == 'lecture',
            onTap: () {
              setState(() {
                _activeTypeFilter = 'lecture';
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
        ];

        if (isCompact) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i < cards.length - 1) const SizedBox(height: AppSpacing.s8),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: AppSpacing.s12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String title,
    required int count,
    required String subtitle,
    required Color color,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? alertText,
    VoidCallback? onAlertTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(AppSpacing.s14),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.08)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: isSelected ? color : AppColors.border,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: color,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (alertText != null) ...[
                const SizedBox(height: AppSpacing.s8),
                InkWell(
                  onTap: onAlertTap,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          alertText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Primary Type Filter Tabs ───────────────────────────────────────────────

  Widget _buildTypeFilterTabs({
    required BuildContext context,
    required int totalCount,
    required int generalCount,
    required int lectureCount,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTypePill(
              title: context.l10n.examFilterTabAll(totalCount),
              isSelected: _activeTypeFilter == 'all',
              accentColor: AppColors.primary,
              icon: Icons.all_inclusive_rounded,
              onTap: () {
                setState(() {
                  _activeTypeFilter = 'all';
                  _activeLectureSubFilter = 'all';
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTypePill(
              title: context.l10n.examFilterTabGeneral(generalCount),
              isSelected: _activeTypeFilter == 'general',
              accentColor: const Color(0xFF7C3AED),
              icon: Icons.assignment_rounded,
              onTap: () {
                setState(() {
                  _activeTypeFilter = 'general';
                  _activeLectureSubFilter = 'all';
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTypePill(
              title: context.l10n.examFilterTabLectureQuizzes(lectureCount),
              isSelected: _activeTypeFilter == 'lecture',
              accentColor: const Color(0xFF0284C7),
              icon: Icons.menu_book_rounded,
              onTap: () {
                setState(() {
                  _activeTypeFilter = 'lecture';
                  _activeLectureSubFilter = 'all';
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill({
    required String title,
    required bool isSelected,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Lecture Sub-filters ────────────────────────────────────────────────────

  Widget _buildLectureSubFilters({
    required BuildContext context,
    required int totalCount,
    required int linkedCount,
    required int unlinkedCount,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.l10n.examFilterSubAll),
            selected: _activeLectureSubFilter == 'all',
            onSelected: (_) => setState(() => _activeLectureSubFilter = 'all'),
            selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.2),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: _activeLectureSubFilter == 'all'
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _activeLectureSubFilter == 'all'
                  ? const Color(0xFF0284C7)
                  : AppColors.textPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _activeLectureSubFilter == 'all'
                    ? const Color(0xFF0284C7)
                    : AppColors.border,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          ChoiceChip(
            avatar: const Icon(
              Icons.link_rounded,
              size: 14,
              color: AppColors.success,
            ),
            label: Text(context.l10n.examFilterSubLinked(linkedCount)),
            selected: _activeLectureSubFilter == 'linked',
            onSelected: (_) =>
                setState(() => _activeLectureSubFilter = 'linked'),
            selectedColor: AppColors.success.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: _activeLectureSubFilter == 'linked'
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _activeLectureSubFilter == 'linked'
                  ? AppColors.success
                  : AppColors.textPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _activeLectureSubFilter == 'linked'
                    ? AppColors.success
                    : AppColors.border,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s8),
          ChoiceChip(
            avatar: const Icon(
              Icons.link_off_rounded,
              size: 14,
              color: AppColors.warning,
            ),
            label: Text(context.l10n.examFilterSubUnlinked(unlinkedCount)),
            selected: _activeLectureSubFilter == 'unlinked',
            onSelected: (_) =>
                setState(() => _activeLectureSubFilter = 'unlinked'),
            selectedColor: AppColors.warning.withValues(alpha: 0.2),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: _activeLectureSubFilter == 'unlinked'
                  ? FontWeight.bold
                  : FontWeight.normal,
              color: _activeLectureSubFilter == 'unlinked'
                  ? AppColors.warning
                  : AppColors.textPrimary,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: _activeLectureSubFilter == 'unlinked'
                    ? AppColors.warning
                    : AppColors.border,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Search & Status Filter Row ─────────────────────────────────────────────

  Widget _buildSearchAndStatusFilters({
    required BuildContext context,
    required int totalCount,
    required int publishedCount,
    required int draftCount,
    required bool hasActiveFilters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _searchController,
          hintText: context.l10n.searchExamsHint,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textSecondary,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  tooltip: context.l10n.clearSearchAction,
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          onChanged: (val) {
            setState(() => _searchQuery = val.trim());
          },
        ),
        const SizedBox(height: AppSpacing.s8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(context.l10n.filterAllExams(totalCount)),
                selected: _activeStatusFilter == 'all',
                onSelected: (_) =>
                    setState(() => _activeStatusFilter = 'all'),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: _activeStatusFilter == 'all'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _activeStatusFilter == 'all'
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _activeStatusFilter == 'all'
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilterChip(
                avatar: Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: _activeStatusFilter == 'published'
                      ? Colors.white
                      : AppColors.success,
                ),
                label: Text(context.l10n.filterPublishedExams(publishedCount)),
                selected: _activeStatusFilter == 'published',
                onSelected: (_) =>
                    setState(() => _activeStatusFilter = 'published'),
                selectedColor: AppColors.success,
                backgroundColor: AppColors.surfaceVariant,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: _activeStatusFilter == 'published'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _activeStatusFilter == 'published'
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _activeStatusFilter == 'published'
                        ? AppColors.success
                        : AppColors.border,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilterChip(
                avatar: Icon(
                  Icons.edit_note_rounded,
                  size: 16,
                  color: _activeStatusFilter == 'draft'
                      ? Colors.white
                      : AppColors.warning,
                ),
                label: Text(context.l10n.filterDraftExams(draftCount)),
                selected: _activeStatusFilter == 'draft',
                onSelected: (_) =>
                    setState(() => _activeStatusFilter = 'draft'),
                selectedColor: AppColors.warning,
                backgroundColor: AppColors.surfaceVariant,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: _activeStatusFilter == 'draft'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _activeStatusFilter == 'draft'
                      ? Colors.white
                      : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: _activeStatusFilter == 'draft'
                        ? AppColors.warning
                        : AppColors.border,
                  ),
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: AppSpacing.s8),
                ActionChip(
                  avatar: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: AppColors.error,
                  ),
                  label: Text(
                    context.l10n.clearSearchAction,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: AppColors.error.withValues(alpha: 0.08),
                  side: BorderSide(
                    color: AppColors.error.withValues(alpha: 0.25),
                  ),
                  onPressed: () {
                    setState(() {
                      _activeStatusFilter = 'all';
                      _activeTypeFilter = 'all';
                      _activeLectureSubFilter = 'all';
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LINK EXAM TO LECTURE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _LinkExamToLectureSheet extends StatefulWidget {
  final ExamEntity exam;
  final String groupId;
  final ExamsCubit cubit;

  const _LinkExamToLectureSheet({
    required this.exam,
    required this.groupId,
    required this.cubit,
  });

  @override
  State<_LinkExamToLectureSheet> createState() =>
      _LinkExamToLectureSheetState();
}

class _LinkExamToLectureSheetState extends State<_LinkExamToLectureSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _lessons = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _selectedLessonId;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _selectedLessonId = widget.exam.linkedLessonId;
    _fetchLessons();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchLessons() async {
    final list = await widget.cubit.getGroupLessons(widget.groupId);
    if (!mounted) return;
    setState(() {
      _lessons = list;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _lessons.where((l) {
      if (_search.isEmpty) return true;
      final t = (l['title'] as String? ?? '').toLowerCase();
      return t.contains(_search.toLowerCase());
    }).toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.82,
        ),
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
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
            const SizedBox(height: AppSpacing.s16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: Color(0xFF0284C7),
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.linkExamToLectureDialogTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.exam.title,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.l10n.linkExamToLectureDialogSubtitle,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Search input
            AppTextField(
              controller: _searchCtrl,
              hintText: context.l10n.searchLecturesHint,
              prefixIcon: const Icon(Icons.search, size: 18),
              onChanged: (val) => setState(() => _search = val.trim()),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Lessons List
            Expanded(
              child: _isLoading
                  ? const AppLoadingView.list(count: 4)
                  : filtered.isEmpty
                      ? Center(
                          child: Text(
                            context.l10n.noLecturesFound,
                            style: const TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.s8),
                          itemBuilder: (context, idx) {
                            final lesson = filtered[idx];
                            final id = lesson['id'] as String;
                            final title = lesson['title'] as String? ?? '';
                            final sortOrder = lesson['sort_order'];
                            final attachedExamId =
                                lesson['associated_exam_id'] as String?;
                            final attachedExamTitle =
                                lesson['exam_title'] as String? ?? '';
                            final isCurrentExamAttached =
                                attachedExamId == widget.exam.id;
                            final isSelected = _selectedLessonId == id;
                            final isAttachedToOther =
                                attachedExamId != null && !isCurrentExamAttached;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedLessonId = id;
                                });
                              },
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF0284C7)
                                          .withValues(alpha: 0.08)
                                      : AppColors.surface,
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium,
                                  ),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF0284C7)
                                        : AppColors.border,
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isSelected
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: isSelected
                                          ? const Color(0xFF0284C7)
                                          : AppColors.textMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(width: AppSpacing.s12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              if (sortOrder != null) ...[
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceVariant,
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    '#$sortOrder',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          if (isCurrentExamAttached)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.success
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                context.l10n.linkedToLecturePill(
                                                  title,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            )
                                          else if (isAttachedToOther)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                context.l10n
                                                    .currentExamAttachedWarning(
                                                  attachedExamTitle,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.warning,
                                                ),
                                              ),
                                            )
                                          else
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0284C7)
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                context.l10n
                                                    .lectureFreeForLinking,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0284C7),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                  ),
                ),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  _isSubmitting
                      ? context.l10n.savingChanges
                      : context.l10n.confirmLinkExamAction,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: (_isSubmitting ||
                        _selectedLessonId == null ||
                        _selectedLessonId == widget.exam.linkedLessonId)
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        final selectedLesson = _lessons.firstWhere(
                          (l) => l['id'] == _selectedLessonId,
                          orElse: () => <String, dynamic>{},
                        );
                        final lessonTitle =
                            selectedLesson['title'] as String? ?? '';
                        final messenger = ScaffoldMessenger.of(context);
                        final successToast =
                            context.l10n.examLinkedSuccessToast(lessonTitle);
                        final nav = Navigator.of(context);

                        final success = await widget.cubit.linkExamToLesson(
                          examId: widget.exam.id,
                          lessonId: _selectedLessonId!,
                          groupId: widget.groupId,
                        );

                        if (mounted && context.mounted) {
                          nav.pop();
                          if (success) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(successToast),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        }
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXAM DETAILS & ATTEMPTS SHEET CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _ExamDetailsSheetContent extends StatefulWidget {
  final ExamEntity exam;
  final ExamsCubit cubit;
  final VoidCallback onLinkLecture;
  final VoidCallback onUnlinkLecture;
  final VoidCallback onDeleteExam;
  final VoidCallback? onEditQuestions;

  const _ExamDetailsSheetContent({
    required this.exam,
    required this.cubit,
    required this.onLinkLecture,
    required this.onUnlinkLecture,
    required this.onDeleteExam,
    this.onEditQuestions,
  });

  @override
  State<_ExamDetailsSheetContent> createState() =>
      _ExamDetailsSheetContentState();
}

class _ExamDetailsSheetContentState extends State<_ExamDetailsSheetContent> {
  bool _isCreatingVersion = false;
  bool _isPublishing = false;
  bool _isUnpublishing = false;
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
                          // If draft: Prominent Edit Questions button
                          if (!isPublished && widget.onEditQuestions != null)
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

                          // If published: Create new version v{N+1}
                          if (isPublished) ...[
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              icon: _isCreatingVersion
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.copy_outlined, size: 15),
                              label: Text(
                                _isCreatingVersion
                                    ? context.l10n.creatingNewVersionLoading
                                    : context.l10n.createNewVersionButton(
                                        activeVersionNumber + 1,
                                      ),
                              ),
                              onPressed: _isCreatingVersion
                                  ? null
                                  : () async {
                                      setState(() => _isCreatingVersion = true);
                                      final messenger =
                                          ScaffoldMessenger.of(context);
                                      final nav = Navigator.of(ctx);
                                      final successMsg = context
                                          .l10n
                                          .newVersionCreatedSuccess;
                                      final errorMsg = context.l10n
                                          .newVersionFailedError('');
                                      final success = await widget.cubit
                                          .createNewVersion(exam.id);
                                      if (mounted && ctx.mounted) {
                                        setState(
                                          () => _isCreatingVersion = false,
                                        );
                                        if (success) {
                                          nav.pop();
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(successMsg),
                                              backgroundColor: AppColors.success,
                                            ),
                                          );
                                        } else {
                                          messenger.showSnackBar(
                                            SnackBar(
                                              content: Text(errorMsg),
                                              backgroundColor: AppColors.error,
                                            ),
                                          );
                                        }
                                      }
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
                          ],

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
  }) {
    // Sort attempts by date descending
    final sorted = List<ExamAttemptEntity>.from(attempts)
      ..sort((a, b) {
        final dateA = a.submittedAt ?? a.startedAt;
        final dateB = b.submittedAt ?? b.startedAt;
        return dateB.compareTo(dateA);
      });

    final Map<String, _StudentAttemptsGroup> groupsMap = {};
    for (final att in sorted) {
      final key = att.studentId.isNotEmpty ? att.studentId : (att.studentName ?? 'unknown');
      if (!groupsMap.containsKey(key)) {
        groupsMap[key] = _StudentAttemptsGroup(
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

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.s16),
      itemCount: groups.length + 1,
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

        final group = groups[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: _StudentAttemptsGroupCard(
            group: group,
            exam: exam,
            dateFormat: _dateFormat,
          ),
        );
      },
    );
  }
}

class _StudentAttemptsGroup {
  final String studentId;
  final String studentName;
  final List<ExamAttemptEntity> attempts;

  _StudentAttemptsGroup({
    required this.studentId,
    required this.studentName,
    required this.attempts,
  });

  int get count => attempts.length;

  ExamAttemptEntity get latest => attempts.first;

  ExamAttemptEntity get best {
    ExamAttemptEntity top = attempts.first;
    for (final a in attempts) {
      if ((a.percentage ?? a.score?.toDouble() ?? 0) >
          (top.percentage ?? top.score?.toDouble() ?? 0)) {
        top = a;
      }
    }
    return top;
  }
}

class _StudentAttemptsGroupCard extends StatefulWidget {
  final _StudentAttemptsGroup group;
  final ExamEntity exam;
  final DateFormat dateFormat;

  const _StudentAttemptsGroupCard({
    required this.group,
    required this.exam,
    required this.dateFormat,
  });

  @override
  State<_StudentAttemptsGroupCard> createState() =>
      _StudentAttemptsGroupCardState();
}

class _StudentAttemptsGroupCardState extends State<_StudentAttemptsGroupCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final exam = widget.exam;
    final best = group.best;
    final latest = group.latest;
    final isPassed = best.isPassed(exam.passingScore);
    final hasMultiple = group.count > 1;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: _isExpanded
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.border,
          width: _isExpanded ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: hasMultiple
                ? () => setState(() => _isExpanded = !_isExpanded)
                : null,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      group.studentName.isNotEmpty
                          ? group.studentName.characters.first
                          : context.l10n.studentInitialFallback,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                group.studentName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (hasMultiple) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.history_rounded,
                                      size: 11,
                                      color: Color(0xFF7C3AED),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      context.l10n.studentAttemptsGroupCount(
                                        group.count,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF7C3AED),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          latest.submittedAt != null
                              ? widget.dateFormat.format(latest.submittedAt!)
                              : context.l10n.startedDatePrefix(
                                  widget.dateFormat.format(latest.startedAt),
                                ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (hasMultiple
                                  ? AppColors.success
                                  : latest.status.color)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                        child: Text(
                          hasMultiple
                              ? (isPassed
                                  ? context.l10n.attemptStatusSubmitted
                                  : latest.status.localizedLabel(context))
                              : latest.status.localizedLabel(context),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: hasMultiple
                                ? (isPassed
                                    ? AppColors.success
                                    : latest.status.color)
                                : latest.status.color,
                          ),
                        ),
                      ),
                      if (best.score != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          hasMultiple
                              ? context.l10n.highestScoreBadge(
                                  '${best.score}/${exam.maxScore} (${best.percentage?.toStringAsFixed(1)}%)',
                                )
                              : '${latest.score}/${exam.maxScore} (${latest.percentage?.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPassed
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasMultiple) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _isExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                  ],
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      size: 16,
                      color: Color(0xFF16A34A),
                    ),
                    tooltip: context.l10n.sendScoreToParentAction,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      context.push(
                        '/teacher/exams/${exam.id}/parent-dispatch?title=${Uri.encodeComponent(exam.title)}',
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded && hasMultiple) ...[
            const Divider(height: 1, color: AppColors.border),
            Container(
              color: AppColors.surfaceVariant.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      context.l10n.allAttemptsHistoryHeader(group.count),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ...group.attempts.asMap().entries.map((entry) {
                    final index = entry.key;
                    final att = entry.value;
                    final attemptNumber = group.count - index;
                    final isThisBest = att.id == best.id;
                    final passed = att.isPassed(exam.passingScore);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isThisBest
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isThisBest
                                    ? AppColors.success.withValues(alpha: 0.4)
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              context.l10n.attemptNumberLabel(attemptNumber),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isThisBest
                                    ? AppColors.success
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              att.submittedAt != null
                                  ? widget.dateFormat.format(att.submittedAt!)
                                  : context.l10n.startedDatePrefix(
                                      widget.dateFormat.format(att.startedAt),
                                    ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          if (att.score != null)
                            Text(
                              '${att.score}/${exam.maxScore} (${att.percentage?.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: passed
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
