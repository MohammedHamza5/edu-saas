import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../widgets/assign_groups_smart_card.dart';

class AssignGroupsDialog extends StatefulWidget {
  final ContentEntity content;

  const AssignGroupsDialog({super.key, required this.content});

  static Future<bool?> show(
    BuildContext context, {
    required ContentEntity content,
  }) {
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
  final Map<String, GroupCustomizationState> _groupCustomizations = {};
  final Map<String, List<Map<String, dynamic>>> _groupAvailableExams = {};
  final List<Map<String, dynamic>> _allExams = [];
  bool _isSaving = false;
  bool _isLoadingExams = true;

  @override
  void initState() {
    super.initState();
    _selectedGroupIds = Set<String>.from(widget.content.assignedGroupIds);
    if (_selectedGroupIds.isEmpty && widget.content.groupId != null) {
      _selectedGroupIds.add(widget.content.groupId!);
    }

    final groupsCubit = context.read<GroupsCubit>();
    if (groupsCubit.state is! GroupsLoaded) {
      groupsCubit.loadGroups();
    }

    _loadExistingGroupConfigsAndExams();
  }

  Future<void> _loadExistingGroupConfigsAndExams() async {
    try {
      final contentCubit = context.read<ContentCubit>();

      // 1. Fetch any existing customization from content_groups
      final cgList = await contentCubit.getContentGroupCustomizations(
        widget.content.id,
      );

      for (final row in cgList) {
        final gId = row['group_id'] as String;
        final fObj = row['file'] as Map<String, dynamic>?;
        final aObj = row['associated_exam'] as Map<String, dynamic>?;
        final pObj = row['prerequisite_exam'] as Map<String, dynamic>?;

        _groupCustomizations[gId] = GroupCustomizationState(
          groupId: gId,
          existingFileId: row['file_id'] as String?,
          existingFileName: fObj?['file_name'] as String?,
          selectedExamId: row['associated_exam_id'] as String?,
          selectedExamTitle: aObj?['title'] as String?,
          prerequisiteExamId: row['prerequisite_exam_id'] as String?,
          prerequisiteExamTitle: pObj?['title'] as String?,
          isSequentialLockEnabled: row['prerequisite_exam_id'] != null,
          sortOrder: (row['sort_order'] as num?)?.toInt() ?? 1,
          passingScoreOverride: (row['passing_score_override'] as num?)
              ?.toInt(),
        );
      }

      // 2. Fetch available exams for tenant
      final examsList = await contentCubit.getAvailableExamsSummary();

      _allExams.clear();
      for (final ex in examsList) {
        final gId = ex['group_id'] as String?;
        final title = ex['title'] as String? ?? 'بدون عنوان';
        final item = {
          'id': ex['id'],
          'title': title,
          if (gId != null) 'group_id': gId,
        };
        _allExams.add(item);
        if (gId != null) {
          _groupAvailableExams
              .putIfAbsent(gId, () => [])
              .add(item);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingExams = false);
    }
  }

  GroupCustomizationState _getOrCreateGroupState(String groupId) {
    return _groupCustomizations.putIfAbsent(
      groupId,
      () => GroupCustomizationState(
        groupId: groupId,
        selectedExamId: widget.content.associatedExamId,
        selectedExamTitle: widget.content.associatedExamTitle,
        prerequisiteExamId: widget.content.prerequisiteExamId,
        prerequisiteExamTitle: widget.content.prerequisiteExamTitle,
        existingFileName: widget.content.file?.fileName,
        sortOrder: widget.content.sortOrder > 0 ? widget.content.sortOrder : 1,
      ),
    );
  }

  Future<void> _pickHandoutForGroup(String groupId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          final customState = _getOrCreateGroupState(groupId);
          customState.customHandoutFile = file;
          customState.customHandoutBytes = file.bytes;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSave() async {
    final contentCubit = context.read<ContentCubit>();
    setState(() => _isSaving = true);

    try {
      final List<Map<String, dynamic>> groupConfigs = [];

      for (final groupId in _selectedGroupIds) {
        final customState = _getOrCreateGroupState(groupId);
        String? finalFileId = customState.existingFileId;

        // Upload custom PDF if picked for this group
        if (customState.customHandoutFile != null &&
            customState.customHandoutBytes != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final safeName = customState.customHandoutFile!.name
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
          final storagePath = 'groups/$groupId/${timestamp}_$safeName';

          finalFileId = await contentCubit.uploadAndCreateFileRecord(
            tenantId: widget.content.tenantId,
            contentId: widget.content.id,
            fileName: customState.customHandoutFile!.name,
            mimeType: 'application/pdf',
            fileBytes: customState.customHandoutBytes!,
            storagePath: storagePath,
          );
        }

        groupConfigs.add({
          'group_id': groupId,
          'file_id': finalFileId,
          'associated_exam_id': customState.selectedExamId,
          'prerequisite_exam_id': customState.isSequentialLockEnabled
              ? customState.prerequisiteExamId
              : null,
          'sort_order': customState.sortOrder,
          'passing_score_override': customState.passingScoreOverride,
        });
      }

      final success = await contentCubit.assignContentToGroups(
        contentId: widget.content.id,
        groupIds: _selectedGroupIds.toList(),
        groupConfigs: groupConfigs,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        final msg = context.l10n.groupAssignmentSuccess;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.success),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.hub_rounded,
                      color: AppColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.distributeToGroupsAction,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
              const SizedBox(height: AppSpacing.s8),
              Text(
                l10n.manageAssignedGroupsDesc,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s8),

              // Group List with Expandable Customization
              Expanded(
                child: _isLoadingExams
                    ? const Center(child: AppLoadingView.compact(size: 32))
                    : BlocBuilder<GroupsCubit, GroupsState>(
                        builder: (context, state) {
                          if (state is GroupsLoading) {
                            return const Center(
                              child: AppLoadingView.compact(size: 32),
                            );
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
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.s8),
                              itemBuilder: (context, index) {
                                final group = groups[index];
                                final isSelected = _selectedGroupIds.contains(
                                  group.id,
                                );
                                final customState = _getOrCreateGroupState(
                                  group.id,
                                );
                                final availableExams =
                                    _allExams.isNotEmpty
                                        ? _allExams
                                        : (_groupAvailableExams[group.id] ?? []);

                                return AssignGroupsSmartCard(
                                  group: group,
                                  isSelected: isSelected,
                                  customState: customState,
                                  availableExams: availableExams,
                                  onSelectionChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        _selectedGroupIds.add(group.id);
                                      } else {
                                        _selectedGroupIds.remove(group.id);
                                      }
                                    });
                                  },
                                  onPickHandout: () =>
                                      _pickHandoutForGroup(group.id),
                                  onExamChanged: (examId, examTitle) {
                                    setState(() {
                                      customState.selectedExamId = examId;
                                      customState.selectedExamTitle = examTitle;
                                    });
                                  },
                                  onLockToggled: (enabled) {
                                    setState(() {
                                      customState.isSequentialLockEnabled =
                                          enabled;
                                    });
                                  },
                                  onPrereqExamChanged: (examId, examTitle) {
                                    setState(() {
                                      customState.prerequisiteExamId = examId;
                                      customState.prerequisiteExamTitle =
                                          examTitle;
                                    });
                                  },
                                  onSortOrderChanged: (val) {
                                    customState.sortOrder = val;
                                  },
                                  onPassingScoreOverrideChanged: (val) {
                                    customState.passingScoreOverride = val;
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
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(
                      MaterialLocalizations.of(context).cancelButtonLabel,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  AppButton(
                    text: l10n.saveGroupAssignmentsAction,
                    isLoading: _isSaving,
                    icon: Icons.check_circle_outline_rounded,
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
