import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';

class CreateExamPage extends StatefulWidget {
  final String groupId;
  final String? groupName;

  const CreateExamPage({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  State<CreateExamPage> createState() => _CreateExamPageState();
}

class _DraftQuestion {
  String text = '';
  QuestionType type = QuestionType.multipleChoice;
  int points = 5;
  List<({String text, bool isCorrect})> options = [
    (text: '', isCorrect: true),
    (text: '', isCorrect: false),
    (text: '', isCorrect: false),
    (text: '', isCorrect: false),
  ];
}

class _CreateExamPageState extends State<CreateExamPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _maxScoreController = TextEditingController(text: '100');
  final _passingScoreController = TextEditingController(text: '60');

  bool _shuffle = true;
  bool _showResult = true;
  bool _allowRetake = false;

  final List<_DraftQuestion> _questions = [
    _DraftQuestion(),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _maxScoreController.dispose();
    _passingScoreController.dispose();
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_DraftQuestion());
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        _questions.removeAt(index);
      });
    }
  }

  Future<void> _submitExam() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that each question has text and at least one correct option
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.fillQuestionTextError(i + 1)),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final hasCorrect = q.options.any((o) => o.isCorrect && o.text.trim().isNotEmpty);
      if (!hasCorrect) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.selectCorrectOptionError(i + 1)),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    final initialQuestions = _questions.asMap().entries.map((entry) {
      final idx = entry.key;
      final q = entry.value;

      final optionsList = q.options
          .where((o) => o.text.trim().isNotEmpty)
          .toList()
          .asMap()
          .entries
          .map((optEntry) {
        return QuestionOptionEntity(
          id: 'opt-${idx + 1}-${optEntry.key + 1}',
          questionId: 'q-${idx + 1}',
          optionText: optEntry.value.text.trim(),
          sortOrder: optEntry.key + 1,
          isCorrect: optEntry.value.isCorrect,
        );
      }).toList();

      return ExamQuestionEntity(
        id: 'q-${idx + 1}',
        examVersionId: '',
        questionText: q.text.trim(),
        questionType: q.type,
        points: q.points,
        sortOrder: idx + 1,
        options: optionsList,
      );
    }).toList();

    final success = await context.read<ExamsCubit>().createExam(
          groupId: widget.groupId,
          title: _titleController.text.trim(),
          durationMinutes: int.tryParse(_durationController.text.trim()) ?? 60,
          maxScore: int.tryParse(_maxScoreController.text.trim()) ?? 100,
          passingScore: int.tryParse(_passingScoreController.text.trim()),
          shuffleQuestions: _shuffle,
          showResult: _showResult,
          allowRetake: _allowRetake,
          initialQuestions: initialQuestions,
        );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.examBuiltAndPublishedSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.createExamTitle),
        centerTitle: true,
      ),
      body: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          final isCreating = state is TeacherExamsLoaded && state.isCreating;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General Settings Card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.examGeneralSettings,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        AppTextField(
                          controller: _titleController,
                          labelText: context.l10n.examTitleField,
                          hintText: context.l10n.examTitleHint,
                          prefixIcon: const Icon(Icons.assignment_outlined),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return context.l10n.examTitleRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s12),

                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _durationController,
                                labelText: context.l10n.durationMinutesField,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.timer_outlined),
                                validator: (v) {
                                  final num = int.tryParse(v ?? '');
                                  if (num == null || num <= 0) return context.l10n.positiveNumberRequired;
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: AppTextField(
                                controller: _maxScoreController,
                                labelText: context.l10n.maxScoreField,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.grade_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),

                        AppTextField(
                          controller: _passingScoreController,
                          labelText: context.l10n.passingScoreField,
                          hintText: '60',
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.verified_outlined),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // Toggles
                        SwitchListTile(
                          title: Text(context.l10n.shuffleQuestionsTitle),
                          subtitle: Text(context.l10n.shuffleQuestionsSubtitle),
                          value: _shuffle,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() => _shuffle = v),
                        ),
                        SwitchListTile(
                          title: Text(context.l10n.showResultTitle),
                          subtitle: Text(context.l10n.showResultSubtitle),
                          value: _showResult,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() => _showResult = v),
                        ),
                        SwitchListTile(
                          title: Text(context.l10n.allowRetakeTitle),
                          subtitle: Text(context.l10n.allowRetakeSubtitle),
                          value: _allowRetake,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() => _allowRetake = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s24),

                  // Questions Section Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.questionsSectionTitle(_questions.length),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addQuestion,
                        icon: const Icon(Icons.add_circle_outline),
                        label: Text(context.l10n.addQuestionAction),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // Questions List
                  ..._questions.asMap().entries.map((entry) {
                    final qIndex = entry.key;
                    final q = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s16),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  context.l10n.questionNumberTitle(qIndex + 1),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                if (_questions.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        color: AppColors.error),
                                    onPressed: () => _removeQuestion(qIndex),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s8),

                            TextFormField(
                              initialValue: q.text,
                              decoration: InputDecoration(
                                labelText: context.l10n.questionTextField,
                                hintText: context.l10n.questionTextHint,
                              ),
                              maxLines: 2,
                              onChanged: (v) => q.text = v,
                            ),
                            const SizedBox(height: AppSpacing.s12),

                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<QuestionType>(
                                    value: q.type,
                                    decoration: InputDecoration(
                                      labelText: context.l10n.questionTypeField,
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: QuestionType.multipleChoice,
                                        child: Text(QuestionType.multipleChoice.localizedLabel(context)),
                                      ),
                                      DropdownMenuItem(
                                        value: QuestionType.trueFalse,
                                        child: Text(QuestionType.trueFalse.localizedLabel(context)),
                                      ),
                                    ],
                                    onChanged: (t) {
                                      if (t != null) {
                                        setState(() {
                                          q.type = t;
                                          if (t == QuestionType.trueFalse) {
                                            q.options = [
                                              (text: context.l10n.optionTrue, isCorrect: true),
                                              (text: context.l10n.optionFalse, isCorrect: false),
                                            ];
                                          } else {
                                            q.options = [
                                              (text: '', isCorrect: true),
                                              (text: '', isCorrect: false),
                                              (text: '', isCorrect: false),
                                              (text: '', isCorrect: false),
                                            ];
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s12),
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    initialValue: q.points.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: context.l10n.pointsField,
                                    ),
                                    onChanged: (v) {
                                      q.points = int.tryParse(v) ?? 1;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s16),

                            Text(
                              context.l10n.optionsSelectCorrectPrompt,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s8),

                            ...q.options.asMap().entries.map((optEntry) {
                              final optIdx = optEntry.key;
                              final opt = optEntry.value;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                                child: Row(
                                  children: [
                                    Radio<int>(
                                      value: optIdx,
                                      groupValue: q.options.indexWhere((o) => o.isCorrect),
                                      activeColor: AppColors.success,
                                      onChanged: (_) {
                                        setState(() {
                                          for (int i = 0; i < q.options.length; i++) {
                                            q.options[i] = (
                                              text: q.options[i].text,
                                              isCorrect: i == optIdx,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: TextFormField(
                                        initialValue: opt.text,
                                        readOnly: q.type == QuestionType.trueFalse,
                                        decoration: InputDecoration(
                                          hintText: context.l10n.optionNumberHint(optIdx + 1),
                                          isDense: true,
                                        ),
                                        onChanged: (v) {
                                          q.options[optIdx] = (
                                            text: v,
                                            isCorrect: opt.isCorrect,
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: AppSpacing.s24),

                  AppButton(
                    text: context.l10n.saveAndPublishExam,
                    icon: Icons.publish_outlined,
                    onPressed: isCreating ? null : _submitExam,
                    isLoading: isCreating,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
