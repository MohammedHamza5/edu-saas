import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../models/create_exam_draft_models.dart';
import 'create_exam_bottom_bar.dart';
import 'create_exam_draft_banner.dart';
import 'create_exam_general_settings_card.dart';
import 'create_exam_pdf_card.dart';
import 'create_exam_questions_list_section.dart';
import 'create_exam_questions_toolbar.dart';
import 'create_exam_score_summary_bar.dart';

/// Form body layout for the Create / Edit Exam page.
/// Encapsulates the scrollable form with draft banner, settings, PDF, summary, and questions list.
class CreateExamBody extends StatelessWidget {
  final ScrollController scrollController;
  final GlobalKey<FormState> formKey;
  final Map<String, dynamic>? savedDraftData;
  final VoidCallback onDiscardDraft;
  final VoidCallback onRestoreDraft;

  // General Settings
  final TextEditingController titleController;
  final TextEditingController durationController;
  final TextEditingController maxScoreController;
  final TextEditingController passingScoreController;
  final TextEditingController defaultPointsController;
  final bool isCreating;
  final bool shuffle;
  final bool showResult;
  final bool allowRetake;
  final bool isPublished;
  final bool saveToQuestionBank;
  final VoidCallback onApplyDefaultPoints;
  final ValueChanged<int> onDefaultPointsChanged;
  final ValueChanged<bool> onShuffleChanged;
  final ValueChanged<bool> onShowResultChanged;
  final ValueChanged<bool> onAllowRetakeChanged;
  final ValueChanged<bool> onIsPublishedChanged;
  final ValueChanged<bool> onSaveToQuestionBankChanged;
  final VoidCallback onMaxScoreChanged;

  // PDF
  final bool hasPdf;
  final bool isUploadingPdf;
  final String? attachedPdfFileName;
  final int? attachedPdfFileSize;
  final String? attachedPdfStoragePath;
  final VoidCallback onPickFromLibrary;
  final VoidCallback onPickFromDevice;
  final VoidCallback onPreviewPdf;
  final VoidCallback onRemovePdf;
  final VoidCallback onQuickBubbleSheet;

  // Score Summary & Toolbar
  final int questionsCount;
  final int totalQuestionsPoints;
  final int maxScoreNum;
  final VoidCallback onAutoAdjustMaxScore;
  final bool hasExpandedQuestions;
  final VoidCallback onToggleExpandCollapse;
  final VoidCallback onImportFromBank;
  final VoidCallback onBulkFillOptions;
  final VoidCallback onAddQuestion;

  // Questions List
  final List<CreateExamDraftQuestion> questions;
  final ValueChanged<int> onToggleExpanded;
  final ValueChanged<int> onRemoveQuestion;
  final void Function(int, Uint8List, String) onImagePicked;
  final VoidCallback onPointsChanged;
  final void Function(CreateExamDraftQuestion) onAddOption;
  final void Function(CreateExamDraftQuestion, int) onRemoveOption;
  final void Function(CreateExamDraftQuestion, List<String>) onQuickFillOptions;

  // Bottom Actions
  final bool isSubmitting;
  final bool isEditing;
  final VoidCallback onSubmit;

