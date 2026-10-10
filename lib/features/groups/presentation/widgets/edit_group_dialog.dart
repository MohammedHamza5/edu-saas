import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/group_entity.dart';
import '../cubit/groups_cubit.dart';

class EditGroupDialog extends StatefulWidget {
  final GroupEntity group;

  const EditGroupDialog({super.key, required this.group});

  static Future<bool?> show(BuildContext context, GroupEntity group) {
    final cubit = context.read<GroupsCubit>();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: EditGroupDialog(group: group),
      ),
    );
  }

  @override
  State<EditGroupDialog> createState() => _EditGroupDialogState();
}

class _EditGroupDialogState extends State<EditGroupDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _passingScoreController;

  late String _selectedLevel;
  late String _previousContentAccess;
  late bool _enforceSequential;
  bool _isSubmitting = false;

  static const List<String> _levels = [
    'SAT',
    'EST',
    'ACT',
    'Basics',
    'Advanced',
  ];

  @override
  void initState() {
    super.initState();
    final group = widget.group;
    _nameController = TextEditingController(text: group.name);
    _descriptionController = TextEditingController(text: group.description ?? '');
    _passingScoreController = TextEditingController(
      text: group.defaultPassingScore.toString(),
    );
    _selectedLevel = _levels.contains(group.level) ? group.level : _levels.first;
    _previousContentAccess = group.previousContentAccess;
    _enforceSequential = group.enforceSequentialLearning;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _passingScoreController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final passingScore = int.tryParse(_passingScoreController.text.trim()) ?? 60;

    final cubit = context.read<GroupsCubit>();
    final success = await cubit.updateGroupDetails(
      groupId: widget.group.id,
      name: name,
      level: _selectedLevel,
      description: description.isEmpty ? null : description,
      previousContentAccess: _previousContentAccess,
      enforceSequentialLearning: _enforceSequential,
      defaultPassingScore: passingScore,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupUpdatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        side: BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
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
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.groups_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          l10n.editGroupTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s20),

                  // Group Name Field
                  AppTextField(
                    controller: _nameController,
                    labelText: l10n.groupNameLabel,
                    hintText: l10n.groupNameLabel,
                    prefixIcon: const Icon(Icons.title_rounded, size: 20),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return l10n.groupNameLabel;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Academic Track / Level Selector
                  Text(
                    l10n.groupLevelLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: _levels.map((level) {
                      final isSelected = _selectedLevel == level;
                      return ChoiceChip(
                        label: Text(level),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.surfaceVariant,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                        ),
                        onSelected: (selected) {
                          if (selected) setState(() => _selectedLevel = level);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Description Field
                  AppTextField(
                    controller: _descriptionController,
                    labelText: l10n.groupDescriptionLabel,
                    hintText: l10n.groupDescriptionLabel,
                    maxLines: 2,
                    prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Previous Content Policy & Passing score
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.previousContentAccessLabel,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        RadioListTile<String>(
                          title: Text(l10n.allowPreviousContent, style: const TextStyle(fontSize: 12)),
                          value: 'allow',
                          groupValue: _previousContentAccess,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            if (val != null) setState(() => _previousContentAccess = val);
                          },
                        ),
                        RadioListTile<String>(
                          title: Text(l10n.denyPreviousContent, style: const TextStyle(fontSize: 12)),
                          value: 'deny',
                          groupValue: _previousContentAccess,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            if (val != null) setState(() => _previousContentAccess = val);
                          },
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text(l10n.sequentialLearning, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text(l10n.sequentialLearningDesc, style: const TextStyle(fontSize: 11)),
                          value: _enforceSequential,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (val) => setState(() => _enforceSequential = val),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
                        child: Text(l10n.cancel),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      AppButton(
                        text: l10n.saveChangesAction,
                        isLoading: _isSubmitting,
                        onPressed: _submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
