import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';

class EditExamDialog extends StatefulWidget {
  final ExamEntity exam;

  const EditExamDialog({super.key, required this.exam});

  static Future<bool?> show(BuildContext context, ExamEntity exam) {
    final cubit = context.read<ExamsCubit>();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: EditExamDialog(exam: exam),
      ),
    );
  }

  @override
  State<EditExamDialog> createState() => _EditExamDialogState();
}

class _EditExamDialogState extends State<EditExamDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _durationController;
  late final TextEditingController _passingScoreController;
  late final TextEditingController _maxScoreController;

  late bool _isUntimed;
  late bool _shuffleQuestions;
  late bool _showResult;
  late bool _allowRetake;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final exam = widget.exam;
    _titleController = TextEditingController(text: exam.title);
    _isUntimed = exam.isUntimed;
    _durationController = TextEditingController(
      text: exam.isUntimed ? '60' : exam.durationMinutes.toString(),
    );
    _passingScoreController = TextEditingController(
      text: exam.passingScore != null ? exam.passingScore.toString() : '60',
    );
    _maxScoreController = TextEditingController(
      text: exam.maxScore.toString(),
    );
    _shuffleQuestions = exam.shuffleQuestions;
    _showResult = exam.showResult;
    _allowRetake = exam.allowRetake;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _passingScoreController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final duration = _isUntimed
        ? 0
        : (int.tryParse(_durationController.text.trim()) ?? 60);
    final passingScore = int.tryParse(_passingScoreController.text.trim());
    final maxScore = int.tryParse(_maxScoreController.text.trim()) ?? 100;

    final cubit = context.read<ExamsCubit>();
    final success = await cubit.updateExam(
      examId: widget.exam.id,
      title: title,
      durationMinutes: duration,
      maxScore: maxScore,
      passingScore: passingScore,
      shuffleQuestions: _shuffleQuestions,
      showResult: _showResult,
      allowRetake: _allowRetake,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.examUpdatedSuccess),
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
                          Icons.edit_note_rounded,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Text(
                          l10n.editExamTitle,
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

                  // Exam Title Field
                  AppTextField(
                    controller: _titleController,
                    labelText: l10n.examTitleLabel,
                    hintText: l10n.examTitleLabel,
                    prefixIcon: const Icon(Icons.title_rounded, size: 20),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return l10n.examTitleLabel;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Duration Controls
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _durationController,
                          labelText: l10n.examDurationLabel,
                          enabled: !_isUntimed,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                          validator: (val) {
                            if (!_isUntimed) {
                              final d = int.tryParse(val ?? '');
                              if (d == null || d <= 0) {
                                return l10n.examDurationLabel;
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _isUntimed,
                                activeColor: AppColors.primary,
                                onChanged: (val) => setState(() => _isUntimed = val ?? false),
                              ),
                              Expanded(
                                child: Text(
                                  l10n.unlimitedDuration,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Passing score & Max score
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _passingScoreController,
                          labelText: l10n.passingScorePercentLabel,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          prefixIcon: const Icon(Icons.verified_outlined, size: 20),
                          validator: (val) {
                            final score = int.tryParse(val ?? '');
                            if (score != null && (score < 0 || score > 100)) {
                              return '0 - 100';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
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

                  // Switches
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: Text(l10n.shuffleQuestionsLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: _shuffleQuestions,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (val) => setState(() => _shuffleQuestions = val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text(l10n.showResultLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: _showResult,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (val) => setState(() => _showResult = val),
                        ),
                        const Divider(height: 1),
                        SwitchListTile(
                          title: Text(l10n.allowRetakeLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          value: _allowRetake,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (val) => setState(() => _allowRetake = val),
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
