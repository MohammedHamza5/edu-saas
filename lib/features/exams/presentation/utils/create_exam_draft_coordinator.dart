import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/exams_repository.dart';
import '../models/create_exam_draft_models.dart';

/// Coordinates debounced auto-saving, retrieving, and clearing of exam creation drafts.
class CreateExamDraftCoordinator {
  final ExamsRepository draftStorage;
  final String draftKey;
  Timer? _debounceTimer;

  CreateExamDraftCoordinator({
    required this.draftStorage,
    required this.draftKey,
  });

  /// Schedules a debounced auto-save after 1500ms of inactivity.
  void scheduleAutoSave({
    required bool isSubmitting,
    required Future<void> Function() onPersist,
  }) {
    _debounceTimer?.cancel();
    if (isSubmitting) return;

    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      onPersist();
    });
  }

  /// Persists serialized draft data to the underlying repository.
  Future<bool> persistDraft({
    required bool isSubmitting,
    required Map<String, dynamic> draftData,
  }) async {
    if (isSubmitting) return false;
    try {
      await draftStorage.saveExamDraft(draftKey: draftKey, data: draftData);
      return true;
    } catch (e) {
      debugPrint('Failed to save exam draft: $e');
      return false;
    }
  }

  /// Checks if a valid non-empty draft exists for the active exam draft key.
  Future<Map<String, dynamic>?> checkForSavedDraft() async {
    try {
      final draft = await draftStorage.getExamDraft(draftKey);
      if (draft == null) return null;

      final rawQuestions = draft['questions'] as List?;
      final hasQuestions = rawQuestions != null && rawQuestions.isNotEmpty;
      final title = draft['title'] as String? ?? '';

      if (hasQuestions || title.trim().isNotEmpty) {
        return draft;
      }
    } catch (e) {
      debugPrint('Failed to retrieve exam draft: $e');
    }
    return null;
  }

  /// Clears the draft from storage (e.g. after successful submission or explicit discard).
  Future<void> clearDraft() async {
    _debounceTimer?.cancel();
    try {
      await draftStorage.clearExamDraft(draftKey);
    } catch (e) {
      debugPrint('Failed to clear exam draft: $e');
    }
  }

  /// Disposes active timers.
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Evaluates whether the current form state contains any meaningful user inputs.
  static bool hasMeaningfulContent({
    required String title,
    required List<CreateExamDraftQuestion> questions,
  }) {
    final hasTitle = title.trim().isNotEmpty;
    final hasAnyQuestionText = questions.any((q) =>
        q.textController.text.trim().isNotEmpty ||
        q.imageUrl != null ||
        q.options.any((o) => o.controller.text.trim().isNotEmpty));
    return hasTitle || hasAnyQuestionText || questions.length > 1;
  }

  /// Disposes existing draft questions and repopulates the list with restored questions.
  static void restoreQuestions({
    required List<CreateExamDraftQuestion> targetQuestions,
    required List<CreateExamDraftQuestion> newQuestions,
    required void Function(CreateExamDraftQuestion) onBindListeners,
  }) {
    for (final q in targetQuestions) {
      q.dispose();
    }
    targetQuestions.clear();
    for (final q in newQuestions) {
      onBindListeners(q);
      targetQuestions.add(q);
    }
  }
}
