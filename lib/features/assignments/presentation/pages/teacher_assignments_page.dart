import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../domain/entities/assignment_entity.dart';
import '../cubit/assignments_cubit.dart';
import '../cubit/assignments_state.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../widgets/assignment_card.dart';
import '../widgets/submission_tile.dart';
import 'grade_submission_page.dart';

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

  void _showCreateAssignmentDialog() {
    final cubit = context.read<AssignmentsCubit>();
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final instructionsController = TextEditingController();
    final maxScoreController = TextEditingController(text: '100');
    DateTime? selectedDueDate;
    bool allowLate = false;

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
          child: StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.s20,
                right: AppSpacing.s20,
                top: AppSpacing.s20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.s24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.createNewAssignment,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      AppTextField(
                        controller: titleController,
                        labelText: context.l10n.assignmentTitleField,
                        hintText: context.l10n.assignmentTitleHint,
                        prefixIcon: const Icon(Icons.title),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return context.l10n.assignmentTitleRequired;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      AppTextField(
                        controller: instructionsController,
                        labelText: context.l10n.instructionsField,
                        hintText: context.l10n.instructionsHint,
                        maxLines: 3,
                        prefixIcon: const Icon(Icons.notes),
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: maxScoreController,
                              labelText: context.l10n.maxScoreField,
                              keyboardType: TextInputType.number,
                              prefixIcon: const Icon(Icons.grade),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return context.l10n.fieldRequired;
                                }
                                final numVal = int.tryParse(val.trim());
                                if (numVal == null || numVal <= 0) {
                                  return context.l10n.positiveNumberRequired;
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final pickedDate = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now().add(
                                    const Duration(days: 3),
                                  ),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 365),
                                  ),
                                );
                                if (pickedDate != null && ctx.mounted) {
                                  final pickedTime = await showTimePicker(
                                    context: ctx,
                                    initialTime: const TimeOfDay(
                                      hour: 23,
                                      minute: 59,
                                    ),
                                  );
                                  if (pickedTime != null) {
                                    setModalState(() {
                                      selectedDueDate = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                    });
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s12,
                                  vertical: AppSpacing.s16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.event,
                                      size: 20,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    Expanded(
                                      child: Text(
                                        selectedDueDate != null
                                            ? '${selectedDueDate!.month}/${selectedDueDate!.day}'
                                            : context
                                                  .l10n
                                                  .submissionDueDateField,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: selectedDueDate != null
                                              ? AppColors.textPrimary
                                              : AppColors.textMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      SwitchListTile(
                        title: Text(
                          context.l10n.allowLateSubmission,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          context.l10n.allowLateSubmissionSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        value: allowLate,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setModalState(() {
                            allowLate = val;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.s20),

                      AppButton(
                        text: context.l10n.publishAssignmentBtn,
                        icon: Icons.send_rounded,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final title = titleController.text.trim();
                          final instructions = instructionsController.text
                              .trim();
                          final maxScore = int.parse(
                            maxScoreController.text.trim(),
                          );

                          Navigator.of(ctx).pop();

                          final successMsg =
                              context.l10n.assignmentPublishedSuccess;
                          final messenger = ScaffoldMessenger.of(context);
                          final success = await context
                              .read<AssignmentsCubit>()
                              .createAssignment(
                                groupId: _selectedGroupId!,
                                title: title,
                                instructions: instructions.isNotEmpty
                                    ? instructions
                                    : null,
                                dueAt: selectedDueDate,
                                allowLateSubmission: allowLate,
                                maxScore: maxScore,
                              );

                          if (mounted && success) {
                            await _loadAssignments(forceRefresh: true);
                            if (!mounted) return;
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
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

  void _showSubmissionsSheet(AssignmentEntity assignment) {
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
              return BlocBuilder<AssignmentsCubit, AssignmentsState>(
              builder: (context, state) {
                if (state is! TeacherAssignmentsLoaded) {
                  return const AppLoadingView.list(count: 3);
                }

                final submissions = state.submissions;
                final isLoading = state.isLoadingSubmissions;

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
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(ctx).pop(),
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
                              controller: scrollController,
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              itemCount: submissions.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.s8),
                              itemBuilder: (context, index) {
                                final sub = submissions[index];
                                return SubmissionTile(
                                  submission: sub,
                                  maxScore: assignment.maxScore,
                                  onTap: () {
                                    Navigator.of(ctx).push<void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => BlocProvider.value(
                                          value: context
                                              .read<AssignmentsCubit>(),
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

              Widget bodyContent = BlocBuilder<AssignmentsCubit, AssignmentsState>(
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
                      child: AppLoadingView.cardsGrid(
                        count: 4,
                        columns: 2,
                      ),
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
                          onRetry: () => _loadAssignments(forceRefresh: true),
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
                      .where((a) =>
                          a.title.toLowerCase().contains(q) ||
                          (a.instructions?.toLowerCase().contains(q) ?? false))
                      .toList();
                }

                // Status filter
                if (_activeStatusFilter == 'open') {
                  filteredAssignments = filteredAssignments
                      .where((a) => a.dueAt == null || a.dueAt!.isAfter(now))
                      .toList();
                } else if (_activeStatusFilter == 'needs_grading') {
                  filteredAssignments = filteredAssignments
                      .where((a) => a.submissionsCount > a.reviewedCount)
                      .toList();
                } else if (_activeStatusFilter == 'past_due') {
                  filteredAssignments = filteredAssignments
                      .where((a) => a.dueAt != null && a.dueAt!.isBefore(now))
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
                final hasActiveFilters =
                    _searchQuery.isNotEmpty || _activeStatusFilter != 'all';

                if (allAssignments.isEmpty) {
                  return Column(
                    children: [
                      groupFilterBar,
                      const SizedBox(height: AppSpacing.s16),
                      Expanded(
                        child: Center(
                          child: AppEmptyView(
                            message: context.l10n.noAssignmentsForGroupTitle,
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

                        // Search Bar
                        AppTextField(
                          controller: _searchController,
                          hintText: context.l10n.searchAssignmentsHint,
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
                                label: Text(context.l10n.filterAllAssignments(allAssignments.length)),
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
                                  Icons.assignment_turned_in_rounded,
                                  size: 16,
                                  color: _activeStatusFilter == 'open'
                                      ? Colors.white
                                      : AppColors.success,
                                ),
                                label: Text('${context.l10n.active} ($openCount)'),
                                selected: _activeStatusFilter == 'open',
                                onSelected: (_) => setState(() => _activeStatusFilter = 'open'),
                                selectedColor: AppColors.success,
                                backgroundColor: AppColors.surfaceVariant,
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _activeStatusFilter == 'open'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _activeStatusFilter == 'open'
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _activeStatusFilter == 'open'
                                        ? AppColors.success
                                        : AppColors.border,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              FilterChip(
                                avatar: Icon(
                                  Icons.rate_review_rounded,
                                  size: 16,
                                  color: _activeStatusFilter == 'needs_grading'
                                      ? Colors.white
                                      : AppColors.warning,
                                ),
                                label: Text('${context.l10n.filterNeedsGrading} ($needsGradingCount)'),
                                selected: _activeStatusFilter == 'needs_grading',
                                onSelected: (_) => setState(() => _activeStatusFilter = 'needs_grading'),
                                selectedColor: AppColors.warning,
                                backgroundColor: AppColors.surfaceVariant,
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _activeStatusFilter == 'needs_grading'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _activeStatusFilter == 'needs_grading'
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _activeStatusFilter == 'needs_grading'
                                        ? AppColors.warning
                                        : AppColors.border,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              FilterChip(
                                avatar: Icon(
                                  Icons.alarm_off_rounded,
                                  size: 16,
                                  color: _activeStatusFilter == 'past_due'
                                      ? Colors.white
                                      : AppColors.error,
                                ),
                                label: Text('${context.l10n.filterPastDue} ($pastDueCount)'),
                                selected: _activeStatusFilter == 'past_due',
                                onSelected: (_) => setState(() => _activeStatusFilter = 'past_due'),
                                selectedColor: AppColors.error,
                                backgroundColor: AppColors.surfaceVariant,
                                checkmarkColor: Colors.white,
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: _activeStatusFilter == 'past_due'
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: _activeStatusFilter == 'past_due'
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _activeStatusFilter == 'past_due'
                                        ? AppColors.error
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

                        if (filteredAssignments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: AppEmptyView(
                                icon: Icons.search_off_rounded,
                                message: context.l10n.noMatchingAssignmentsFound,
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
                            children: filteredAssignments.map((assignment) {
                              return AssignmentCard(
                                assignment: assignment,
                                isTeacher: true,
                                onTap: () => _showSubmissionsSheet(assignment),
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
    ),
  );
  }
}
