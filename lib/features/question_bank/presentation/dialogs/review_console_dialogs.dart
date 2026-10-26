import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../domain/entities/question_revision_entity.dart';
import '../../domain/entities/validation_issue_entity.dart';
import '../cubit/question_bank_cubit.dart';

/// Modal dialogs and confirmation sheets for Question Bank Review interactions.
abstract final class ReviewConsoleDialogs {
  static void showIssueAcknowledgmentDialog(
    BuildContext context,
    ValidationIssueEntity issue,
  ) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${l10n.confirmIssueDialogTitle}: ${issue.ruleId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue.getLocalizedMessage(locale)),
            const SizedBox(height: 12),
            Text(
              l10n.confirmIssuePrompt,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancelAction),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<QuestionBankCubit>().acknowledgeIssue(issue.id);
            },
            child: Text(l10n.acknowledgeIssueAction),
          ),
        ],
      ),
    );
  }

  static void showBlockEditDialog(
    BuildContext context,
    String blockId,
    String initialValue,
  ) {
    final l10n = context.l10n;
    final isCropPath = initialValue.startsWith('crops/');
    final textController = TextEditingController(
      text: isCropPath ? '' : initialValue,
    );
    String selectedReason = 'ocr_error';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${l10n.editBlockDialogTitle} [$blockId]'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: l10n.blockContentLabel,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                decoration: InputDecoration(
                  labelText: l10n.editReasonLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'ocr_error',
                    child: Text(l10n.ocrErrorCorrection),
                  ),
                  DropdownMenuItem(
                    value: 'source_image_correction',
                    child: Text(l10n.sourceImageCorrection),
                  ),
                  DropdownMenuItem(
                    value: 'source_typo_fix',
                    child: Text(l10n.sourceTypoFix),
                  ),
                  DropdownMenuItem(
                    value: 'teacher_answer_confirmation',
                    child: Text(l10n.teacherAnswerConfirmation),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedReason = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.cancelAction),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                Navigator.pop(dialogCtx);
                context.read<QuestionBankCubit>().editBlock(
                  blockId: blockId,
                  newValue: text,
                  reason: selectedReason,
                );
              },
              child: Text(l10n.saveNewRevision),
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog to edit the complete question stem text.
  static void showStemEditDialog(
    BuildContext context,
    QuestionRevisionEntity rev,
  ) {
    final allText = rev.stemBlocks
        .where((Map<String, dynamic> b) => (b['type'] ?? 'text') == 'text')
        .map((Map<String, dynamic> b) => b['value']?.toString() ?? '')
        .join('\n')
        .trim();

    final firstBlock = rev.stemBlocks.isNotEmpty
        ? rev.stemBlocks[0]['id']?.toString() ?? 'stem_1'
        : 'stem_1';

    showBlockEditDialog(context, firstBlock, allText);
  }

  static void confirmMerge(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmMergeDialogTitle),
        content: Text(l10n.confirmMergeDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<QuestionBankCubit>().mergeWithNext();
            },
            child: Text(l10n.mergeAction),
          ),
        ],
      ),
    );
  }

  static void confirmSplit(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmSplitDialogTitle),
        content: Text(l10n.confirmSplitDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<QuestionBankCubit>().splitQuestion(splitIndex: 1);
            },
            child: Text(l10n.splitAction),
          ),
        ],
      ),
    );
  }

  static void confirmMarkUnreadable(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmUnreadableDialogTitle),
        content: Text(l10n.confirmUnreadableDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<QuestionBankCubit>().markSourceUnreadable(
                reason: 'Source unreadable/truncated',
              );
            },
            child: Text(l10n.quarantineAction),
          ),
        ],
      ),
    );
  }
}
