import 'dart:typed_data';
import '../../../../core/utils/app_logger.dart';
import '../../../question_bank/domain/entities/question_revision_entity.dart';
import '../../../question_bank/domain/repositories/question_bank_repository.dart';
import '../../domain/services/exam_image_uploader.dart';
import '../../domain/entities/exam_entity.dart';
import '../models/create_exam_draft_models.dart';

/// Helper utility for creating, transforming, and syncing exam questions.
class CreateExamBuilderHelpers {
  CreateExamBuilderHelpers._();

  /// Converts draft questions into domain [ExamQuestionEntity] list for persistence.
  static List<ExamQuestionEntity> buildExamQuestionsFromDraft({
    required List<CreateExamDraftQuestion> questions,
    required String optionTrueText,
    required String optionFalseText,
  }) {
    return questions.asMap().entries.map((entry) {
      final idx = entry.key;
      final q = entry.value;

      List<QuestionOptionEntity> optionsList;

      if (q.type == QuestionType.trueFalse) {
        optionsList = [
          QuestionOptionEntity(
            id: 'opt-${idx + 1}-1',
            questionId: 'q-${idx + 1}',
            optionText: optionTrueText,
            sortOrder: 1,
            isCorrect: q.trueFalseAnswer == true,
          ),
          QuestionOptionEntity(
            id: 'opt-${idx + 1}-2',
            questionId: 'q-${idx + 1}',
            optionText: optionFalseText,
            sortOrder: 2,
            isCorrect: q.trueFalseAnswer == false,
          ),
        ];
      } else {
        const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
        final textFilled = q.options
            .where((o) =>
                o.controller.text.trim().isNotEmpty || o.imageUrl != null)
            .toList();

        final effectiveDraftOptions =
            (textFilled.length >= 2) ? textFilled : q.options;

        optionsList = effectiveDraftOptions.asMap().entries.map((optEntry) {
          final optIdx = optEntry.key;
          final opt = optEntry.value;
          final letter =
              optIdx < letters.length ? letters[optIdx] : '${optIdx + 1}';
          final effectiveText = opt.controller.text.trim().isNotEmpty
              ? opt.controller.text.trim()
              : letter;

          return QuestionOptionEntity(
            id: 'opt-${idx + 1}-${optIdx + 1}',
            questionId: 'q-${idx + 1}',
            optionText: effectiveText,
            sortOrder: optIdx + 1,
            isCorrect: opt.isCorrect,
            imageUrl: opt.imageUrl,
            imageMeta: opt.imageMeta,
          );
        }).toList();

        if (optionsList.isNotEmpty &&
            !optionsList.any((o) => o.isCorrect == true)) {
          final first = optionsList.first;
          optionsList[0] = QuestionOptionEntity(
            id: first.id,
            questionId: first.questionId,
            optionText: first.optionText,
            sortOrder: first.sortOrder,
            isCorrect: true,
            imageUrl: first.imageUrl,
            imageMeta: first.imageMeta,
          );
        }
      }

      final hasImage = (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ||
          (q.localImageBytes != null);
      final qText = q.textController.text.trim();
      final finalQuestionText = qText.isEmpty && hasImage ? ' ' : qText;

      return ExamQuestionEntity(
        id: 'q-${idx + 1}',
        examVersionId: '',
        questionText: finalQuestionText,
        questionType: q.type,
        points: q.points,
        sortOrder: idx + 1,
        options: optionsList,
        imageUrl: q.imageUrl,
        imageMeta: q.imageMeta,
        contextId: q.contextId,
      );
    }).toList();
  }

  /// Syncs finalized exam questions to Question Bank in background.
  static void syncQuestionsToBank({
    required List<CreateExamDraftQuestion> questions,
    required String examTitle,
    required QuestionBankRepository qbRepo,
  }) {
    final title = examTitle.trim().isEmpty ? 'Exam' : examTitle.trim();

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final optionsList = <Map<String, dynamic>>[];
      String correctAnswer = 'A';

      if (q.type == QuestionType.multipleChoice) {
        for (int optIdx = 0; optIdx < q.options.length; optIdx++) {
          final key = String.fromCharCode(65 + optIdx);
          optionsList.add({
            'key': key,
            'text': q.options[optIdx].controller.text.trim(),
          });
          if (q.options[optIdx].isCorrect) {
            correctAnswer = key;
          }
        }
      } else {
        optionsList.add({'key': 'A', 'text': 'True'});
        optionsList.add({'key': 'B', 'text': 'False'});
        correctAnswer = q.trueFalseAnswer ? 'A' : 'B';
      }

      final stemText = q.textController.text.trim();
      final sourceLabel = '$title-Q${i + 1}';

      qbRepo
          .createManualQuestion(
        sourceLabel: sourceLabel,
        questionType: q.type == QuestionType.trueFalse
            ? 'true_false'
            : 'multiple_choice',
        stemText: stemText,
        options: optionsList,
        correctAnswer: correctAnswer,
        rightsAttestation: {
          'claimed_source': 'exam_builder',
          'license': 'teacher_owned',
          'attested_at': DateTime.now().toIso8601String(),
        },
        imageUrl: q.imageUrl,
        imageMeta: q.imageMeta,
      )
          .catchError((Object err) {
        AppLogger.w('CreateExamPage',
            'Could not sync question ${i + 1} to question bank: $err');
        return '';
      });
    }
  }

