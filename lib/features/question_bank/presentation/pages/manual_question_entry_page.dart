import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/question_bank_cubit.dart';

class ManualQuestionEntryPage extends StatefulWidget {
  const ManualQuestionEntryPage({super.key});

  @override
  State<ManualQuestionEntryPage> createState() =>
      _ManualQuestionEntryPageState();
}

class _ManualQuestionEntryPageState extends State<ManualQuestionEntryPage> {
  final _formKey = GlobalKey<FormState>();
  final _sourceLabelController = TextEditingController(text: 'Q1');
  final _stemController = TextEditingController();
  final _optionAController = TextEditingController();
  final _optionBController = TextEditingController();
  final _optionCController = TextEditingController();
  final _optionDController = TextEditingController();

  String _questionType = 'multiple_choice';
  String _correctAnswer = 'A';
  bool _rightsAttested = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _sourceLabelController.dispose();
    _stemController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_rightsAttested) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attest academic rights')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final options = _questionType == 'multiple_choice'
          ? [
              {'key': 'A', 'text': _optionAController.text.trim()},
              {'key': 'B', 'text': _optionBController.text.trim()},
              {'key': 'C', 'text': _optionCController.text.trim()},
              {'key': 'D', 'text': _optionDController.text.trim()},
            ]
          : <Map<String, dynamic>>[];

      final questionId = await context
          .read<QuestionBankCubit>()
          .createManualQuestion(
            sourceLabel: _sourceLabelController.text.trim(),
            questionType: _questionType,
            stemText: _stemController.text.trim(),
            options: options,
            correctAnswer: _correctAnswer,
            rightsAttestation: {
              'claimed_source': 'teacher_authored',
              'license': 'teacher_owned',
              'attested_at': DateTime.now().toIso8601String(),
            },
          );

      if (mounted) {
        context.pushReplacement('/teacher/question-bank/review/$questionId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.manualQuestionEntry)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: Source Label & Type
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      controller: _sourceLabelController,
                      label: l10n.sourceLabel,
                      hintText: 'e.g. Q1, SAT-M1-Q4',
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _questionType,
                      decoration: InputDecoration(
                        labelText: l10n.questionType,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'multiple_choice',
                          child: Text(l10n.multipleChoice),
                        ),
                        DropdownMenuItem(
                          value: 'grid_in',
                          child: Text(l10n.gridIn),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _questionType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),

              // Stem Text
              Text(
                l10n.stemText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              TextFormField(
                controller: _stemController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: l10n.stemTextHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.s24),

              // Options if Multiple Choice
              if (_questionType == 'multiple_choice') ...[
                Text(
                  l10n.multipleChoice,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s8),
                AppTextField(
                  controller: _optionAController,
                  label: l10n.optionA,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.s8),
                AppTextField(
                  controller: _optionBController,
                  label: l10n.optionB,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.s8),
                AppTextField(
                  controller: _optionCController,
                  label: l10n.optionC,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.s8),
                AppTextField(
                  controller: _optionDController,
                  label: l10n.optionD,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.s24),

                // Correct Answer
                DropdownButtonFormField<String>(
                  value: _correctAnswer,
                  decoration: InputDecoration(
                    labelText: l10n.correctAnswer,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('Option A')),
                    DropdownMenuItem(value: 'B', child: Text('Option B')),
                    DropdownMenuItem(value: 'C', child: Text('Option C')),
                    DropdownMenuItem(value: 'D', child: Text('Option D')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _correctAnswer = val);
                  },
                ),
                const SizedBox(height: AppSpacing.s24),
              ],

              // Rights attestation checkbox
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _rightsAttested,
                title: Text(
                  l10n.rightsAttestation,
                  style: theme.textTheme.bodyMedium,
                ),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) =>
                    setState(() => _rightsAttested = val ?? false),
              ),
              const SizedBox(height: AppSpacing.s32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  text: l10n.saveAndReview,
                  icon: Icons.check,
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
