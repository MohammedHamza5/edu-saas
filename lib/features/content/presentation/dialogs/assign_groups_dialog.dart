import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';

class _GroupCustomizationState {
  final String groupId;
  PlatformFile? customHandoutFile;
  Uint8List? customHandoutBytes;
  String? existingFileId;
  String? existingFileName;
  String? selectedExamId;
  String? selectedExamTitle;
  bool isSequentialLockEnabled;
  String? prerequisiteExamId;
  String? prerequisiteExamTitle;
  int sortOrder;

  _GroupCustomizationState({
    required this.groupId,
    this.existingFileId,
    this.existingFileName,
    this.selectedExamId,
    this.selectedExamTitle,
    this.isSequentialLockEnabled = true,
    this.prerequisiteExamId,
    this.prerequisiteExamTitle,
    this.sortOrder = 1,
  });
}

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
  final Map<String, _GroupCustomizationState> _groupCustomizations = {};
  final Map<String, List<Map<String, dynamic>>> _groupAvailableExams = {};
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
      final client = SupabaseService.client;

      // 1. Fetch any existing customization from content_groups
      final cgRes = await client
          .from('content_groups')
          .select(
            'group_id, file_id, associated_exam_id, prerequisite_exam_id, sort_order, '
            'file:files!content_groups_file_id_fkey(id, file_name), '
            'associated_exam:exams!content_groups_associated_exam_id_fkey(id, title), '
            'prerequisite_exam:exams!content_groups_prerequisite_exam_id_fkey(id, title)',
          )
          .eq('content_id', widget.content.id);

      for (final row in (cgRes as List<dynamic>)) {
        final gId = row['group_id'] as String;
        final fObj = row['file'] as Map<String, dynamic>?;
        final aObj = row['associated_exam'] as Map<String, dynamic>?;
        final pObj = row['prerequisite_exam'] as Map<String, dynamic>?;

        _groupCustomizations[gId] = _GroupCustomizationState(
          groupId: gId,
          existingFileId: row['file_id'] as String?,
          existingFileName: fObj?['file_name'] as String?,
          selectedExamId: row['associated_exam_id'] as String?,
          selectedExamTitle: aObj?['title'] as String?,
          prerequisiteExamId: row['prerequisite_exam_id'] as String?,
          prerequisiteExamTitle: pObj?['title'] as String?,
          isSequentialLockEnabled: row['prerequisite_exam_id'] != null,
          sortOrder: (row['sort_order'] as num?)?.toInt() ?? 1,
        );
      }

      // 2. Fetch available exams for tenant
      final tenantId = widget.content.tenantId;
      final examsRes = await client
          .from('exams')
          .select('id, group_id, title')
          .eq('tenant_id', tenantId)
          .order('title');

      for (final ex in (examsRes as List<dynamic>)) {
        final gId = ex['group_id'] as String?;
        if (gId != null) {
          _groupAvailableExams.putIfAbsent(gId, () => []).add(ex as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _isLoadingExams = false);
    }
  }

  _GroupCustomizationState _getOrCreateGroupState(String groupId) {
    return _groupCustomizations.putIfAbsent(
      groupId,
      () => _GroupCustomizationState(
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
          final state = _getOrCreateGroupState(groupId);
          state.customHandoutFile = file;
          state.customHandoutBytes = file.bytes;
        });
      }
    } catch (_) {}
  }

  Future<void> _handleSave() async {
    final contentCubit = context.read<ContentCubit>();
    setState(() => _isSaving = true);
    final client = SupabaseService.client;
    final tenantId = widget.content.tenantId;

    try {
      final List<Map<String, dynamic>> groupConfigs = [];

      for (final groupId in _selectedGroupIds) {
        final customState = _getOrCreateGroupState(groupId);
        String? finalFileId = customState.existingFileId;

        // Upload custom PDF if picked for this group
        if (customState.customHandoutFile != null && customState.customHandoutBytes != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final safeName = customState.customHandoutFile!.name
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
          final storagePath = 'group_handouts/${groupId}_${timestamp}_$safeName';

          await client.storage.from('group-content').uploadBinary(
                storagePath,
                Uint8List.fromList(customState.customHandoutBytes!),
                fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
              );

          final fileRes = await client.from('files').insert({
            'tenant_id': tenantId,
            'content_id': widget.content.id,
            'storage_path': storagePath,
            'file_name': customState.customHandoutFile!.name,
            'mime_type': 'application/pdf',
            'file_size': customState.customHandoutFile!.size,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }).select('id').single();

          finalFileId = fileRes['id'] as String;
        }

        groupConfigs.add({
          'group_id': groupId,
          'file_id': finalFileId,
          'associated_exam_id': customState.selectedExamId,
          'prerequisite_exam_id': customState.isSequentialLockEnabled ? customState.prerequisiteExamId : null,
          'sort_order': customState.sortOrder,
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
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
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
                            return const Center(child: AppLoadingView.compact(size: 32));
                          }

                          if (state is GroupsError) {
                            return Center(
                              child: Text(
                                state.message,
                                style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.error),
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
                              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                              itemBuilder: (context, index) {
                                final group = groups[index];
                                final isSelected = _selectedGroupIds.contains(group.id);
                                final customState = _getOrCreateGroupState(group.id);
                                final availableExams = _groupAvailableExams[group.id] ?? [];

                                return _SmartGroupCard(
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
                                  onPickHandout: () => _pickHandoutForGroup(group.id),
                                  onExamChanged: (examId, examTitle) {
                                    setState(() {
                                      customState.selectedExamId = examId;
                                      customState.selectedExamTitle = examTitle;
                                    });
                                  },
                                  onLockToggled: (enabled) {
                                    setState(() {
                                      customState.isSequentialLockEnabled = enabled;
                                    });
                                  },
                                  onPrereqExamChanged: (examId, examTitle) {
                                    setState(() {
                                      customState.prerequisiteExamId = examId;
                                      customState.prerequisiteExamTitle = examTitle;
                                    });
                                  },
                                  onSortOrderChanged: (val) {
                                    customState.sortOrder = val;
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

class _SmartGroupCard extends StatelessWidget {
  final GroupEntity group;
  final bool isSelected;
  final _GroupCustomizationState customState;
  final List<Map<String, dynamic>> availableExams;
  final ValueChanged<bool?> onSelectionChanged;
  final VoidCallback onPickHandout;
  final void Function(String? id, String? title) onExamChanged;
  final ValueChanged<bool> onLockToggled;
  final void Function(String? id, String? title) onPrereqExamChanged;
  final ValueChanged<int> onSortOrderChanged;

  const _SmartGroupCard({
    required this.group,
    required this.isSelected,
    required this.customState,
    required this.availableExams,
    required this.onSelectionChanged,
    required this.onPickHandout,
    required this.onExamChanged,
    required this.onLockToggled,
    required this.onPrereqExamChanged,
    required this.onSortOrderChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header checkbox row
          InkWell(
            onTap: () => onSelectionChanged(!isSelected),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: onSelectionChanged,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.enrolledStudentsCountLabel(group.membersCount),
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contextual customization panel (shows only when group is checked)
          if (isSelected) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              color: AppColors.surfaceVariant.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Group-specific PDF Handout
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFEA580C)),
                      const SizedBox(width: 6),
                      Text(
                        l10n.groupHandoutPdfLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            customState.customHandoutFile != null
                                ? customState.customHandoutFile!.name
                                : customState.existingFileName != null
                                    ? customState.existingFileName!
                                    : l10n.uploadPdfFileTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: (customState.customHandoutFile != null || customState.existingFileName != null)
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onPickHandout,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: Text(
                          l10n.uploadFirstPdfAction,
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // 2. Group-specific Lesson Quiz
                  Row(
                    children: [
                      const Icon(Icons.quiz_rounded, size: 16, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        l10n.groupExamLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: availableExams.any((e) => e['id'] == customState.selectedExamId)
                        ? customState.selectedExamId
                        : null,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    hint: Text(l10n.noExamSelected, style: const TextStyle(fontSize: 12)),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.noExamSelected, style: const TextStyle(fontSize: 12)),
                      ),
                      ...availableExams.map((ex) {
                        return DropdownMenuItem<String?>(
                          value: ex['id'] as String,
                          child: Text(
                            ex['title'] as String? ?? '',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      final selectedTitle = availableExams
                          .where((e) => e['id'] == val)
                          .firstOrNull?['title'] as String?;
                      onExamChanged(val, selectedTitle);
                    },
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // 3. Sequential Lock Prerequisite
                  Row(
                    children: [
                      Switch.adaptive(
                        value: customState.isSequentialLockEnabled,
                        onChanged: onLockToggled,
                        activeColor: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.lockUntilPreviousQuizPassed,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
