import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/theme/math_tokens.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_member_entity.dart';
import '../cubit/groups_cubit.dart';
import '../cubit/groups_state.dart';
import '../widgets/add_member_dialog.dart';
import '../widgets/course_settings_dialog.dart';
import '../../../content/presentation/widgets/student_course_progress_sheet.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  final GroupEntity? initialGroup;

  const GroupDetailPage({super.key, required this.groupId, this.initialGroup});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _searchMemberController = TextEditingController();
  String _searchMemberQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<GroupsCubit>().loadGroupDetail(widget.groupId);
  }

  @override
  void dispose() {
    _searchMemberController.dispose();
    super.dispose();
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
    final mathTokens =
        Theme.of(context).extension<MathTokens>() ?? MathTokens.light;

    return BlocBuilder<GroupsCubit, GroupsState>(
      builder: (context, state) {
        if (state is GroupsLoading) {
          return const Scaffold(body: AppLoadingView.profile());
        }

        GroupEntity? group = widget.initialGroup;
        final List<GroupMemberEntity> allMembers = state is GroupsLoaded
            ? state.groupMembers
            : const [];

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
                onPressed: () =>
                    context.read<GroupsCubit>().loadGroupDetail(widget.groupId),
              ),
              IconButton(
                icon: const Icon(Icons.settings_rounded),
                tooltip: context.l10n.courseSettingsTitle,
                onPressed: () => CourseSettingsDialog.show(context, group!),
              ),
            ],
          ),
          body: ResponsiveContainer(
            maxWidth: ResponsiveBreakpoints.maxContentWidth,
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Academic Group Banner Card
                  RepaintBoundary(
                    child: AppCard(
                      padding: EdgeInsets.zero,
                      child: Stack(
                        children: [
                          // Background subtle watermark glyph
                          PositionedDirectional(
                            top: -10,
                            end: -8,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: mathTokens.formulaSymbolOpacity,
                                child: Text(
                                  mathSymbol,
                                  style: const TextStyle(
                                    fontSize: 84,
                                    fontWeight: FontWeight.w900,
                                    fontStyle: FontStyle.italic,
                                    color: AppColors.primary,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        group.name,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    AppBadge(
                                      label: group.level,
                                      variant: AppBadgeVariant.active,
                                    ),
                                  ],
                                ),
                                if (group.description != null &&
                                    group.description!.isNotEmpty) ...[
                                  const SizedBox(height: AppSpacing.s12),
                                  Text(
                                    group.description!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s16),

                  // Group Operations Quick Action Bar
                  AppCard(
                    variant: AppCardVariant.standard,
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.dashboard_customize_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                context.l10n.groupServicesAndTools,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s8,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.folder_shared_rounded,
                                size: 16,
                              ),
                              label: Text(context.l10n.manageLessons),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => context.go(
                                '${AppRoutes.teacherGroupContent.replaceAll(':groupId', widget.groupId)}?name=${Uri.encodeComponent(groupName)}',
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.assignment_rounded,
                                size: 16,
                              ),
                              label: Text(
                                context.l10n.assignmentsAndSubmissions,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => context.go(
                                '${AppRoutes.teacherGroupAssignments.replaceAll(':groupId', widget.groupId)}?name=${Uri.encodeComponent(groupName)}',
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.quiz_rounded, size: 16),
                              label: Text(context.l10n.examsBank),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => context.go(
                                '${AppRoutes.teacherGroupExams.replaceAll(':groupId', widget.groupId)}?name=${Uri.encodeComponent(groupName)}',
                              ),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(
                                Icons.campaign_rounded,
                                size: 16,
                              ),
                              label: Text(context.l10n.sendGroupAnnouncement),
                              onPressed: () => context.go(
                                '${AppRoutes.sendAnnouncement}?groupId=${widget.groupId}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s24),

                  // Members Header with Action Buttons
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.s12,
                    runSpacing: AppSpacing.s8,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.people_alt_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Flexible(
                              child: Text(
                                context.l10n.groupMembersCountHeader(
                                  allMembers.length,
                                ),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 16,
                        ),
                        label: Text(context.l10n.addMemberAction),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                          ),
                        ),
                        onPressed: () => AddMemberDialog.show(
                          context,
                          widget.groupId,
                          existingMemberIds: allMembers.map((m) => m.studentId).toSet(),
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.fact_check_rounded, size: 16),
                        label: Text(context.l10n.recordAttendanceAction),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                          ),
                        ),
                        onPressed: () => context.push(
                          '${AppRoutes.teacherAttendance}?groupId=${widget.groupId}',
                        ),
                      ),
                    ],
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
                        existingMemberIds: allMembers.map((m) => m.studentId).toSet(),
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
                      itemCount: members.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s8),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return _MemberRowCard(
                          member: member,
                          groupId: widget.groupId,
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

/// Interactive Member Row Card with smooth hover physics & tactile remove
class _MemberRowCard extends StatefulWidget {
  final GroupMemberEntity member;
  final String groupId;
  final VoidCallback onRemove;

  const _MemberRowCard({
    required this.member,
    required this.groupId,
    required this.onRemove,
  });

  @override
  State<_MemberRowCard> createState() => _MemberRowCardState();
}

class _MemberRowCardState extends State<_MemberRowCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return MouseRegion(
      cursor: MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          StudentCourseProgressSheet.show(
            context,
            groupId: widget.groupId,
            studentId: member.studentId,
            studentName: member.studentName,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    const BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.18),
                child: Text(
                  member.studentName.isNotEmpty ? member.studentName[0] : 'S',
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
                    Text(
                      member.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (member.studentEmail != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        member.studentEmail!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tooltip(
                message: context.l10n.removeFromGroupTooltip,
                child: IconButton(
                  icon: const Icon(
                    Icons.person_remove_outlined,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: widget.onRemove,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