  /// Parses revisions imported from Question Bank into draft question models.
  static List<CreateExamDraftQuestion> importQuestionsFromBank({
    required List<QuestionRevisionEntity> revisions,
    required int defaultQuestionPoints,
  }) {
    final imported = <CreateExamDraftQuestion>[];
    for (final rev in revisions) {
      final draftQ = CreateExamDraftQuestion(
        isExpanded: false,
        initialPoints: defaultQuestionPoints,
      );
      draftQ.textController.text = rev.stemText;
      draftQ.imageUrl = rev.imageUrl;
      draftQ.imageMeta = rev.imageMeta;

      if (rev.options.isNotEmpty) {
        draftQ.type = QuestionType.multipleChoice;
        draftQ.options.clear();

        final correctKey = rev.answerKey?.trim().toUpperCase();
        for (final opt in rev.options) {
          final key = opt['key']?.toString().toUpperCase() ?? '';
          String optText = '';
          final contentList = opt['content'];
          if (contentList is List && contentList.isNotEmpty) {
            final first = contentList.first;
            if (first is Map) {
              optText = first['latex']?.toString() ??
                  first['value']?.toString() ??
                  '';
            }
          }
          if (optText.isEmpty) {
            optText = opt['text']?.toString() ?? '';
          }
          final isCorrect = (correctKey != null && correctKey == key);
          draftQ.options.add(CreateExamDraftOption(
            text: optText,
            isCorrect: isCorrect,
          ));
        }
        if (draftQ.options.isNotEmpty &&
            !draftQ.options.any((o) => o.isCorrect)) {
          draftQ.options.first.isCorrect = true;
        }
      } else {
        draftQ.type = QuestionType.multipleChoice;
      }
      imported.add(draftQ);
    }
    return imported;
  }

  /// Fills question options automatically based on specified letter pattern.
  static int applyBulkPattern({
    required List<CreateExamDraftQuestion> questions,
    required String pattern,
    required bool onlyEmpty,
  }) {
    int updatedCount = 0;
    for (int qIdx = 0; qIdx < questions.length; qIdx++) {
      final q = questions[qIdx];
      if (q.type != QuestionType.multipleChoice) continue;

      if (onlyEmpty) {
        final isAnyFilled =
            q.options.any((o) => o.controller.text.trim().isNotEmpty);
        if (isAnyFilled) continue;
      }

      List<String> letters;
      if (pattern == 'act') {
        letters =
            (qIdx % 2 == 0) ? ['A', 'B', 'C', 'D'] : ['F', 'G', 'H', 'J'];
      } else if (pattern == 'ar') {
        letters = ['أ', 'ب', 'ج', 'د'];
      } else {
        letters = ['A', 'B', 'C', 'D'];
      }

      while (q.options.length < letters.length && q.options.length < 6) {
        q.options.add(CreateExamDraftOption(isCorrect: false));
      }

      for (int i = 0; i < q.options.length; i++) {
        if (i < letters.length) {
          q.options[i].controller.text = letters[i];
        }
      }
      if (!q.options.any((o) => o.isCorrect)) {
        q.options.first.isCorrect = true;
      }
      updatedCount++;
    }
    return updatedCount;
  }

  /// Converts existing exam questions from domain model into draft questions for editing.
  static List<CreateExamDraftQuestion> loadDraftQuestionsFromExistingExam(
    List<ExamQuestionEntity> existingQuestions,
  ) {
    final list = <CreateExamDraftQuestion>[];
    for (int i = 0; i < existingQuestions.length; i++) {
      final eq = existingQuestions[i];
      final dq = CreateExamDraftQuestion(isExpanded: i == 0);
      dq.textController.text = eq.questionText.trim();
      dq.pointsController.text = eq.points.toString();
      dq.points = eq.points;
      dq.type = eq.questionType;
      dq.imageUrl = eq.imageUrl;
      dq.localImageBytes = null;
      dq.imageMeta = eq.imageMeta;
      dq.contextId = eq.contextId;

      if (eq.questionType == QuestionType.trueFalse) {
        final correctOpt =
            eq.options.where((o) => o.isCorrect == true).firstOrNull ??
                eq.options.firstOrNull;
        dq.trueFalseAnswer = correctOpt != null &&
            (correctOpt.optionText == 'True' || correctOpt.optionText == 'صح');
      } else {
        for (final opt in dq.options) {
          opt.dispose();
        }
        dq.options = eq.options.map((opt) {
          final dOpt = CreateExamDraftOption(
            text: opt.optionText,
            isCorrect: opt.isCorrect ?? false,
          );
          dOpt.imageUrl = opt.imageUrl;
          dOpt.imageMeta = opt.imageMeta;
          return dOpt;
        }).toList();
        if (dq.options.isEmpty) {
          dq.options = [
            CreateExamDraftOption(isCorrect: true),
            CreateExamDraftOption(isCorrect: false),
          ];
        }
      }
      list.add(dq);
    }
    return list;
  }

