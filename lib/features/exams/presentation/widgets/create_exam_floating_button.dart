import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';

/// Floating action button to quickly add a new question to the exam.
class CreateExamFloatingButton extends StatelessWidget {
  final bool isCreating;
  final VoidCallback onAddQuestion;

  const CreateExamFloatingButton({
    super.key,
    required this.isCreating,
    required this.onAddQuestion,
  });

  @override
  Widget build(BuildContext context) {
    if (isCreating) return const SizedBox.shrink();

    return FloatingActionButton.extended(
      onPressed: onAddQuestion,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        context.l10n.addQuestionAction,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}
