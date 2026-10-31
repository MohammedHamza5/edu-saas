import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_member_entity.dart';
import '../cubit/groups_cubit.dart';
import '../cubit/groups_state.dart';
import '../widgets/add_member_dialog.dart';
import '../widgets/course_settings_dialog.dart';
import '../widgets/edit_group_dialog.dart';
import '../widgets/group_hero_banner_card.dart';
import '../widgets/group_member_row_card.dart';
import '../widgets/group_members_header_bar.dart';
import '../widgets/group_services_action_bar.dart';

/// Group Detail Page coordinator displaying cohort overview, quick operations, and enrolled member roster.
class GroupDetailPage extends StatefulWidget {
  final String groupId;
  final GroupEntity? initialGroup;
  final void Function(BuildContext context, GroupMemberEntity member)?
      onMemberTap;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    this.initialGroup,
    this.onMemberTap,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _searchMemberController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchMemberQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<GroupsCubit>().loadGroupDetail(widget.groupId);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchMemberController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<GroupsCubit>().loadMoreGroupMembers();
    }
  }

  void _confirmRemoveMember(String studentId, String studentName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmRemoveMemberTitle),
        content: Text(context.l10n.confirmRemoveMemberBody(studentName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<GroupsCubit>().removeMember(
                    groupId: widget.groupId,
                    studentId: studentId,
                  );
            },
            child: Text(context.l10n.removeStudentConfirmAction),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteGroup(
      BuildContext context, GroupEntity group) async {
    final l10n = context.l10n;
    final cubit = context.read<GroupsCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteGroupConfirmTitle),
        content: Text(l10n.deleteGroupConfirmBody(group.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteGroupAction),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (confirmed == true) {
      final ok = await cubit.deleteGroup(group.id);
      if (!context.mounted) return;
      if (ok) {
        AppFeedback.showSuccess(context, l10n.groupDeletedSuccess);
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(AppRoutes.groupsList);
        }
      }
    }
  }

  String _getMathSymbol(String level) {
    final lower = level.toLowerCase();
    if (lower.contains('sat')) return 'f(x)';
    if (lower.contains('est')) return 'Δ';
    if (lower.contains('act')) return '√x';
    if (lower.contains('basic')) return '∑';
    if (lower.contains('advance') || lower.contains('calc')) return '∫';
    return 'π';
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupsCubit, GroupsState>(
      builder: (context, state) {
        if (state is GroupsLoading) {
          return const Scaffold(body: AppLoadingView.profile());
        }

        GroupEntity? group = widget.initialGroup;
        final List<GroupMemberEntity> allMembers =
            state is GroupsLoaded ? state.groupMembers : const [];

        if (state is GroupsLoaded && state.selectedGroup != null) {
          group = state.selectedGroup;
        }

        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.groupDetailTitle)),
            body: Center(child: Text(context.l10n.groupNotFound)),
          );
        }

        // Filter members by search query
        final members = allMembers.where((m) {
          if (_searchMemberQuery.isEmpty) return true;
          final q = _searchMemberQuery.toLowerCase();
          return m.studentName.toLowerCase().contains(q) ||
              (m.studentEmail?.toLowerCase().contains(q) ?? false);
        }).toList();

        final mathSymbol = _getMathSymbol(group.level);
        final groupName = group.name;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: context.l10n.backToGroups,
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.groupsList),
            ),
            title: Text(group.name, overflow: TextOverflow.ellipsis),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: context.l10n.refresh,
                onPressed: () => context
                    .read<GroupsCubit>()
                    .loadGroupDetail(widget.groupId),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: context.l10n.editGroupAction,
                onPressed: () => EditGroupDialog.show(context, group!),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: context.l10n.courseSettingsTitle,
                onPressed: () => CourseSettingsDialog.show(context, group!),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.error,
                ),
                tooltip: context.l10n.deleteGroupAction,
                onPressed: () => _confirmDeleteGroup(context, group!),
              ),
            ],
          ),
          body: ResponsiveContainer(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Academic Group Banner Card
                  GroupHeroBannerCard(
                    group: group,
                    mathSymbol: mathSymbol,
                  ),

                  const SizedBox(height: AppSpacing.s16),

                  // Group Operations Quick Action Bar
                  GroupServicesActionBar(
                    groupId: widget.groupId,
                    groupName: groupName,
                  ),

                  const SizedBox(height: AppSpacing.s24),

                  // Members Header with Action Buttons
                  GroupMembersHeaderBar(
                    totalMembersCount: allMembers.length,
                    groupId: widget.groupId,
                    existingMemberIds:
                        allMembers.map((m) => m.studentId).toSet(),
                  ),

                  const SizedBox(height: AppSpacing.s16),

                  // Search filter when list is long
                  if (allMembers.length > 3) ...[
                    TextField(
                      controller: _searchMemberController,
                      decoration: InputDecoration(
                        hintText: context.l10n.searchEnrolledStudentsHint,
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        suffixIcon: _searchMemberQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _searchMemberController.clear();
                                    _searchMemberQuery = '';
                                  });
                                },
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                          vertical: AppSpacing.s8,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _searchMemberQuery = val.trim());
                      },
                    ),
                    const SizedBox(height: AppSpacing.s12),
                  ],

                  // Members List / Empty View
                  if (allMembers.isEmpty)
                    AppEmptyView(
                      message: context.l10n.noStudentsInGroupYet,
                      actionText: context.l10n.addFirstStudent,
                      onAction: () => AddMemberDialog.show(
                        context,
                        widget.groupId,
                        existingMemberIds:
                            allMembers.map((m) => m.studentId).toSet(),
                      ),
                    )
                  else if (members.isEmpty)
                    AppEmptyView(
                      message: context.l10n.noStudentsMatchSearch,
                      actionText: context.l10n.clearSearch,
                      onAction: () {
                        setState(() {
                          _searchMemberController.clear();
                          _searchMemberQuery = '';
                        });
                      },
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length +
                          (state is GroupsLoaded && state.isLoadingMoreMembers
                              ? 1
                              : 0),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s8),
                      itemBuilder: (context, index) {
                        if (index == members.length) {
                          return const Padding(
                            padding:
                                EdgeInsets.symmetric(vertical: AppSpacing.s16),
                            child: Center(
                              child: AppLoadingView.compact(size: 24),
                            ),
                          );
                        }
                        final member = members[index];
                        return GroupMemberRowCard(
                          member: member,
                          groupId: widget.groupId,
                          onMemberTap: widget.onMemberTap,
                          onRemove: () => _confirmRemoveMember(
                            member.studentId,
                            member.studentName,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