  /// Generates a standardized bubble sheet question list.
  static List<CreateExamDraftQuestion> generateBubbleSheetDraftQuestions({
    required int questionCount,
    required int optionsCount,
    required int points,
  }) {
    const optionLetters = ['A', 'B', 'C', 'D', 'E'];
    final list = <CreateExamDraftQuestion>[];

    for (int i = 1; i <= questionCount; i++) {
      final dq = CreateExamDraftQuestion(
        isExpanded: i == 1,
        initialPoints: points,
        initialText: 'Question $i',
      );
      for (final opt in dq.options) {
        opt.dispose();
      }
      dq.options = List.generate(optionsCount, (idx) {
        final letter =
            idx < optionLetters.length ? optionLetters[idx] : '${idx + 1}';
        return CreateExamDraftOption(
          text: letter,
          isCorrect: idx == 0,
        );
      });
      list.add(dq);
    }
    return list;
  }

  /// Validates questions before submission. Returns an error message if invalid, or null if valid.
  static String? validateQuestions({
    required List<CreateExamDraftQuestion> questions,
    required String Function(int index) fillQuestionTextError,
    required String atLeastTwoOptionsRequired,
    required String Function(int index) selectCorrectOptionError,
  }) {
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final hasImage = (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ||
          (q.localImageBytes != null);
      if (q.textController.text.trim().isEmpty && !hasImage) {
        return fillQuestionTextError(i + 1);
      }

      if (q.type == QuestionType.multipleChoice) {
        final filledOptions = q.options
            .where((o) =>
                o.controller.text.trim().isNotEmpty || o.imageUrl != null)
            .toList();
        final isImageBasedQuestion =
            (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ||
                (q.localImageBytes != null);
        if (filledOptions.length < 2 &&
            (!isImageBasedQuestion || q.options.length < 2)) {
          return atLeastTwoOptionsRequired;
        }

        final hasCorrect = q.options.any((o) => o.isCorrect);
        if (!hasCorrect) {
          return selectCorrectOptionError(i + 1);
        }
      }
    }
    return null;
  }

  /// Uploads a question background image and manages loading / completion state.
  static void uploadQuestionImage({
    required CreateExamDraftQuestion q,
    required int qIndex,
    required Uint8List bytes,
    required String filename,
    required ExamImageUploader uploadService,
    required void Function() onStateChanged,
    required void Function(String error) onError,
  }) {
    q.localImageBytes = bytes;
    q.imageUrl = null;
    q.isUploadingImage = true;
    q.uploadError = null;
    onStateChanged();

    final uploadFuture = uploadService.uploadExamImage(
      bytes: Uint8List.fromList(bytes),
      fileName: filename,
      mimeType: 'image/png',
    );

    q.uploadFuture = uploadFuture;

    uploadFuture.then((uploadedUrl) {
      AppLogger.s(
        'CreateExamPage',
        '📸 Question ${qIndex + 1} background image upload succeeded: $uploadedUrl',
      );
      q.imageUrl = uploadedUrl;
      q.isUploadingImage = false;
      q.uploadError = null;
      onStateChanged();
    }).catchError((Object error, StackTrace stackTrace) {
      AppLogger.e(
        'CreateExamPage',
        '❌ Question ${qIndex + 1} background image upload failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      q.isUploadingImage = false;
      q.uploadError = error.toString();
      onStateChanged();
      onError(error.toString());
    });
  }

  /// Awaits any in-flight background image uploads. Returns true if successful or none pending, false on error.
  static Future<bool> awaitPendingUploads(
    List<CreateExamDraftQuestion> questions,
  ) async {
    final pending = questions
        .where((q) => q.isUploadingImage && q.uploadFuture != null)
        .toList();
    if (pending.isEmpty) return true;
    try {
      await Future.wait(pending.map((q) => q.uploadFuture!));
      return true;
    } catch (e) {
      AppLogger.e('CreateExamBuilderHelpers', 'Pending upload error: $e');
      return false;
    }
  }
}
