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
import '../../domain/entities/assignment_entity.dart';
import '../cubit/assignments_cubit.dart';
import '../cubit/assignments_state.dart';
import '../widgets/assignment_submissions_sheet.dart';
import '../widgets/create_assignment_sheet.dart';
import '../widgets/edit_assignment_dialog.dart';
import '../widgets/teacher_assignment_filter_section.dart';
import '../widgets/teacher_assignments_grid.dart';

class TeacherAssignmentsPage extends StatefulWidget {
  final String? groupId;
  final String? groupName;

  const TeacherAssignmentsPage({super.key, this.groupId, this.groupName});

  @override
  State<TeacherAssignmentsPage> createState() => _TeacherAssignmentsPageState();
}

class _TeacherAssignmentsPageState extends State<TeacherAssignmentsPage> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _activeStatusFilter = 'all'; // 'all', 'open', 'needs_grading', 'past_due'
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
      _loadAssignments();
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
      context.read<AssignmentsCubit>().loadMoreTeacherAssignments();
    }
  }

  void _onGroupChanged(GroupEntity group) {
    if (_selectedGroupId == group.id) return;
    TeacherGroupFilterBar.lastSelectedGroupId = group.id;
    setState(() {
      _selectedGroupId = group.id;
      _selectedGroupName = group.name;
    });
    _loadAssignments();
  }

  Future<void> _loadAssignments({bool forceRefresh = false}) async {
    if (_selectedGroupId != null) {
      await context.read<AssignmentsCubit>().loadGroupAssignments(
        _selectedGroupId!,
        forceRefresh: forceRefresh,
      );
    }
  }

  void _onResetAllFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _activeStatusFilter = 'all';
    });
  }

  void _onClearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _onSearchChanged(String val) {
    setState(() => _searchQuery = val.trim());
  }

  void _onStatusFilterChanged(String status) {
    setState(() => _activeStatusFilter = status);
  }

  void _showCreateAssignmentDialog() {
    if (_selectedGroupId == null) return;
    CreateAssignmentSheet.show(
      context,
      groupId: _selectedGroupId!,
      onCreated: () async {
        final successMsg = context.l10n.assignmentPublishedSuccess;
        final messenger = ScaffoldMessenger.of(context);
        await _loadAssignments(forceRefresh: true);
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: AppColors.success,
          ),
        );
      },
    );
  }

  void _showSubmissionsSheet(AssignmentEntity assignment) {
    AssignmentSubmissionsSheet.show(context, assignment);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backToHomeTooltip,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.teacherDashboard),
        ),
        title: Text(
          _selectedGroupName != null
              ? context.l10n.groupAssignmentsTitle(_selectedGroupName!)
              : context.l10n.manageAssignmentsTitle,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refreshTooltip,
            onPressed: () => _loadAssignments(forceRefresh: true),
          ),
        ],
      ),
      floatingActionButton: _selectedGroupId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showCreateAssignmentDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(
                context.l10n.createAssignmentFab,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Builder(
          builder: (context) {
            GroupsCubit? groupsCubit;
            try {
              groupsCubit = context.read<GroupsCubit>();
            } catch (_) {
              groupsCubit = null;
            }

            Widget bodyContent =
                BlocBuilder<AssignmentsCubit, AssignmentsState>(
              builder: (context, state) {
                final groupFilterBar = TeacherGroupFilterBar(
                  selectedGroupId: _selectedGroupId,
                  onGroupChanged: _onGroupChanged,
                  onRefresh: () => _loadAssignments(forceRefresh: true),
                );

                if (state is AssignmentsLoading) {
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

                if (state is AssignmentsError) {
                  return Column(
                    children: [
                      groupFilterBar,
                      const SizedBox(height: AppSpacing.s16),
                      Expanded(
                        child: Center(
                          child: AppErrorView(
                            message: state.message,
                            onRetry: () =>
                                _loadAssignments(forceRefresh: true),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                if (state is TeacherAssignmentsLoaded) {
                  final allAssignments = state.assignments;
                  final now = DateTime.now();

                  var filteredAssignments = allAssignments;

                  // Search query filter
                  if (_searchQuery.isNotEmpty) {
                    final q = _searchQuery.toLowerCase();
                    filteredAssignments = filteredAssignments
                        .where(
                          (a) =>
                              a.title.toLowerCase().contains(q) ||
                              (a.instructions?.toLowerCase().contains(q) ??
                                  false),
                        )
                        .toList();
                  }

                  // Status filter
                  if (_activeStatusFilter == 'open') {
                    filteredAssignments = filteredAssignments
                        .where(
                          (a) => a.dueAt == null || a.dueAt!.isAfter(now),
                        )
                        .toList();
                  } else if (_activeStatusFilter == 'needs_grading') {
                    filteredAssignments = filteredAssignments
                        .where((a) => a.submissionsCount > a.reviewedCount)
                        .toList();
                  } else if (_activeStatusFilter == 'past_due') {
                    filteredAssignments = filteredAssignments
                        .where(
                          (a) => a.dueAt != null && a.dueAt!.isBefore(now),
                        )
                        .toList();
                  }

                  final openCount = allAssignments
                      .where((a) => a.dueAt == null || a.dueAt!.isAfter(now))
                      .length;
                  final needsGradingCount = allAssignments
                      .where((a) => a.submissionsCount > a.reviewedCount)
                      .length;
                  final pastDueCount = allAssignments
                      .where((a) => a.dueAt != null && a.dueAt!.isBefore(now))
                      .length;

                  if (allAssignments.isEmpty) {
                    return Column(
                      children: [
                        groupFilterBar,
                        const SizedBox(height: AppSpacing.s16),
                        Expanded(
                          child: Center(
                            child: AppEmptyView(
                              message:
                                  context.l10n.noAssignmentsForGroupTitle,
                              subtitle:
                                  context.l10n.noAssignmentsForGroupSubtitle,
                              actionText: _selectedGroupId != null
                                  ? context.l10n.createFirstAssignmentBtn
                                  : null,
                              onAction: _selectedGroupId == null
                                  ? null
                                  : _showCreateAssignmentDialog,
                              icon: Icons.assignment_outlined,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => _loadAssignments(forceRefresh: true),
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          groupFilterBar,
                          const SizedBox(height: AppSpacing.s12),
                          TeacherAssignmentFilterSection(
                            searchController: _searchController,
                            searchQuery: _searchQuery,
                            activeStatusFilter: _activeStatusFilter,
                            totalCount: allAssignments.length,
                            openCount: openCount,
                            needsGradingCount: needsGradingCount,
                            pastDueCount: pastDueCount,
                            onSearchChanged: _onSearchChanged,
                            onClearSearch: _onClearSearch,
                            onStatusFilterChanged: _onStatusFilterChanged,
                            onResetAllFilters: _onResetAllFilters,
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          TeacherAssignmentsGrid(
                            assignments: filteredAssignments,
                            isLoadingMore: state.isLoadingMore,
                            onAssignmentTap: _showSubmissionsSheet,
                            onAssignmentEdit: (assignment) =>
                                EditAssignmentDialog.show(
                              context,
                              assignment,
                            ),
                            onResetFilters: _onResetAllFilters,
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
                listener: (context, groupsState) {
                  if (groupsState is GroupsLoaded &&
                      groupsState.groups.isNotEmpty) {
                    if (_selectedGroupId == null ||
                        !groupsState.groups.any(
                          (g) => g.id == _selectedGroupId,
                        )) {
                      final targetGroup = (widget.groupId != null &&
                              groupsState.groups.any(
                                (g) => g.id == widget.groupId,
                              ))
                          ? groupsState.groups.firstWhere(
                              (g) => g.id == widget.groupId,
                            )
                          : groupsState.groups.first;
                      TeacherGroupFilterBar.lastSelectedGroupId =
                          targetGroup.id;
                      setState(() {
                        _selectedGroupId = targetGroup.id;
                        _selectedGroupName = targetGroup.name;
                      });
                      _loadAssignments();
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
    );
  }
}
