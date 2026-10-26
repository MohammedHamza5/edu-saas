import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/create_exam_draft_models.dart';
import 'create_exam_question_card.dart';

/// Renders the accordion list of exam questions.
class CreateExamQuestionsListSection extends StatelessWidget {
  final List<CreateExamDraftQuestion> questions;
  final bool isCreating;
  final void Function(int qIndex) onToggleExpanded;
  final void Function(int qIndex) onRemove;
  final void Function(int qIndex, Uint8List bytes, String filename) onImagePicked;
  final VoidCallback onPointsChanged;
  final void Function(CreateExamDraftQuestion q) onAddOption;
  final void Function(CreateExamDraftQuestion q, int optIdx) onRemoveOption;
  final void Function(CreateExamDraftQuestion q, List<String> letters) onQuickFillOptions;

  const CreateExamQuestionsListSection({
    super.key,
    required this.questions,
    required this.isCreating,
    required this.onToggleExpanded,
    required this.onRemove,
    required this.onImagePicked,
    required this.onPointsChanged,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onQuickFillOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int qIndex = 0; qIndex < questions.length; qIndex++)
          CreateExamQuestionCard(
            key: ValueKey(questions[qIndex]),
            qIndex: qIndex,
            q: questions[qIndex],
            isCreating: isCreating,
            canDelete: questions.length > 1,
            onToggleExpanded: () => onToggleExpanded(qIndex),
            onRemove: () => onRemove(qIndex),
            onImagePicked: (bytes, filename) =>
                onImagePicked(qIndex, bytes, filename),
            onPointsChanged: onPointsChanged,
            onAddOption: () => onAddOption(questions[qIndex]),
            onRemoveOption: (optIdx) =>
                onRemoveOption(questions[qIndex], optIdx),
            onQuickFillOptions: (letters) =>
                onQuickFillOptions(questions[qIndex], letters),
          ),
      ],
    );
  }
}
