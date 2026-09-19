import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';

class AssignGroupsDialog extends StatefulWidget {
  final ContentEntity content;

  const AssignGroupsDialog({
    super.key,
    required this.content,
  });

  static Future<bool?> show(BuildContext context, {required ContentEntity content}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<ContentCubit>()),
            BlocProvider.value(value: context.read<GroupsCubit>()),
          ],
          child: AssignGroupsDialog(content: content),
        );
      },
    );
  }

  @override
  State<AssignGroupsDialog> createState() => _AssignGroupsDialogState();
}

class _AssignGroupsDialogState extends State<AssignGroupsDialog> {
  late final Set<String> _selectedGroupIds;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedGroupIds = Set<String>.from(widget.content.assignedGroupIds);
    // If empty but single groupId is set, include it
    if (_selectedGroupIds.isEmpty && widget.content.groupId != null) {
      _selectedGroupIds.add(widget.content.groupId!);
    }

    final groupsCubit = context.read<GroupsCubit>();
    if (groupsCubit.state is! GroupsLoaded) {
      groupsCubit.loadGroups();
    }
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      final success = await context.read<ContentCubit>().assignContentToGroups(
            contentId: widget.content.id,
            groupIds: _selectedGroupIds.toList(),
          );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupAssignmentSuccess),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.groups_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.manageAssignedGroupsTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.content.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                l10n.manageAssignedGroupsDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),

              // Group List
              Expanded(
                child: BlocBuilder<GroupsCubit, GroupsState>(
                  builder: (context, state) {
                    if (state is GroupsLoading) {
                      return const Center(child: CircularProgressIndicator.adaptive());
                    }

                    if (state is GroupsError) {
                      return Center(
                        child: Text(
                          state.message,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      );
                    }

                    if (state is GroupsLoaded) {
                      final groups = state.groups;
                      if (groups.isEmpty) {
                        return Center(
                          child: Text(
                            l10n.noGroupsAvailable,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        itemCount: groups.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s4),
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          final isSelected = _selectedGroupIds.contains(group.id);

                          return _GroupCheckboxTile(
                            group: group,
                            isSelected: isSelected,
                            onChanged: (checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedGroupIds.add(group.id);
                                } else {
                                  _selectedGroupIds.remove(group.id);
                                }
                              });
                            },
                          );
                        },
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.s16),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  AppButton(
                    text: l10n.saveGroupAssignmentsAction,
                    isLoading: _isSaving,
                    icon: Icons.check,
                    onPressed: _isSaving ? null : _handleSave,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCheckboxTile extends StatelessWidget {
  final GroupEntity group;
  final bool isSelected;
  final ValueChanged<bool?> onChanged;

  const _GroupCheckboxTile({
    required this.group,
    required this.isSelected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return InkWell(
      onTap: () => onChanged(!isSelected),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: AppSpacing.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  if (group.level.isNotEmpty)
                    Text(
                      group.level,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                l10n.enrolledStudentsCountLabel(group.membersCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
