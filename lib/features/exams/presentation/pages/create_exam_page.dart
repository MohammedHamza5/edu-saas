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

class _DraftOption {
  final TextEditingController controller;
  bool isCorrect;

  _DraftOption({String text = '', this.isCorrect = false})
      : controller = TextEditingController(text: text);

  void dispose() {
    controller.dispose();
  }
}

class _DraftQuestion {
  final TextEditingController textController = TextEditingController();
  final TextEditingController pointsController = TextEditingController(text: '5');
  QuestionType type = QuestionType.multipleChoice;
  int points = 5;
  bool trueFalseAnswer = true; // true = OptionTrue is correct, false = OptionFalse is correct
  late List<_DraftOption> options;

  _DraftQuestion() {
    options = [
      _DraftOption(isCorrect: true),
      _DraftOption(isCorrect: false),
      _DraftOption(isCorrect: false),
      _DraftOption(isCorrect: false),
    ];
  }

  void dispose() {
    textController.dispose();
    pointsController.dispose();
    for (final opt in options) {
      opt.dispose();
    }
  }
}

class _CreateExamPageState extends State<CreateExamPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _maxScoreController = TextEditingController(text: '20');
  final _passingScoreController = TextEditingController(text: '12');

  bool _shuffle = true;
  bool _showResult = true;
  bool _allowRetake = false;

  final ScrollController _scrollController = ScrollController();

  final List<_DraftQuestion> _questions = [
    _DraftQuestion(),
  ];

  int get _totalQuestionsPoints =>
      _questions.fold(0, (sum, q) => sum + q.points);

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    _durationController.dispose();
    _maxScoreController.dispose();
    _passingScoreController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_DraftQuestion());
      _autoUpdateMaxScoreIfBalanced();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        final removed = _questions.removeAt(index);
        removed.dispose();
        _autoUpdateMaxScoreIfBalanced();
      });
    }
  }

  void _autoUpdateMaxScoreIfBalanced() {
    final currentSum = _totalQuestionsPoints;
    if (currentSum > 0) {
      _maxScoreController.text = currentSum.toString();
      _passingScoreController.text = (currentSum * 0.6).round().toString();
    }
  }

  void _addOptionToQuestion(_DraftQuestion q) {
    if (q.options.length < 6) {
      setState(() {
        q.options.add(_DraftOption(isCorrect: false));
      });
    }
  }

  void _removeOptionFromQuestion(_DraftQuestion q, int optIdx) {
    if (q.options.length > 2) {
      setState(() {
        final removed = q.options.removeAt(optIdx);
        final wasCorrect = removed.isCorrect;
        removed.dispose();
        if (wasCorrect && q.options.isNotEmpty) {
          q.options.first.isCorrect = true;
        }
      });
    }
  }

  Future<void> _submitExam() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that each question has text and at least one correct option
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      if (q.textController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.fillQuestionTextError(i + 1)),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (q.type == QuestionType.multipleChoice) {
        final filledOptions = q.options.where((o) => o.controller.text.trim().isNotEmpty).toList();
        if (filledOptions.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.atLeastTwoOptionsRequired),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        final hasCorrect = q.options.any((o) => o.isCorrect && o.controller.text.trim().isNotEmpty);
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
    }

    final initialQuestions = _questions.asMap().entries.map((entry) {
      final idx = entry.key;
      final q = entry.value;

      List<QuestionOptionEntity> optionsList;

      if (q.type == QuestionType.trueFalse) {
        // True/False options: explicitly defined
        optionsList = [
          QuestionOptionEntity(
            id: 'opt-${idx + 1}-1',
            questionId: 'q-${idx + 1}',
            optionText: context.l10n.optionTrue,
            sortOrder: 1,
            isCorrect: q.trueFalseAnswer == true,
          ),
          QuestionOptionEntity(
            id: 'opt-${idx + 1}-2',
            questionId: 'q-${idx + 1}',
            optionText: context.l10n.optionFalse,
            sortOrder: 2,
            isCorrect: q.trueFalseAnswer == false,
          ),
        ];
      } else {
        // Multiple choice options
        optionsList = q.options
            .where((o) => o.controller.text.trim().isNotEmpty)
            .toList()
            .asMap()
            .entries
            .map((optEntry) {
          return QuestionOptionEntity(
            id: 'opt-${idx + 1}-${optEntry.key + 1}',
            questionId: 'q-${idx + 1}',
            optionText: optEntry.value.controller.text.trim(),
            sortOrder: optEntry.key + 1,
            isCorrect: optEntry.value.isCorrect,
          );
        }).toList();
      }

      return ExamQuestionEntity(
        id: 'q-${idx + 1}',
        examVersionId: '',
        questionText: q.textController.text.trim(),
        questionType: q.type,
        points: q.points,
        sortOrder: idx + 1,
        options: optionsList,
      );
    }).toList();

    final createdExam = await context.read<ExamsCubit>().createExam(
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

    if (!mounted) return;

    if (createdExam != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.examBuiltAndPublishedSuccess),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(createdExam);
    } else {
      final state = context.read<ExamsCubit>().state;
      String errorMsg = 'Failed';
      if (state is TeacherExamsLoaded && state.message != null) {
        errorMsg = state.message!;
      } else if (state is ExamsError) {
        errorMsg = state.message;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.examPublishFailed(errorMsg)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(context.l10n.createExamTitle),
            if (widget.groupName != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.groupName!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
      ),
      floatingActionButton: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          final isCreating = (state is TeacherExamsLoaded && state.isCreating) ||
              state is ExamsLoading;
          if (isCreating) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _addQuestion,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              context.l10n.addQuestionAction,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      body: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          final isCreating = (state is TeacherExamsLoaded && state.isCreating) ||
              state is ExamsLoading;

          final maxScoreNum = int.tryParse(_maxScoreController.text.trim()) ?? 0;
          final isPointsMismatched = maxScoreNum > 0 && maxScoreNum != _totalQuestionsPoints;

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s20,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. General Settings Card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.s8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Text(
                              context.l10n.examGeneralSettings,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s20),

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
                        const SizedBox(height: AppSpacing.s16),

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
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: AppTextField(
                                controller: _passingScoreController,
                                labelText: context.l10n.passingScoreField,
                                keyboardType: TextInputType.number,
                                prefixIcon: const Icon(Icons.verified_outlined),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: AppSpacing.s12),

                        // Toggles
                        SwitchListTile(
                          title: Text(
                            context.l10n.shuffleQuestionsTitle,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            context.l10n.shuffleQuestionsSubtitle,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          value: _shuffle,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: isCreating ? null : (v) => setState(() => _shuffle = v),
                        ),
                        SwitchListTile(
                          title: Text(
                            context.l10n.showResultTitle,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            context.l10n.showResultSubtitle,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          value: _showResult,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: isCreating ? null : (v) => setState(() => _showResult = v),
                        ),
                        SwitchListTile(
                          title: Text(
                            context.l10n.allowRetakeTitle,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            context.l10n.allowRetakeSubtitle,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                          value: _allowRetake,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: isCreating ? null : (v) => setState(() => _allowRetake = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // 2. Score Balance & Summary Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(
                        color: isPointsMismatched ? AppColors.warning.withValues(alpha: 0.5) : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                              ),
                              child: Text(
                                context.l10n.totalQuestionsSummary(_questions.length),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Text(
                              context.l10n.totalPointsSummary(_totalQuestionsPoints, maxScoreNum),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isPointsMismatched ? AppColors.warning : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (isPointsMismatched)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _maxScoreController.text = _totalQuestionsPoints.toString();
                                _passingScoreController.text = (_totalQuestionsPoints * 0.6).round().toString();
                              });
                            },
                            icon: const Icon(Icons.sync_alt_rounded, size: 16, color: AppColors.warning),
                            label: Text(
                              context.l10n.autoAdjustMaxScore(_totalQuestionsPoints),
                              style: const TextStyle(fontSize: 12, color: AppColors.warning),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // 3. Questions Section Header
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
                      ElevatedButton.icon(
                        onPressed: isCreating ? null : _addQuestion,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text(context.l10n.addQuestionAction),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // 4. Questions List
                  ..._questions.asMap().entries.map((entry) {
                    final qIndex = entry.key;
                    final q = entry.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.s20),
                      child: AppCard(
                        padding: const EdgeInsets.all(AppSpacing.s20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question header: Number, points chip, and delete
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                      ),
                                      child: Text(
                                        context.l10n.questionNumberTitle(qIndex + 1),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceVariant,
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: Text(
                                        '${q.points} ${context.l10n.pointsField}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_questions.length > 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.error,
                                      size: 20,
                                    ),
                                    tooltip: context.l10n.removeOption,
                                    onPressed: isCreating ? null : () => _removeQuestion(qIndex),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s16),

                            // Question Text
                            TextFormField(
                              controller: q.textController,
                              decoration: InputDecoration(
                                labelText: context.l10n.questionTextField,
                                hintText: context.l10n.questionTextHint,
                                alignLabelWithHint: true,
                              ),
                              maxLines: 2,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return context.l10n.fillQuestionTextError(qIndex + 1);
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.s16),

                            // Question Type and Points Row
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<QuestionType>(
                                    value: q.type,
                                    decoration: InputDecoration(
                                      labelText: context.l10n.questionTypeField,
                                      prefixIcon: Icon(
                                        q.type == QuestionType.trueFalse
                                            ? Icons.rule_rounded
                                            : Icons.list_alt_rounded,
                                      ),
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
                                    onChanged: isCreating
                                        ? null
                                        : (t) {
                                            if (t != null) {
                                              setState(() {
                                                q.type = t;
                                              });
                                            }
                                          },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s12),
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    controller: q.pointsController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: context.l10n.pointsField,
                                      prefixIcon: const Icon(Icons.stars_outlined),
                                    ),
                                    onChanged: (v) {
                                      setState(() {
                                        q.points = int.tryParse(v) ?? 1;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s20),

                            // 5. Options Area (True/False or Multiple Choice)
                            if (q.type == QuestionType.trueFalse)
                              _buildTrueFalseSelector(q, isCreating)
                            else
                              _buildMultipleChoiceOptions(q, isCreating),
                          ],
                        ),
                      ),
                    );
                  }),

                  // Bottom Add Question Card Button
                  InkWell(
                    onTap: isCreating ? null : _addQuestion,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s10),
                          Text(
                            context.l10n.addQuestionAction,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s24),

                  // Bottom Publish Action Button
                  AppButton(
                    text: context.l10n.saveAndPublishExam,
                    icon: Icons.publish_rounded,
                    isFullWidth: true,
                    onPressed: isCreating ? null : _submitExam,
                    isLoading: isCreating,
                  ),
                  const SizedBox(height: 80), // Clearance for FloatingActionButton
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Builds modern interactive True/False choice selector
  Widget _buildTrueFalseSelector(_DraftQuestion q, bool isCreating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(
              context.l10n.selectCorrectAnswerPrompt,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _buildTrueFalseChoiceCard(
                label: context.l10n.optionTrue,
                isTrue: true,
                isSelected: q.trueFalseAnswer == true,
                onTap: isCreating
                    ? null
                    : () {
                        setState(() {
                          q.trueFalseAnswer = true;
                        });
                      },
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: _buildTrueFalseChoiceCard(
                label: context.l10n.optionFalse,
                isTrue: false,
                isSelected: q.trueFalseAnswer == false,
                onTap: isCreating
                    ? null
                    : () {
                        setState(() {
                          q.trueFalseAnswer = false;
                        });
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrueFalseChoiceCard({
    required String label,
    required bool isTrue,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isTrue
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1))
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: isSelected
                ? (isTrue ? AppColors.success : AppColors.error)
                : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isTrue ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isTrue ? AppColors.success : AppColors.error,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? (isTrue ? AppColors.success : AppColors.error)
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isTrue ? AppColors.success : AppColors.error).withValues(alpha: 0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Text(
                isSelected ? context.l10n.correctAnswerBadge : '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isTrue ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds Multiple Choice options list with addition/deletion and correct option radio
  Widget _buildMultipleChoiceOptions(_DraftQuestion q, bool isCreating) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.optionsSelectCorrectPrompt,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (q.options.length < 6)
              TextButton.icon(
                onPressed: isCreating ? null : () => _addOptionToQuestion(q),
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.l10n.addOption),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),

        ...q.options.asMap().entries.map((optEntry) {
          final optIdx = optEntry.key;
          final opt = optEntry.value;
          final letter = optIdx < letters.length ? letters[optIdx] : '${optIdx + 1}';

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: opt.isCorrect ? AppColors.success.withValues(alpha: 0.05) : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: opt.isCorrect ? AppColors.success.withValues(alpha: 0.6) : AppColors.border,
                  width: opt.isCorrect ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<int>(
                    value: optIdx,
                    groupValue: q.options.indexWhere((o) => o.isCorrect),
                    activeColor: AppColors.success,
                    onChanged: isCreating
                        ? null
                        : (_) {
                            setState(() {
                              for (int i = 0; i < q.options.length; i++) {
                                q.options[i].isCorrect = (i == optIdx);
                              }
                            });
                          },
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: opt.isCorrect
                          ? AppColors.success
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: opt.isCorrect ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: TextFormField(
                      controller: opt.controller,
                      decoration: InputDecoration(
                        hintText: context.l10n.optionLetter(letter),
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  if (opt.isCorrect)
                    Container(
                      margin: const EdgeInsets.only(left: 8, right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: Text(
                        context.l10n.correctAnswerBadge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  if (q.options.length > 2)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                      tooltip: context.l10n.removeOption,
                      onPressed: isCreating ? null : () => _removeOptionFromQuestion(q, optIdx),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
