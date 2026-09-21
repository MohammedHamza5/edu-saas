import 'package:edu_saas/features/groups/presentation/cubit/groups_state.dart';
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
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../widgets/exam_card.dart';
import 'create_exam_page.dart';

import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';

class TeacherExamsPage extends StatefulWidget {
  final String? groupId;
  final String? groupName;
  final String? initialExamId;

  const TeacherExamsPage({super.key, this.groupId, this.groupName, this.initialExamId});

  @override
  State<TeacherExamsPage> createState() => _TeacherExamsPageState();
}

class _TeacherExamsPageState extends State<TeacherExamsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeStatusFilter = 'all'; // 'all', 'published', 'draft'
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
        if (widget.initialExamId != null && mounted) {
          final state = context.read<ExamsCubit>().state;
          if (state is TeacherExamsLoaded) {
            try {
              final exam = state.exams.firstWhere((e) => e.id == widget.initialExamId);
              _openExamDetails(exam);
            } catch (_) {}
          }
        }
      });
    }
    try {
      context.read<GroupsCubit>().loadGroups();
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
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<ExamsCubit>().loadMoreTeacherExams();
    }
  }

  void _onGroupChanged(GroupEntity group) {
    if (_selectedGroupId == group.id) return;
    TeacherGroupFilterBar.lastSelectedGroupId = group.id;
    setState(() {
      _selectedGroupId = group.id;
      _selectedGroupName = group.name;
    });
    _loadExams();
  }

  void _openExamDetails(ExamEntity exam) {
    _showExamDetailsSheet(exam);
  }

  Future<void> _loadExams({bool forceRefresh = false}) async {
    if (_selectedGroupId != null) {
      await context.read<ExamsCubit>().loadGroupExams(
            _selectedGroupId!,
            forceRefresh: forceRefresh,
          );
    }
  }

  void _showExamDetailsSheet(ExamEntity exam) {
    final cubit = context.read<ExamsCubit>();
    cubit.selectExamForTeacher(exam);
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');

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
              return BlocBuilder<ExamsCubit, ExamsState>(
              builder: (context, state) {
                if (state is! TeacherExamsLoaded) {
                  return const AppLoadingView.list(count: 3);
                }

                final attempts = state.attempts;
                final isLoading = state.isLoadingAttempts;

                return Column(
                  children: [
                    // Handle & Header
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
                                  exam.title,
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
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                          Text(
                            context.l10n.examDetailsVersionFrozen(
                              exam.activeVersion?.versionNumber ?? 1,
                              attempts.length,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),

                          // Version actions
                          Row(
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(Icons.copy_outlined, size: 16),
                                label: Text(
                                  context.l10n.createNewVersionButton(
                                    (exam.activeVersion?.versionNumber ?? 1) +
                                        1,
                                  ),
                                ),
                                onPressed: () async {
                                  final cubit = context.read<ExamsCubit>();
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final successMsg =
                                      context.l10n.newVersionCreatedSuccess;
                                  Navigator.of(ctx).pop();
                                  final success = await cubit.createNewVersion(
                                    exam.id,
                                  );
                                  if (mounted && success) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(successMsg),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),

                    // Attempts List
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
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              itemCount: attempts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.s8),
                              itemBuilder: (context, index) {
                                final att = attempts[index];
                                final isPassed = att.isPassed(
                                  exam.passingScore,
                                );

                                return Container(
                                  padding: const EdgeInsets.all(AppSpacing.s12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMedium,
                                    ),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        child: Text(
                                          att.studentName != null &&
                                                  att.studentName!.isNotEmpty
                                              ? att
                                                    .studentName!
                                                    .characters
                                                    .first
                                              : context
                                                    .l10n
                                                    .studentInitialFallback,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              att.studentName ??
                                                  context
                                                      .l10n
                                                      .studentFallbackName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              att.submittedAt != null
                                                  ? dateFormat.format(
                                                      att.submittedAt!,
                                                    )
                                                  : context.l10n
                                                        .startedDatePrefix(
                                                          dateFormat.format(
                                                            att.startedAt,
                                                          ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.s8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: att.status.color
                                                  .withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppSpacing.radiusSmall,
                                                  ),
                                            ),
                                            child: Text(
                                              att.status.localizedLabel(
                                                context,
                                              ),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: att.status.color,
                                              ),
                                            ),
                                          ),
                                          if (att.score != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              '${att.score}/${exam.maxScore} (${att.percentage?.toStringAsFixed(1)}%)',
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
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
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
      floatingActionButton: _selectedGroupId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context)
                    .push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider.value(
                          value: context.read<ExamsCubit>(),
                          child: CreateExamPage(
                            groupId: _selectedGroupId!,
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
          child: Builder(
            builder: (context) {
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
                          child: AppLoadingView.cardsGrid(
                            count: 4,
                            columns: 2,
                          ),
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

                var filteredExams = allExams;

                // Search query filter
                if (_searchQuery.isNotEmpty) {
                  final q = _searchQuery.toLowerCase();
                  filteredExams = filteredExams
                      .where((e) => e.title.toLowerCase().contains(q))
                      .toList();
                }

                // Status filter
                if (_activeStatusFilter == 'published') {
                  filteredExams =
                      filteredExams.where((e) => e.isPublished).toList();
                } else if (_activeStatusFilter == 'draft') {
                  filteredExams =
                      filteredExams.where((e) => !e.isPublished).toList();
                }

                final publishedCount =
                    allExams.where((e) => e.isPublished).length;
                final draftCount =
                    allExams.where((e) => !e.isPublished).length;
                final hasActiveFilters =
                    _searchQuery.isNotEmpty || _activeStatusFilter != 'all';

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
                            actionText: _selectedGroupId != null
                                ? context.l10n.buildFirstExam
                                : null,
                            onAction: _selectedGroupId == null
                                ? null
                                : () {
                                    Navigator.of(context).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => BlocProvider.value(
                                          value: context.read<ExamsCubit>(),
                                          child: CreateExamPage(
                                            groupId: _selectedGroupId!,
                                            groupName: _selectedGroupName,
                                          ),
                                        ),
                                      ),
                                    ).then((_) {
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
                        const SizedBox(height: AppSpacing.s12),

                        // Search Bar
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
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
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

                        // Status Filter Chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              FilterChip(
                                label: Text(context.l10n.filterAllExams(allExams.length)),
                                selected: _activeStatusFilter == 'all',
                                onSelected: (_) => setState(() => _activeStatusFilter = 'all'),
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
                                onSelected: (_) => setState(() => _activeStatusFilter = 'published'),
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
                                onSelected: (_) => setState(() => _activeStatusFilter = 'draft'),
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
                                  backgroundColor: AppColors.error.withAlpha(20),
                                  side: BorderSide(color: AppColors.error.withAlpha(50)),
                                  onPressed: () {
                                    setState(() {
                                      _activeStatusFilter = 'all';
                                      _searchController.clear();
                                      _searchQuery = '';
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

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
                              );
                            }).toList(),
                          ),
                        if (state.isLoadingMore)
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.s16,
                            ),
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
                      child: AppLoadingView.cardsGrid(
                        count: 4,
                        columns: 2,
                      ),
                    ),
                  ],
                );
                },
              );

              if (groupsCubit != null) {
                bodyContent = BlocListener<GroupsCubit, GroupsState>(
                  bloc: groupsCubit,
                  listener: (context, groupsState) {
                    if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
                      if (_selectedGroupId == null ||
                          !groupsState.groups.any((g) => g.id == _selectedGroupId)) {
                        final targetGroup = (widget.groupId != null &&
                                groupsState.groups.any((g) => g.id == widget.groupId))
                            ? groupsState.groups.firstWhere((g) => g.id == widget.groupId)
                            : groupsState.groups.first;
                        TeacherGroupFilterBar.lastSelectedGroupId = targetGroup.id;
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
            },
          ),
        ),
      ),
    );
  }
}
