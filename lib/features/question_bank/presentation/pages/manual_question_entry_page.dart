import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../exams/presentation/widgets/exam_image_attachment_box.dart';
import '../cubit/question_bank_cubit.dart';
import '../widgets/manual_question_options_section.dart';

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

  late List<DraftOption> _options;

  @override
  void initState() {
    super.initState();
    _options = [
      DraftOption(isCorrect: true),
      DraftOption(isCorrect: false),
      DraftOption(isCorrect: false),
      DraftOption(isCorrect: false),
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
        _options.add(DraftOption(isCorrect: false));
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
                                initialValue: _questionType,
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
                  ManualQuestionOptionsSection(
                    questionType: _questionType,
                    options: _options,
                    trueFalseAnswer: _trueFalseAnswer,
                    onAddOption: _addOption,
                    onRemoveOption: _removeOption,
                    onSelectCorrectOption: (idx) {
                      setState(() {
                        for (final o in _options) {
                          o.isCorrect = false;
                        }
                        _options[idx].isCorrect = true;
                      });
                    },
                    onSelectTrueFalse: (val) =>
                        setState(() => _trueFalseAnswer = val),
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
        );
  }
}
