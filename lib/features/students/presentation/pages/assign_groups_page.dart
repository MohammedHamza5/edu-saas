import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/student_360_entity.dart';
import '../cubit/students_cubit.dart';
import '../cubit/students_state.dart';

/// T-05 — Assign Groups to Student (Teacher)
/// Separate step from approval — student can belong to multiple groups.
/// Teacher adds/removes; student cannot add themselves.
class AssignGroupsPage extends StatefulWidget {
  final String studentId;

  const AssignGroupsPage({super.key, required this.studentId});

  @override
  State<AssignGroupsPage> createState() => _AssignGroupsPageState();
}

class _AssignGroupsPageState extends State<AssignGroupsPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<StudentsCubit>().loadAssignGroups(widget.studentId);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSkeletonLoading() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: ResponsiveContainer(
        maxWidth: 800,
        child: Column(
          children: [
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backToStudentsList,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.studentsList),
        ),
        title: Text(context.l10n.assignGroupsTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refresh,
            onPressed: () => context.read<StudentsCubit>().loadAssignGroups(
              widget.studentId,
            ),
          ),
        ],
      ),
      body: BlocConsumer<StudentsCubit, StudentsState>(
        listener: (context, state) {
          if (state is StudentsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is StudentsLoading) {
            return _buildSkeletonLoading();
          }

          if (state is StudentsError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<StudentsCubit>().loadAssignGroups(
                widget.studentId,
              ),
            );
          }

          if (state is AssignGroupsLoaded) {
            final availableFiltered = state.availableGroups.where((g) {
              if (_searchQuery.isEmpty) return true;
              return g.groupName.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  g.groupLevel.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  );
            }).toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: ResponsiveContainer(
                maxWidth: 800,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Student header card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.s14),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppColors.primaryLight.withValues(
                              alpha: 0.15,
                            ),
                            child: Text(
                              state.student.initials,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.student.fullName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  state.student.email,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                            child: Text(
                              context.l10n.groupsCountBadge(state.currentGroups.length),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s20),

                    // Current groups
                    _SectionHeader(
                      title: context.l10n.currentlyEnrolledGroups,
                      count: state.currentGroups.length,
                    ),
                    const SizedBox(height: AppSpacing.s8),

                    if (state.currentGroups.isEmpty)
                      AppEmptyView(
                        icon: Icons.group_off_rounded,
                        message: context.l10n.noAssignedGroupsEmpty,
                      )
                    else
                      ...state.currentGroups.map(
                        (g) => _GroupTile(
                          group: g,
                          isAssigned: true,
                          onToggle: () => _removeGroup(context, g),
                        ),
                      ),

                    const SizedBox(height: AppSpacing.s24),

                    // Available groups to add
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionHeader(
                          title: context.l10n.availableGroupsToAdd,
                          count: availableFiltered.length,
                        ),
                        if (state.availableGroups.length > 3)
                          SizedBox(
                            width: 180,
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: context.l10n.searchInGroups,
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  size: 16,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s8,
                                  vertical: AppSpacing.s6,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSmall,
                                  ),
                                ),
                              ),
                              onChanged: (val) {
                                setState(() => _searchQuery = val.trim());
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),

                    if (state.availableGroups.isEmpty)
                      AppEmptyView(
                        icon: Icons.done_all_rounded,
                        message: context.l10n.studentEnrolledInAllGroups,
                      )
                    else if (availableFiltered.isEmpty)
                      AppEmptyView(
                        icon: Icons.search_off_rounded,
                        message: context.l10n.noGroupsMatchingQuery(_searchQuery),
                      )
                    else
                      ...availableFiltered.map(
                        (g) => _GroupTile(
                          group: g,
                          isAssigned: false,
                          onToggle: () => _addGroup(context, g),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Future<void> _addGroup(BuildContext context, StudentGroupInfo g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.assignGroupConfirmTitle),
        content: Text(
          context.l10n.assignGroupConfirmBody(g.groupName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.assignNowAction),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<StudentsCubit>().toggleGroupMembership(
        studentId: widget.studentId,
        groupId: g.groupId,
        add: true,
      );
    }
  }

  Future<void> _removeGroup(BuildContext context, StudentGroupInfo g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.unassignGroupConfirmTitle),
        content: Text(
          context.l10n.unassignGroupConfirmBody(g.groupName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<StudentsCubit>().toggleGroupMembership(
        studentId: widget.studentId,
        groupId: g.groupId,
        add: false,
      );
    }
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(width: AppSpacing.s8),
      Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        ),
        child: Text(
          '$count',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    ],
  );
}

class _GroupTile extends StatelessWidget {
  final StudentGroupInfo group;
  final bool isAssigned;
  final VoidCallback onToggle;

  const _GroupTile({
    required this.group,
    required this.isAssigned,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s12,
        ),
        child: Row(
          children: [
            Icon(
              isAssigned
                  ? Icons.check_circle_rounded
                  : Icons.add_circle_outline_rounded,
              color: isAssigned ? AppColors.success : AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.groupName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isAssigned)
                    Text(
                      context.l10n.joinedDateLabel(
                        '${group.joinedAt.day}/${group.joinedAt.month}/${group.joinedAt.year}',
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            AppBadge(label: group.groupLevel, variant: AppBadgeVariant.active),
            const SizedBox(width: AppSpacing.s8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isAssigned
                    ? AppColors.error
                    : AppColors.primary,
                side: BorderSide(
                  color: isAssigned
                      ? AppColors.error.withValues(alpha: 0.4)
                      : AppColors.primary.withValues(alpha: 0.4),
                ),
                minimumSize: const Size(64, 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: 0,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onToggle,
              child: Text(
                isAssigned
                    ? context.l10n.unassignAction
                    : context.l10n.assignActionPlus,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

