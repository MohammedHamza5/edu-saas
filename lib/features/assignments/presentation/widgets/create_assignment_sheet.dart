import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/assignments_cubit.dart';

/// Modal bottom sheet form to create and publish a new assignment for a group.
class CreateAssignmentSheet extends StatefulWidget {
  final String groupId;
  final VoidCallback onCreated;

  const CreateAssignmentSheet({
    super.key,
    required this.groupId,
    required this.onCreated,
  });

  /// Opens the create assignment bottom sheet modal.
  static void show(
    BuildContext context, {
    required String groupId,
    required VoidCallback onCreated,
  }) {
    final cubit = context.read<AssignmentsCubit>();
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
          child: CreateAssignmentSheet(
            groupId: groupId,
            onCreated: onCreated,
          ),
        );
      },
    );
  }

  @override
  State<CreateAssignmentSheet> createState() => _CreateAssignmentSheetState();
}

class _CreateAssignmentSheetState extends State<CreateAssignmentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _maxScoreController = TextEditingController(text: '100');
  DateTime? _selectedDueDate;
  bool _allowLate = false;
  bool _isPublishing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.s20,
        right: AppSpacing.s20,
        top: AppSpacing.s20,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.s24,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              AppTextField(
                controller: _titleController,
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
                controller: _instructionsController,
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
                      controller: _maxScoreController,
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
                          context: context,
                          initialDate: DateTime.now().add(
                            const Duration(days: 3),
                          ),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (pickedDate != null && context.mounted) {
                          final pickedTime = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(
                              hour: 23,
                              minute: 59,
                            ),
                          );
                          if (pickedTime != null && mounted) {
                            setState(() {
                              _selectedDueDate = DateTime(
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
                                _selectedDueDate != null
                                    ? '${_selectedDueDate!.month}/${_selectedDueDate!.day}'
                                    : context.l10n.submissionDueDateField,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _selectedDueDate != null
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
                value: _allowLate,
                activeThumbColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (val) {
                  setState(() {
                    _allowLate = val;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.s20),

              AppButton(
                text: context.l10n.publishAssignmentBtn,
                icon: Icons.send_rounded,
                isLoading: _isPublishing,
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final title = _titleController.text.trim();
                  final instructions = _instructionsController.text.trim();
                  final maxScore = int.parse(_maxScoreController.text.trim());
                  final navigator = Navigator.of(context);

                  setState(() => _isPublishing = true);
                  final success = await context
                      .read<AssignmentsCubit>()
                      .createAssignment(
                        groupId: widget.groupId,
                        title: title,
                        instructions:
                            instructions.isNotEmpty ? instructions : null,
                        dueAt: _selectedDueDate,
                        allowLateSubmission: _allowLate,
                        maxScore: maxScore,
                      );

                  if (!mounted) return;
                  setState(() => _isPublishing = false);

                  if (success) {
                    navigator.pop();
                    widget.onCreated();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
