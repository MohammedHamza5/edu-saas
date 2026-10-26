import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/responsive_container.dart';
import 'package:edu_saas/features/exams/domain/entities/exam_entity.dart';
import 'package:edu_saas/features/exams/domain/entities/saved_question_entity.dart';
import 'package:edu_saas/features/exams/presentation/cubit/saved_questions_cubit.dart';
import '../widgets/vault/smart_practice_stem_view.dart';
import '../widgets/vault/smart_practice_options_view.dart';
import '../widgets/vault/smart_practice_bottom_bar.dart';
import '../widgets/vault/smart_practice_completion_view.dart';

class SmartPracticePage extends StatefulWidget {
  final List<SavedQuestionEntity> questions;
  final int initialIndex;

  const SmartPracticePage({
    super.key,
    required this.questions,
    this.initialIndex = 0,
  });

  @override
  State<SmartPracticePage> createState() => _SmartPracticePageState();
}

class _SmartPracticePageState extends State<SmartPracticePage> {
  late int _currentIndex;
  String? _selectedOptionId;
  bool _isSubmitted = false;
  bool _isCompleted = false;
  int _reviewedInSession = 0;
  final Map<String, bool> _masteredMap = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.questions.isNotEmpty ? widget.questions.length - 1 : 0);
    for (final q in widget.questions) {
      _masteredMap[q.questionId] = q.isMastered;
    }
  }

  SavedQuestionEntity get _currentQuestion => widget.questions[_currentIndex];

  String? _resolveCorrectOptionId(SavedQuestionEntity q) {
    if (q.correctOptionId != null && q.correctOptionId!.isNotEmpty) {
      return q.correctOptionId;
    }
    return q.options
        .cast<QuestionOptionEntity?>()
        .firstWhere((QuestionOptionEntity? o) => o?.isCorrect == true, orElse: () => null)
        ?.id;
  }

  void _checkAnswer() {
    if (_selectedOptionId == null) return;
    setState(() => _isSubmitted = true);
  }

  void _rateDifficultyAndAdvance(QuestionDifficultyRating rating) {
    final qId = _currentQuestion.questionId;
    unawaited(context.read<SavedQuestionsCubit>().updateDifficulty(qId, rating));
    _reviewedInSession++;
    _nextQuestion();
  }

  void _nextQuestion() {
    if (_currentIndex < widget.questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionId = null;
        _isSubmitted = false;
      });
    } else {
      setState(() => _isCompleted = true);
    }
  }

  void _toggleMastered() {
    final qId = _currentQuestion.questionId;
    final current = _masteredMap[qId] ?? _currentQuestion.isMastered;
    final updated = !current;
    setState(() => _masteredMap[qId] = updated);
    unawaited(context.read<SavedQuestionsCubit>().markQuestionMastered(qId, isMastered: updated));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.l10n.emptyVaultTitle)),
      );
    }

    if (_isCompleted) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.practiceSessionTitle)),
        body: SmartPracticeCompletionView(
          totalReviewed: _reviewedInSession > 0 ? _reviewedInSession : widget.questions.length,
          onFinish: () => Navigator.of(context).pop(),
        ),
      );
    }

    final q = _currentQuestion;
    final correctId = _resolveCorrectOptionId(q);
    final isCorrect = _isSubmitted && correctId != null && _selectedOptionId == correctId;
    final isMastered = _masteredMap[q.questionId] ?? q.isMastered;
    final hasNext = _currentIndex < widget.questions.length - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          q.examTitle.isNotEmpty ? q.examTitle : context.l10n.practiceSessionTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        actions: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s10),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Center(
              child: Text(
                context.l10n.questionCounter(_currentIndex + 1, widget.questions.length),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: (_currentIndex + 1) / widget.questions.length,
            backgroundColor: AppColors.border.withValues(alpha: 0.4),
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            minHeight: 3,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SmartPracticeStemView(question: q, questionIndex: _currentIndex),
              const SizedBox(height: AppSpacing.s24),
              SmartPracticeOptionsView(
                options: q.options,
                selectedOptionId: _selectedOptionId,
                correctOptionId: correctId,
                isSubmitted: _isSubmitted,
                onSelectOption: (id) => setState(() => _selectedOptionId = id),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SmartPracticeBottomBar(
        isSubmitted: _isSubmitted,
        isCorrect: isCorrect,
        isMastered: isMastered,
        hasNext: hasNext,
        canCheck: _selectedOptionId != null,
        onCheck: _checkAnswer,
        onNext: _nextQuestion,
        onToggleMastered: _toggleMastered,
        onRateDifficulty: _rateDifficultyAndAdvance,
      ),
    );
  }
}
