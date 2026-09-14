import 'package:edu_saas/features/groups/presentation/cubit/groups_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
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

  const TeacherExamsPage({super.key, this.groupId, this.groupName});

  @override
  State<TeacherExamsPage> createState() => _TeacherExamsPageState();
}

class _TeacherExamsPageState extends State<TeacherExamsPage> {
  String? _selectedGroupId;
  String? _selectedGroupName;

  @override
  void initState() {
    super.initState();
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
      _loadExams();
    }
    try {
      context.read<GroupsCubit>().loadGroups();
    } catch (_) {}
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

  void _loadExams() {
    if (_selectedGroupId != null) {
      context.read<ExamsCubit>().loadGroupExams(_selectedGroupId!);
    }
  }

  void _showExamDetailsSheet(ExamEntity exam) {
    context.read<ExamsCubit>().selectExamForTeacher(exam);
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
        return DraggableScrollableSheet(
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
              : context.go(AppRouter.teacherDashboard),
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
            onPressed: _loadExams,
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
                        _loadExams();
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
                    onRefresh: _loadExams,
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
                          onRetry: _loadExams,
                        ),
                      ),
                    ),
                  ],
                );
              }

              if (state is TeacherExamsLoaded) {
                final exams = state.exams;

                if (exams.isEmpty) {
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
                                    );
                                  },
                            icon: Icons.quiz_outlined,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadExams(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 96),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        groupFilterBar,
                        const SizedBox(height: AppSpacing.s16),
                        ResponsiveGrid(
                          mobileColumns: 1,
                          tabletColumns: 2,
                          desktopColumns: 2,
                          spacing: AppSpacing.s16,
                          runSpacing: AppSpacing.s16,
                          children: exams.map((exam) {
                            return ExamCard(
                              exam: exam,
                              isTeacher: true,
                              onTap: () => _showExamDetailsSheet(exam),
                            );
                          }).toList(),
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
