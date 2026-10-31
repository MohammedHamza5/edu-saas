import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/saved_question_entity.dart';
import '../cubit/exams_state.dart';

/// Helper to handle saving and removing questions to/from the student's question vault.
class ExamTakingVaultHelper {
  ExamTakingVaultHelper._();

  /// Toggles saving of the active exam question in the student vault.
  static Future<void> toggleQuestionVault({
    required BuildContext context,
    required ExamTakingState state,
    required Set<String> savedQuestionIds,
    required VoidCallback onStateChanged,
  }) async {
    final q = state.currentQuestion;
    final isSaved = savedQuestionIds.contains(q.id);

    if (isSaved) {
      savedQuestionIds.remove(q.id);
      onStateChanged();
      await InjectionContainer.savedQuestionsRepository.removeSavedQuestion(q.id);
      if (context.mounted) {
        AppFeedback.showInfo(context, context.l10n.removedFromVaultSuccess);
      }
    } else {
      savedQuestionIds.add(q.id);
      onStateChanged();
      final saved = SavedQuestionEntity(
        id: 'sq_${q.id}',
        questionId: q.id,
        examId: state.exam.id,
        examTitle: state.exam.title,
        questionText: q.questionText,
        questionImageUrl: q.imageUrl,
        options: q.options,
        savedAt: DateTime.now(),
        questionIndex: state.currentQuestionIndex + 1,
        isPdfQuestion: state.exam.hasAttachedPdf,
        pdfUrl: state.exam.pdfStoragePath,
      );
      await InjectionContainer.savedQuestionsRepository.saveQuestion(saved);
      if (context.mounted) {
        AppFeedback.showSuccess(context, context.l10n.savedToVaultSuccess);
      }
    }
  }
}
