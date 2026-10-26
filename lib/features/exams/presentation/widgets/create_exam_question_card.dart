import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';
import '../models/create_exam_draft_models.dart';
import 'create_exam_multiple_choice_section.dart';
import 'create_exam_question_collapsed_card.dart';
import 'create_exam_true_false_section.dart';
import 'exam_image_attachment_box.dart';
import '../extensions/exam_ui_extensions.dart';

class CreateExamQuestionCard extends StatefulWidget {
  final int qIndex;
  final CreateExamDraftQuestion q;
  final bool isCreating;
  final bool canDelete;
  final VoidCallback onToggleExpanded;
  final VoidCallback onRemove;
  final void Function(Uint8List bytes, String filename)? onImagePicked;
  final VoidCallback? onPointsChanged;
  final VoidCallback? onAddOption;
  final ValueChanged<int>? onRemoveOption;
  final ValueChanged<List<String>>? onQuickFillOptions;

  const CreateExamQuestionCard({
    super.key,
    required this.qIndex,
    required this.q,
    required this.isCreating,
    required this.canDelete,
    required this.onToggleExpanded,
    required this.onRemove,
    this.onImagePicked,
    this.onPointsChanged,
    this.onAddOption,
    this.onRemoveOption,
    this.onQuickFillOptions,
  });

  @override
  State<CreateExamQuestionCard> createState() => _CreateExamQuestionCardState();
}

class _CreateExamQuestionCardState extends State<CreateExamQuestionCard> {
  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final qIndex = widget.qIndex;
    final isCreating = widget.isCreating;

    if (!q.isExpanded) {
      return CreateExamQuestionCollapsedCard(
        qIndex: qIndex,
        q: q,
        isCreating: isCreating,
        canDelete: widget.canDelete,
        onToggleExpanded: widget.onToggleExpanded,
        onRemove: widget.onRemove,
      );
    }

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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
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
                Row(
                  children: [
                    if (widget.canDelete)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        tooltip: context.l10n.removeOption,
                        onPressed: isCreating ? null : widget.onRemove,
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.expand_less_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      tooltip: context.l10n.collapseAllQuestions,
                      onPressed: widget.onToggleExpanded,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),

            // Question Text
            TextFormField(
              controller: q.textController,
              decoration: InputDecoration(
                labelText: ((q.imageUrl != null &&
                            q.imageUrl!.trim().isNotEmpty) ||
                        (q.localImageBytes != null))
                    ? context.l10n.questionTextFieldOptional
                    : context.l10n.questionTextField,
                hintText: ((q.imageUrl != null &&
                            q.imageUrl!.trim().isNotEmpty) ||
                        (q.localImageBytes != null))
                    ? context.l10n.questionTextOptionalHint
                    : context.l10n.questionTextHint,
                alignLabelWithHint: true,
              ),
              maxLines: 2,
              validator: (v) {
                final hasImg = (q.imageUrl != null &&
                        q.imageUrl!.trim().isNotEmpty) ||
                    (q.localImageBytes != null);
                if (!hasImg && (v == null || v.trim().isEmpty)) {
                  return context.l10n.fillQuestionTextError(qIndex + 1);
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s12),

            // Question Image / Screenshot Attachment Box
            ExamImageAttachmentBox(
              initialImageUrl: q.imageUrl,
              initialLocalBytes: q.localImageBytes,
              initialImageMeta: q.imageMeta,
              isUploading: q.isUploadingImage,
              uploadError: q.uploadError,
              onRetryUpload: q.localImageBytes != null
                  ? () => widget.onImagePicked?.call(
                        q.localImageBytes!,
                        'question_${qIndex + 1}.png',
                      )
                  : null,
              onBytesSelected: (bytes, filename) {
                widget.onImagePicked?.call(bytes, filename);
              },
              onChanged: (data) {
                AppLogger.i(
                  'CreateExamPage',
                  'Question ${qIndex + 1} image updated: url=${data.imageUrl}, meta=${data.imageMeta}',
                );
                setState(() {
                  q.imageUrl = data.imageUrl;
                  q.imageMeta = data.imageMeta;
                  if (data.localBytes != null) {
                    q.localImageBytes = data.localBytes;
                  } else if (data.imageUrl == null) {
                    q.localImageBytes = null;
                    q.uploadFuture = null;
                    q.isUploadingImage = false;
                    q.uploadError = null;
                  }
                });
              },
            ),
            const SizedBox(height: AppSpacing.s16),

            // Question Type & Points Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<QuestionType>(
                    value: q.type,
                    decoration: InputDecoration(
                      labelText: context.l10n.questionTypeField,
                      prefixIcon: const Icon(Icons.category_outlined),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: QuestionType.multipleChoice,
                        child: Text(
                          QuestionType.multipleChoice.localizedLabel(context),
                        ),
                      ),
                      DropdownMenuItem(
                        value: QuestionType.trueFalse,
                        child: Text(
                          QuestionType.trueFalse.localizedLabel(context),
                        ),
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
                        widget.onPointsChanged?.call();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),

            // Options Area (True/False or Multiple Choice)
            if (q.type == QuestionType.trueFalse)
              CreateExamTrueFalseSection(
                trueFalseAnswer: q.trueFalseAnswer,
                isCreating: isCreating,
                onChanged: (val) {
                  setState(() {
                    q.trueFalseAnswer = val;
                  });
                },
              )
            else
              CreateExamMultipleChoiceSection(
                options: q.options,
                isCreating: isCreating,
                onOptionCorrectChanged: (optIdx) {
                  setState(() {
                    for (int i = 0; i < q.options.length; i++) {
                      q.options[i].isCorrect = (i == optIdx);
                    }
                  });
                },
                onAddOption: () {
                  widget.onAddOption?.call();
                  setState(() {});
                },
                onRemoveOption: (optIdx) {
                  widget.onRemoveOption?.call(optIdx);
                  setState(() {});
                },
                onQuickFill: (letters) {
                  widget.onQuickFillOptions?.call(letters);
                  setState(() {});
                },
              ),
          ],
        ),
      ),
    );
  }
}
