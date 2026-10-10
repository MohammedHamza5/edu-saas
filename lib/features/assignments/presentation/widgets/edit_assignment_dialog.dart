import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/assignment_entity.dart';
import '../cubit/assignments_cubit.dart';

class EditAssignmentDialog extends StatefulWidget {
  final AssignmentEntity assignment;

  const EditAssignmentDialog({super.key, required this.assignment});

  static Future<bool?> show(BuildContext context, AssignmentEntity assignment) {
    final cubit = context.read<AssignmentsCubit>();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: EditAssignmentDialog(assignment: assignment),
      ),
    );
  }

  @override
  State<EditAssignmentDialog> createState() => _EditAssignmentDialogState();
}

class _EditAssignmentDialogState extends State<EditAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _maxScoreController;

  DateTime? _dueDate;
  late bool _allowLateSubmission;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final a = widget.assignment;
    _titleController = TextEditingController(text: a.title);
    _instructionsController = TextEditingController(text: a.instructions ?? '');
    _maxScoreController = TextEditingController(text: a.maxScore.toString());
    _dueDate = a.dueAt;
    _allowLateSubmission = a.allowLateSubmission;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final initialDate = _dueDate ?? DateTime.now().add(const Duration(days: 7));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null && mounted) {
      final initialTime = _dueDate != null
          ? TimeOfDay(hour: _dueDate!.hour, minute: _dueDate!.minute)
          : const TimeOfDay(hour: 23, minute: 59);

      final pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _dueDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final instructions = _instructionsController.text.trim();
    final maxScore = int.tryParse(_maxScoreController.text.trim()) ?? 100;

    final cubit = context.read<AssignmentsCubit>();
    final success = await cubit.updateAssignment(
      assignmentId: widget.assignment.id,
      title: title,
      instructions: instructions.isEmpty ? null : instructions,
      dueAt: _dueDate,
      allowLateSubmission: _allowLateSubmission,
      maxScore: maxScore,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.assignmentUpdatedSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');

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
                          Icons.assignment_outlined,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          l10n.editAssignmentTitle,
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

                  // Assignment Title Field
                  AppTextField(
                    controller: _titleController,
                    labelText: l10n.assignmentTitleLabel,
                    hintText: l10n.assignmentTitleLabel,
                    prefixIcon: const Icon(Icons.title_rounded, size: 20),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return l10n.assignmentTitleLabel;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Instructions Field
                  AppTextField(
                    controller: _instructionsController,
                    labelText: l10n.assignmentInstructionsLabel,
                    hintText: l10n.assignmentInstructionsLabel,
                    maxLines: 3,
                    prefixIcon: const Icon(Icons.description_outlined, size: 20),
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Due Date & Max Score Row
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: InkWell(
                          onTap: _pickDueDate,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_month_outlined, size: 20, color: AppColors.primary),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.dueDateLabel,
                                        style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                      ),
                                      Text(
                                        _dueDate != null ? dateFormat.format(_dueDate!) : l10n.notSpecified,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        flex: 2,
                        child: AppTextField(
                          controller: _maxScoreController,
                          labelText: l10n.maxScoreLabel,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          prefixIcon: const Icon(Icons.grade_outlined, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Allow Late Submission Switch
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        l10n.allowLateSubmissionLabel,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      value: _allowLateSubmission,
                      activeColor: AppColors.primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      onChanged: (val) => setState(() => _allowLateSubmission = val),
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