  const CreateExamBody({
    super.key,
    required this.scrollController,
    required this.formKey,
    required this.savedDraftData,
    required this.onDiscardDraft,
    required this.onRestoreDraft,
    required this.titleController,
    required this.durationController,
    required this.maxScoreController,
    required this.passingScoreController,
    required this.defaultPointsController,
    required this.isCreating,
    required this.shuffle,
    required this.showResult,
    required this.allowRetake,
    required this.isPublished,
    required this.saveToQuestionBank,
    required this.onApplyDefaultPoints,
    required this.onDefaultPointsChanged,
    required this.onShuffleChanged,
    required this.onShowResultChanged,
    required this.onAllowRetakeChanged,
    required this.onIsPublishedChanged,
    required this.onSaveToQuestionBankChanged,
    required this.onMaxScoreChanged,
    required this.hasPdf,
    required this.isUploadingPdf,
    required this.attachedPdfFileName,
    required this.attachedPdfFileSize,
    required this.attachedPdfStoragePath,
    required this.onPickFromLibrary,
    required this.onPickFromDevice,
    required this.onPreviewPdf,
    required this.onRemovePdf,
    required this.onQuickBubbleSheet,
    required this.questionsCount,
    required this.totalQuestionsPoints,
    required this.maxScoreNum,
    required this.onAutoAdjustMaxScore,
    required this.hasExpandedQuestions,
    required this.onToggleExpandCollapse,
    required this.onImportFromBank,
    required this.onBulkFillOptions,
    required this.onAddQuestion,
    required this.questions,
    required this.onToggleExpanded,
    required this.onRemoveQuestion,
    required this.onImagePicked,
    required this.onPointsChanged,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onQuickFillOptions,
    required this.isSubmitting,
    required this.isEditing,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s20,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (savedDraftData != null) ...[
              CreateExamDraftBanner(
                savedDraftData: savedDraftData,
                onDiscard: onDiscardDraft,
                onRestore: onRestoreDraft,
              ),
              const SizedBox(height: AppSpacing.s16),
            ],

            // 1. General Settings Card
            CreateExamGeneralSettingsCard(
              titleController: titleController,
              durationController: durationController,
              maxScoreController: maxScoreController,
              passingScoreController: passingScoreController,
              defaultPointsController: defaultPointsController,
              isCreating: isCreating,
              shuffle: shuffle,
              showResult: showResult,
              allowRetake: allowRetake,
              isPublished: isPublished,
              saveToQuestionBank: saveToQuestionBank,
              onApplyDefaultPoints: onApplyDefaultPoints,
              onDefaultPointsChanged: onDefaultPointsChanged,
              onShuffleChanged: onShuffleChanged,
              onShowResultChanged: onShowResultChanged,
              onAllowRetakeChanged: onAllowRetakeChanged,
              onIsPublishedChanged: onIsPublishedChanged,
              onSaveToQuestionBankChanged: onSaveToQuestionBankChanged,
              onMaxScoreChanged: onMaxScoreChanged,
            ),

            const SizedBox(height: AppSpacing.s20),

            // 2. Attached Exam Booklet (PDF) Card
            CreateExamPdfCard(
              hasPdf: hasPdf,
              isCreating: isCreating,
              isUploadingPdf: isUploadingPdf,
              attachedPdfFileName: attachedPdfFileName,
              attachedPdfFileSize: attachedPdfFileSize,
              attachedPdfStoragePath: attachedPdfStoragePath,
              onPickFromLibrary: onPickFromLibrary,
              onPickFromDevice: onPickFromDevice,
              onPreviewPdf: onPreviewPdf,
              onRemovePdf: onRemovePdf,
              onQuickBubbleSheet: onQuickBubbleSheet,
            ),

            const SizedBox(height: AppSpacing.s20),

            // 3. Score Balance & Summary Header
            CreateExamScoreSummaryBar(
              questionsCount: questionsCount,
              totalQuestionsPoints: totalQuestionsPoints,
              maxScoreNum: maxScoreNum,
              defaultPointsController: defaultPointsController,
              isCreating: isCreating,
              onAutoAdjustMaxScore: onAutoAdjustMaxScore,
              onDefaultPointsChanged: onDefaultPointsChanged,
              onApplyDefaultPoints: onApplyDefaultPoints,
            ),

            const SizedBox(height: AppSpacing.s20),

            // 4. Questions Section Header
            CreateExamQuestionsToolbar(
              questionsCount: questionsCount,
              isCreating: isCreating,
              hasExpandedQuestions: hasExpandedQuestions,
              onToggleExpandCollapse: onToggleExpandCollapse,
              onImportFromBank: onImportFromBank,
              onBulkFillOptions: onBulkFillOptions,
              onAddQuestion: onAddQuestion,
            ),
            const SizedBox(height: AppSpacing.s12),

            // 5. Questions List (Accordion Pattern)
            CreateExamQuestionsListSection(
              questions: questions,
              isCreating: isCreating,
              onToggleExpanded: onToggleExpanded,
              onRemove: onRemoveQuestion,
              onImagePicked: onImagePicked,
              onPointsChanged: onPointsChanged,
              onAddOption: onAddOption,
              onRemoveOption: onRemoveOption,
              onQuickFillOptions: onQuickFillOptions,
            ),

            // 6. Bottom Add Question Card and Submit/Publish Action Button
            CreateExamBottomBar(
              isCreating: isCreating,
              isSubmitting: isSubmitting,
              isEditing: isEditing,
              onAddQuestion: onAddQuestion,
              onSubmit: onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
