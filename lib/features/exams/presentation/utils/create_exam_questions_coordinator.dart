import 'package:flutter/material.dart';
import '../../../question_bank/domain/entities/question_revision_entity.dart';
import '../models/create_exam_draft_models.dart';
import 'create_exam_builder_helpers.dart';

/// Coordinator that encapsulates all question and option list mutations for the exam builder.
class CreateExamQuestionsCoordinator {
  CreateExamQuestionsCoordinator._();

  static void addQuestion({
    required List<CreateExamDraftQuestion> questions,
    required int defaultPoints,
    required void Function(CreateExamDraftQuestion) onBindListeners,
    ScrollController? scrollController,
  }) {
    for (final q in questions) {
      q.isExpanded = false;
    }
    final newQ = CreateExamDraftQuestion(
      isExpanded: true,
      initialPoints: defaultPoints,
    );
    onBindListeners(newQ);
    questions.add(newQ);

    if (scrollController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  static void removeQuestion({
    required List<CreateExamDraftQuestion> questions,
    required int index,
  }) {
    if (questions.length > 1 && index >= 0 && index < questions.length) {
      final removed = questions.removeAt(index);
      removed.dispose();
    }
  }

  static void collapseAll(List<CreateExamDraftQuestion> questions) {
    for (final q in questions) {
      q.isExpanded = false;
    }
  }

  static void expandAll(List<CreateExamDraftQuestion> questions) {
    for (final q in questions) {
      q.isExpanded = true;
    }
  }

  static void toggleExpanded(List<CreateExamDraftQuestion> questions, int index) {
    if (index >= 0 && index < questions.length) {
      questions[index].isExpanded = !questions[index].isExpanded;
    }
  }

  static void addOption({
    required CreateExamDraftQuestion question,
    required VoidCallback onScheduleAutoSave,
  }) {
    if (question.options.length < 6) {
      final opt = CreateExamDraftOption(isCorrect: false);
      opt.controller.addListener(onScheduleAutoSave);
      question.options.add(opt);
    }
  }

  static void removeOption({
    required CreateExamDraftQuestion question,
    required int optIdx,
  }) {
    if (question.options.length > 2 && optIdx >= 0 && optIdx < question.options.length) {
      final removed = question.options.removeAt(optIdx);
      final wasCorrect = removed.isCorrect;
      removed.dispose();
      if (wasCorrect && question.options.isNotEmpty) {
        question.options.first.isCorrect = true;
      }
    }
  }

  static void quickFillOptions({
    required CreateExamDraftQuestion question,
    required List<String> letters,
    required VoidCallback onScheduleAutoSave,
  }) {
    while (question.options.length < letters.length && question.options.length < 6) {
      final opt = CreateExamDraftOption(isCorrect: false);
      opt.controller.addListener(onScheduleAutoSave);
      question.options.add(opt);
    }
    for (int i = 0; i < question.options.length; i++) {
      if (i < letters.length) {
        question.options[i].controller.text = letters[i];
      }
    }
    if (!question.options.any((o) => o.isCorrect)) {
      question.options.first.isCorrect = true;
    }
  }

  static int bulkFillAll({
    required List<CreateExamDraftQuestion> questions,
    required String pattern,
    bool onlyEmpty = false,
  }) {
    return CreateExamBuilderHelpers.applyBulkPattern(
      questions: questions,
      pattern: pattern,
      onlyEmpty: onlyEmpty,
    );
  }

  static void importFromBank({
    required List<CreateExamDraftQuestion> questions,
    required List<QuestionRevisionEntity> revisions,
    required int defaultPoints,
    required void Function(CreateExamDraftQuestion) onBindListeners,
  }) {
    if (revisions.isEmpty) return;
    final imported = CreateExamBuilderHelpers.importQuestionsFromBank(
      revisions: revisions,
      defaultQuestionPoints: defaultPoints,
    );
    for (final draftQ in imported) {
      onBindListeners(draftQ);
      questions.add(draftQ);
    }

    if (questions.length > revisions.length &&
        questions.first.textController.text.trim().isEmpty &&
        questions.first.options.every((o) => o.controller.text.trim().isEmpty)) {
      final emptyQ = questions.removeAt(0);
      emptyQ.dispose();
    }
  }

  static void applyDefaultPoints({
    required List<CreateExamDraftQuestion> questions,
    required int points,
  }) {
    for (final q in questions) {
      q.points = points;
      q.pointsController.text = points.toString();
    }
  }

  static ({int maxScore, int passingScore}) calculateBalancedScores(int totalPoints) {
    final maxScore = totalPoints > 0 ? totalPoints : 0;
    final passingScore = (maxScore * 0.6).round();
    return (maxScore: maxScore, passingScore: passingScore);
  }
}
