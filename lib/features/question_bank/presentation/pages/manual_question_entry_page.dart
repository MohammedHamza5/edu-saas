import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../exams/presentation/widgets/exam_image_attachment_box.dart';
import '../cubit/question_bank_cubit.dart';

class _DraftOption {
  final TextEditingController controller;
  bool isCorrect;

  _DraftOption({
    String text = '',
    this.isCorrect = false,
  }) : controller = TextEditingController(text: text);

  void dispose() {
    controller.dispose();
  }
}

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

  String _questionType = 'multiple_choice';
  bool _trueFalseAnswer = true; // true = Option A (True), false = Option B (False)
  bool _rightsAttested = true;
  bool _isSubmitting = false;

  String? _imageUrl;
  Map<String, dynamic>? _imageMeta;

  late List<_DraftOption> _options;

  @override
  void initState() {
    super.initState();
    _options = [
      _DraftOption(isCorrect: true),
      _DraftOption(isCorrect: false),
      _DraftOption(isCorrect: false),
      _DraftOption(isCorrect: false),
    ];
  }

  @override
  void dispose() {
    _sourceLabelController.dispose();
    _stemController.dispose();
    for (final opt in _options) {
      opt.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_options.length < 6) {
      setState(() {
        _options.add(_DraftOption(isCorrect: false));
      });
    }
  }

  void _removeOption(int index) {
    if (_options.length > 2) {
      setState(() {
        final removed = _options.removeAt(index);
        final wasCorrect = removed.isCorrect;
        removed.dispose();
        if (wasCorrect && _options.isNotEmpty) {
          _options.first.isCorrect = true;
        }
      });
    }
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
      final optionsList = <Map<String, dynamic>>[];
      String correctAnswer = 'A';

      if (_questionType == 'multiple_choice') {
        for (int i = 0; i < _options.length; i++) {
          final key = String.fromCharCode(65 + i); // A, B, C, D...
          optionsList.add({
            'key': key,
            'text': _options[i].controller.text.trim(),
          });
          if (_options[i].isCorrect) {
            correctAnswer = key;
          }
        }
      } else if (_questionType == 'true_false') {
        optionsList.add({'key': 'A', 'text': 'True'});
        optionsList.add({'key': 'B', 'text': 'False'});
        correctAnswer = _trueFalseAnswer ? 'A' : 'B';
      }

      final stemText = _stemController.text.trim();

      final questionId = await context
          .read<QuestionBankCubit>()
          .createManualQuestion(
            sourceLabel: _sourceLabelController.text.trim(),
            questionType: _questionType,
            stemText: stemText,
            options: optionsList,
            correctAnswer: correctAnswer,
            rightsAttestation: {
              'claimed_source': 'teacher_authored',
              'license': 'teacher_owned',
              'attested_at': DateTime.now().toIso8601String(),
            },
            imageUrl: _imageUrl,
            imageMeta: _imageMeta,
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s20),
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
                                    value: 'true_false',
                                    child: Text(
                                      '${l10n.optionTrue} / ${l10n.optionFalse}',
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _questionType = val);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // Stem Text
                        TextFormField(
                          controller: _stemController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: (_imageUrl != null &&
                                    _imageUrl!.trim().isNotEmpty)
                                ? l10n.questionTextFieldOptional
                                : l10n.stemText,
                            hintText: (_imageUrl != null &&
                                    _imageUrl!.trim().isNotEmpty)
                                ? l10n.questionTextOptionalHint
                                : l10n.stemTextHint,
                            alignLabelWithHint: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          validator: (v) {
                            final hasImg = _imageUrl != null &&
                                _imageUrl!.trim().isNotEmpty;
                            if (!hasImg && (v == null || v.trim().isEmpty)) {
                              return 'Required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Image attachment box (with cropping & width chips)
                        ExamImageAttachmentBox(
                          initialImageUrl: _imageUrl,
                          initialImageMeta: _imageMeta,
                          onChanged: (data) {
                            setState(() {
                              _imageUrl = data.imageUrl;
                              _imageMeta = data.imageMeta;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // Options Section
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_questionType == 'multiple_choice') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                l10n.optionsLabel,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_options.length < 6)
                                TextButton.icon(
                                  onPressed: _addOption,
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: Text(l10n.addOption),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            l10n.tapToSelectAnswer,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          ..._options.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final opt = entry.value;
                            final key = String.fromCharCode(65 + idx);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Radio button for correct answer
                                  IconButton(
                                    icon: Icon(
                                      opt.isCorrect
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: opt.isCorrect
                                          ? AppColors.primary
                                          : AppColors.textMuted,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        for (final o in _options) {
                                          o.isCorrect = false;
                                        }
                                        opt.isCorrect = true;
                                      });
                                    },
                                  ),
                                  // Option letter badge
                                  Container(
                                    width: 32,
                                    height: 32,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: opt.isCorrect
                                          ? AppColors.primary.withValues(alpha: 0.12)
                                          : AppColors.surfaceVariant,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      key,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: opt.isCorrect
                                            ? AppColors.primary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s12),
                                  // Option text input
                                  Expanded(
                                    child: TextFormField(
                                      controller: opt.controller,
                                      decoration: InputDecoration(
                                        hintText: l10n.optionLetter(key),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Required'
                                              : null,
                                    ),
                                  ),
                                  if (_options.length > 2)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: AppColors.error,
                                        size: 20,
                                      ),
                                      onPressed: () => _removeOption(idx),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ] else if (_questionType == 'true_false') ...[
                          Text(
                            l10n.correctAnswer,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _trueFalseAnswer = true),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.s16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _trueFalseAnswer
                                          ? AppColors.primary.withValues(alpha: 0.1)
                                          : AppColors.surfaceVariant,
                                      border: Border.all(
                                        color: _trueFalseAnswer
                                            ? AppColors.primary
                                            : AppColors.border,
                                        width: _trueFalseAnswer ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _trueFalseAnswer
                                              ? Icons.check_circle_rounded
                                              : Icons.circle_outlined,
                                          color: _trueFalseAnswer
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          l10n.optionTrue,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: _trueFalseAnswer
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s16),
                              Expanded(
                                child: InkWell(
                                  onTap: () => setState(() => _trueFalseAnswer = false),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.s16,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !_trueFalseAnswer
                                          ? AppColors.primary.withValues(alpha: 0.1)
                                          : AppColors.surfaceVariant,
                                      border: Border.all(
                                        color: !_trueFalseAnswer
                                            ? AppColors.primary
                                            : AppColors.border,
                                        width: !_trueFalseAnswer ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          !_trueFalseAnswer
                                              ? Icons.check_circle_rounded
                                              : Icons.circle_outlined,
                                          color: !_trueFalseAnswer
                                              ? AppColors.primary
                                              : AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          l10n.optionFalse,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: !_trueFalseAnswer
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s20),

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
                  const SizedBox(height: AppSpacing.s24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: AppButton(
                      text: l10n.saveAndReview,
                      icon: Icons.check_circle_rounded,
                      isLoading: _isSubmitting,
                      onPressed: _submit,
                    ),
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
