import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../question_bank/domain/entities/question_revision_entity.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/repositories/exams_repository.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../dialogs/quick_bubble_sheet_dialog.dart';
import '../models/create_exam_draft_models.dart';
import '../utils/create_exam_builder_helpers.dart';
import '../utils/create_exam_draft_coordinator.dart';
import '../utils/create_exam_pdf_helper.dart';
import '../utils/create_exam_submission_coordinator.dart';
import '../utils/no_op_exams_repository.dart';
import '../widgets/bulk_fill_options_sheet.dart';
import '../widgets/create_exam_app_bar.dart';
import '../widgets/create_exam_bottom_bar.dart';
import '../widgets/create_exam_draft_banner.dart';
import '../widgets/create_exam_floating_button.dart';
import '../widgets/create_exam_general_settings_card.dart';
import '../widgets/create_exam_pdf_card.dart';
import '../widgets/create_exam_questions_list_section.dart';
import '../widgets/create_exam_questions_toolbar.dart';
import '../widgets/create_exam_score_summary_bar.dart';
import '../widgets/question_bank_picker_sheet.dart';

class CreateExamPage extends StatefulWidget {
  final String? groupId;
  final String? groupName;
  final String? initialTitle;
  final ExamEntity? existingExam;
  final ExamsRepository? examsRepository;

  const CreateExamPage({
    super.key,
    this.groupId,
    this.groupName,
    this.initialTitle,
    this.existingExam,
    this.examsRepository,
  });

  @override
  State<CreateExamPage> createState() => _CreateExamPageState();
}

typedef _DraftOption = CreateExamDraftOption;
typedef _DraftQuestion = CreateExamDraftQuestion;

class _CreateExamPageState extends State<CreateExamPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _durationController = TextEditingController(text: '60');
  final _maxScoreController = TextEditingController(text: '20');
  final _passingScoreController = TextEditingController(text: '12');
  int _defaultQuestionPoints = 5;
  final _defaultPointsController = TextEditingController(text: '5');

  bool _shuffle = true;
  bool _showResult = true;
  bool _allowRetake = false;
  bool _isPublished = false;
  bool _saveToQuestionBank = true;
  bool _isSubmitting = false;
  String? _savedExamId;

  String? _attachedPdfFileId;
  String? _attachedPdfFileName;
  int? _attachedPdfFileSize;
  String? _attachedPdfStoragePath;
  bool _clearPdfOnSave = false;
  bool _isUploadingPdf = false;

  final ScrollController _scrollController = ScrollController();
  ExamsRepository? _resolvedRepo;
  ExamsRepository get _uploadService {
    if (widget.examsRepository != null) return widget.examsRepository!;
    if (_resolvedRepo != null) return _resolvedRepo!;
    try {
      _resolvedRepo = InjectionContainer.examsRepository;
      return _resolvedRepo!;
    } catch (_) {
      return NoOpExamsRepository();
    }
  }

  late final CreateExamDraftCoordinator _draftCoordinator;
  Map<String, dynamic>? _savedDraftData;
  bool _isAutoSaved = false;

  String get _draftKey => widget.existingExam != null
      ? 'edit_${widget.existingExam!.id}'
      : 'new_${widget.groupId ?? "general"}';

  final List<_DraftQuestion> _questions = [_DraftQuestion(isExpanded: true)];

  int get _totalQuestionsPoints =>
      _questions.fold(0, (sum, q) => sum + q.points);

  @override
  void initState() {
    super.initState();

    _draftCoordinator = CreateExamDraftCoordinator(
      draftStorage: _uploadService,
      draftKey: _draftKey,
    );

    for (final c in [
      _titleController,
      _durationController,
      _maxScoreController,
      _passingScoreController,
      _defaultPointsController,
    ]) {
      c.addListener(_scheduleAutoSave);
    }

    if (widget.existingExam != null) {
      final ex = widget.existingExam!;
      _titleController.text = ex.title;
      _durationController.text = ex.durationMinutes.toString();
      _maxScoreController.text = ex.maxScore.toString();
      if (ex.passingScore != null) {
        _passingScoreController.text = ex.passingScore.toString();
      }
      _shuffle = ex.shuffleQuestions;
      _showResult = ex.showResult;
      _allowRetake = ex.allowRetake;
      _isPublished = ex.isPublished;
      _attachedPdfFileId = ex.pdfFileId;
      _attachedPdfFileName = ex.pdfFileName;
      _attachedPdfFileSize = ex.pdfFileSize;
      _attachedPdfStoragePath = ex.pdfStoragePath;

      final existingQuestions = ex.activeVersion?.questions;
      if (existingQuestions != null && existingQuestions.isNotEmpty) {
        _defaultQuestionPoints = existingQuestions.first.points;
        _defaultPointsController.text =
            existingQuestions.first.points.toString();
        for (final q in _questions) {
          q.dispose();
        }
        _questions.clear();
        _questions.addAll(
          CreateExamBuilderHelpers.loadDraftQuestionsFromExistingExam(
            existingQuestions,
          ),
        );
      }
    } else if (widget.initialTitle != null &&
        widget.initialTitle!.trim().isNotEmpty) {
      _titleController.text = widget.initialTitle!.trim();
    }

    for (final q in _questions) {
      _bindQuestionListeners(q);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForSavedDraft();
    });
  }

  @override
  void dispose() {
    _draftCoordinator.dispose();
    for (final c in [
      _titleController,
      _durationController,
      _defaultPointsController,
      _maxScoreController,
      _passingScoreController,
    ]) {
      c.removeListener(_scheduleAutoSave);
      c.dispose();
    }
    for (final q in _questions) {
      q.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _bindQuestionListeners(_DraftQuestion q) {
    q.textController.addListener(_scheduleAutoSave);
    q.pointsController.addListener(_scheduleAutoSave);
    for (final opt in q.options) {
      opt.controller.addListener(_scheduleAutoSave);
    }
  }

  void _scheduleAutoSave() {
    _draftCoordinator.scheduleAutoSave(
      isSubmitting: _isSubmitting,
      onPersist: _persistDraft,
    );
  }

  Future<void> _persistDraft() async {
    if (!mounted || _isSubmitting) return;

    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasAnyQuestionText = _questions.any((q) =>
        q.textController.text.trim().isNotEmpty ||
        q.imageUrl != null ||
        q.options.any((o) => o.controller.text.trim().isNotEmpty));
    final hasMultipleQuestions = _questions.length > 1;

    if (!hasTitle && !hasAnyQuestionText && !hasMultipleQuestions) {
      return;
    }

    final draftData = CreateExamDraftSerializer.serialize(
      title: _titleController.text,
      duration: _durationController.text,
      maxScore: _maxScoreController.text,
      passingScore: _passingScoreController.text,
      defaultPoints: _defaultPointsController.text,
      shuffle: _shuffle,
      showResult: _showResult,
      allowRetake: _allowRetake,
      isPublished: _isPublished,
      saveToQuestionBank: _saveToQuestionBank,
      pdfFileId: _attachedPdfFileId,
      pdfFileName: _attachedPdfFileName,
      pdfFileSize: _attachedPdfFileSize,
      pdfStoragePath: _attachedPdfStoragePath,
      questions: _questions,
    );

    final saved = await _draftCoordinator.persistDraft(
      isSubmitting: _isSubmitting,
      draftData: draftData,
    );
    if (saved && mounted) {
      setState(() {
        _isAutoSaved = true;
      });
    }
  }

  Future<void> _checkForSavedDraft() async {
    if (!mounted) return;
    final draft = await _draftCoordinator.checkForSavedDraft();
    if (draft != null && mounted) {
      setState(() {
        _savedDraftData = draft;
      });
    }
  }

  void _restoreDraft() {
    if (_savedDraftData == null) return;
    final v = CreateExamDraftSerializer.deserialize(_savedDraftData!);

    setState(() {
      if (v.title != null && v.title!.isNotEmpty) {
        _titleController.text = v.title!;
      }
      if (v.duration != null) _durationController.text = v.duration!;
      if (v.maxScore != null) _maxScoreController.text = v.maxScore!;
      if (v.passingScore != null) {
        _passingScoreController.text = v.passingScore!;
      }
      if (v.defaultPoints != null) {
        _defaultPointsController.text = v.defaultPoints!;
        _defaultQuestionPoints =
            int.tryParse(v.defaultPoints!) ?? _defaultQuestionPoints;
      }
      if (v.shuffle != null) _shuffle = v.shuffle!;
      if (v.showResult != null) _showResult = v.showResult!;
      if (v.allowRetake != null) _allowRetake = v.allowRetake!;
      if (v.isPublished != null) _isPublished = v.isPublished!;
      if (v.saveToQuestionBank != null) {
        _saveToQuestionBank = v.saveToQuestionBank!;
      }
      if (v.pdfFileId != null) {
        _attachedPdfFileId = v.pdfFileId;
        _attachedPdfFileName = v.pdfFileName;
        _attachedPdfFileSize = v.pdfFileSize;
        _attachedPdfStoragePath = v.pdfStoragePath;
        _clearPdfOnSave = false;
      }

      if (v.questions != null && v.questions!.isNotEmpty) {
        for (final q in _questions) {
          q.dispose();
        }
        _questions.clear();
        for (final q in v.questions!) {
          _bindQuestionListeners(q);
          _questions.add(q);
        }
      }

      _savedDraftData = null;
      _autoUpdateMaxScoreIfBalanced();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.examDraftRestoredSuccess),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _discardDraft() {
    _draftCoordinator.clearDraft();
    setState(() {
      _savedDraftData = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.examDraftDiscardedSuccess),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleQuestionImagePicked(
    int qIndex,
    Uint8List bytes,
    String filename,
  ) {
    if (qIndex < 0 || qIndex >= _questions.length) return;
    CreateExamBuilderHelpers.uploadQuestionImage(
      q: _questions[qIndex],
      qIndex: qIndex,
      bytes: bytes,
      filename: filename,
      uploadService: _uploadService,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onError: (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.imageUploadFailed(err)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
    );
  }

  void _addQuestion() {
    setState(() {
      for (final q in _questions) {
        q.isExpanded = false;
      }
      final newQ = _DraftQuestion(
        isExpanded: true,
        initialPoints: _defaultQuestionPoints,
      );
      _bindQuestionListeners(newQ);
      _questions.add(newQ);
      _autoUpdateMaxScoreIfBalanced();
      _scheduleAutoSave();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _collapseAllQuestions() {
    setState(() {
      for (final q in _questions) {
        q.isExpanded = false;
      }
    });
  }

  void _expandAllQuestions() {
    setState(() {
      for (final q in _questions) {
        q.isExpanded = true;
      }
    });
  }

  void _toggleQuestionExpanded(int index) {
    setState(() {
      _questions[index].isExpanded = !_questions[index].isExpanded;
    });
  }

  void _removeQuestion(int index) {
    if (_questions.length > 1) {
      setState(() {
        final removed = _questions.removeAt(index);
        removed.dispose();
        _autoUpdateMaxScoreIfBalanced();
        _scheduleAutoSave();
      });
    }
  }

  Future<void> _openQuestionBankPicker() async {
    final importedRevisions = await QuestionBankPickerSheet.show(context);
    if (importedRevisions != null && importedRevisions.isNotEmpty && mounted) {
      _importQuestionsFromBank(importedRevisions);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.questionsImportedSuccess(importedRevisions.length),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _importQuestionsFromBank(List<QuestionRevisionEntity> revisions) {
    if (revisions.isEmpty) return;
    final imported = CreateExamBuilderHelpers.importQuestionsFromBank(
      revisions: revisions,
      defaultQuestionPoints: _defaultQuestionPoints,
    );
    setState(() {
      for (final draftQ in imported) {
        _bindQuestionListeners(draftQ);
        _questions.add(draftQ);
      }

      // If the first question was just an empty default draft, remove it
      if (_questions.length > revisions.length &&
          _questions.first.textController.text.trim().isEmpty &&
          _questions.first.options
              .every((o) => o.controller.text.trim().isEmpty)) {
        final emptyQ = _questions.removeAt(0);
        emptyQ.dispose();
      }

      _autoUpdateMaxScoreIfBalanced();
      _scheduleAutoSave();
    });
  }

  void _applyDefaultPointsToAllQuestions() {
    final pts = int.tryParse(_defaultPointsController.text.trim());
    if (pts == null || pts <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.invalidPointsError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _defaultQuestionPoints = pts;
      for (final q in _questions) {
        q.points = pts;
        q.pointsController.text = pts.toString();
      }
      _autoUpdateMaxScoreIfBalanced();
      _scheduleAutoSave();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.pointsAppliedToAllSuccess(
            pts,
            _questions.length,
          ),
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _autoUpdateMaxScoreIfBalanced() {
    final currentSum = _totalQuestionsPoints;
    if (currentSum > 0) {
      _maxScoreController.text = currentSum.toString();
      _passingScoreController.text = (currentSum * 0.6).round().toString();
    }
  }

  void _addOptionToQuestion(_DraftQuestion q) {
    if (q.options.length < 6) {
      final opt = _DraftOption(isCorrect: false);
      opt.controller.addListener(_scheduleAutoSave);
      setState(() {
        q.options.add(opt);
      });
      _scheduleAutoSave();
    }
  }

  void _removeOptionFromQuestion(_DraftQuestion q, int optIdx) {
    if (q.options.length > 2) {
      setState(() {
        final removed = q.options.removeAt(optIdx);
        final wasCorrect = removed.isCorrect;
        removed.dispose();
        if (wasCorrect && q.options.isNotEmpty) {
          q.options.first.isCorrect = true;
        }
      });
      _scheduleAutoSave();
    }
  }

  void _quickFillQuestionOptions(_DraftQuestion q, List<String> letters) {
    setState(() {
      while (q.options.length < letters.length && q.options.length < 6) {
        final opt = _DraftOption(isCorrect: false);
        opt.controller.addListener(_scheduleAutoSave);
        q.options.add(opt);
      }
      for (int i = 0; i < q.options.length; i++) {
        if (i < letters.length) {
          q.options[i].controller.text = letters[i];
        }
      }
      if (!q.options.any((o) => o.isCorrect)) {
        q.options.first.isCorrect = true;
      }
    });
    _scheduleAutoSave();
  }

  void _bulkFillAllQuestions(String pattern, {bool onlyEmpty = false}) {
    final updatedCount = CreateExamBuilderHelpers.applyBulkPattern(
      questions: _questions,
      pattern: pattern,
      onlyEmpty: onlyEmpty,
    );
    setState(() {});
    _scheduleAutoSave();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.optionsAutoFilledSuccess(updatedCount)),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showBulkFillOptionsSheet() {
    BulkFillOptionsSheet.show(
      context,
      onSelectPattern: (pattern, {required bool onlyEmpty}) {
        _bulkFillAllQuestions(pattern, onlyEmpty: onlyEmpty);
      },
    );
  }

  Future<void> _submitExam() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final resultExam = await CreateExamSubmissionCoordinator.submit(
        context: context,
        cubit: context.read<ExamsCubit>(),
        targetExamId: widget.existingExam?.id ?? _savedExamId,
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        durationText: _durationController.text.trim(),
        maxScoreText: _maxScoreController.text.trim(),
        passingScoreText: _passingScoreController.text.trim(),
        shuffle: _shuffle,
        showResult: _showResult,
        allowRetake: _allowRetake,
        isPublished: _isPublished,
        saveToQuestionBank: _saveToQuestionBank,
        clearPdfOnSave: _clearPdfOnSave,
        attachedPdfFileId: _attachedPdfFileId,
        questions: _questions,
        onClearDraft: () => _draftCoordinator.clearDraft(),
      );

      if (resultExam != null && mounted) {
        _savedExamId = resultExam.id;
        Navigator.of(context).pop(resultExam);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _applyAttachedPdf(AttachedPdfResult result) {
    setState(() {
      _attachedPdfFileId = result.id;
      _attachedPdfFileName = result.fileName;
      _attachedPdfFileSize = result.fileSize;
      _attachedPdfStoragePath = result.storagePath;
      _clearPdfOnSave = false;
    });
    _scheduleAutoSave();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.pdfAttachedSuccess),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _pickPdfFromLibrary() async {
    final result = await CreateExamPdfHelper.pickPdfFromLibrary(context);
    if (result != null && mounted) {
      _applyAttachedPdf(result);
    }
  }

  Future<void> _pickPdfFromDevice() async {
    try {
      final result = await CreateExamPdfHelper.pickPdfFromDevice(
        onUploadStateChanged: (isUploading) {
          if (mounted) setState(() => _isUploadingPdf = isUploading);
        },
      );
      if (result != null && mounted) {
        _applyAttachedPdf(result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _removeAttachedPdf() {
    setState(() {
      _attachedPdfFileId = null;
      _attachedPdfFileName = null;
      _attachedPdfFileSize = null;
      _attachedPdfStoragePath = null;
      _clearPdfOnSave = true;
    });
    _scheduleAutoSave();
  }

  void _previewAttachedPdf() {
    CreateExamPdfHelper.previewAttachedPdf(
      context: context,
      storagePath: _attachedPdfStoragePath,
      fileName: _attachedPdfFileName,
      fileId: _attachedPdfFileId,
      fileSize: _attachedPdfFileSize,
      tenantId: widget.existingExam?.tenantId,
    );
  }

  Future<void> _showQuickBubbleSheetDialog() async {
    final result = await showDialog<QuickBubbleSheetResult>(
      context: context,
      builder: (ctx) => QuickBubbleSheetDialog(
        initialPoints: _defaultQuestionPoints,
        hasExistingQuestions: _questions.isNotEmpty &&
            _questions.any((q) => q.textController.text.isNotEmpty),
      ),
    );
    if (result == null || !mounted) return;

    for (final q in _questions) {
      q.dispose();
    }
    _questions.clear();

    final bubbleQuestions =
        CreateExamBuilderHelpers.generateBubbleSheetDraftQuestions(
      questionCount: result.questionCount,
      optionsCount: result.optionsCount,
      points: result.points,
    );
    for (final dq in bubbleQuestions) {
      _bindQuestionListeners(dq);
      _questions.add(dq);
    }

    final totalScore = result.questionCount * result.points;
    _maxScoreController.text = totalScore.toString();
    _passingScoreController.text = (totalScore * 0.6).round().toString();
    _defaultQuestionPoints = result.points;
    _defaultPointsController.text = result.points.toString();

    setState(() {});
    _scheduleAutoSave();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${context.l10n.generateQuestions}: ${result.questionCount}'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CreateExamAppBar(
        isEditing: widget.existingExam != null,
        groupName: widget.groupName,
        isAutoSaved: _isAutoSaved,
      ),
      floatingActionButton: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          final isCreating =
              (state is TeacherExamsLoaded && state.isCreating) ||
                  state is ExamsLoading;
          return CreateExamFloatingButton(
            isCreating: isCreating,
            onAddQuestion: _addQuestion,
          );
        },
      ),
      body: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          final isCreating = (state is TeacherExamsLoaded && state.isCreating) ||
              state is ExamsLoading;

          final maxScoreNum =
              int.tryParse(_maxScoreController.text.trim()) ?? 0;

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s20,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_savedDraftData != null) ...[
                    CreateExamDraftBanner(
                      savedDraftData: _savedDraftData,
                      onDiscard: _discardDraft,
                      onRestore: _restoreDraft,
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],

                  // 1. General Settings Card
                  CreateExamGeneralSettingsCard(
                    titleController: _titleController,
                    durationController: _durationController,
                    maxScoreController: _maxScoreController,
                    passingScoreController: _passingScoreController,
                    defaultPointsController: _defaultPointsController,
                    isCreating: isCreating,
                    shuffle: _shuffle,
                    showResult: _showResult,
                    allowRetake: _allowRetake,
                    isPublished: _isPublished,
                    saveToQuestionBank: _saveToQuestionBank,
                    onApplyDefaultPoints: _applyDefaultPointsToAllQuestions,
                    onDefaultPointsChanged: (pts) =>
                        _defaultQuestionPoints = pts,
                    onShuffleChanged: (v) => setState(() => _shuffle = v),
                    onShowResultChanged: (v) => setState(() => _showResult = v),
                    onAllowRetakeChanged: (v) =>
                        setState(() => _allowRetake = v),
                    onIsPublishedChanged: (v) =>
                        setState(() => _isPublished = v),
                    onSaveToQuestionBankChanged: (v) =>
                        setState(() => _saveToQuestionBank = v),
                    onMaxScoreChanged: () => setState(() {}),
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // 2. Attached Exam Booklet (PDF) Card
                  CreateExamPdfCard(
                    hasPdf: (_attachedPdfFileId != null &&
                            _attachedPdfFileId!.isNotEmpty) ||
                        (_attachedPdfStoragePath != null &&
                            _attachedPdfStoragePath!.isNotEmpty),
                    isCreating: isCreating,
                    isUploadingPdf: _isUploadingPdf,
                    attachedPdfFileName: _attachedPdfFileName,
                    attachedPdfFileSize: _attachedPdfFileSize,
                    attachedPdfStoragePath: _attachedPdfStoragePath,
                    onPickFromLibrary: _pickPdfFromLibrary,
                    onPickFromDevice: _pickPdfFromDevice,
                    onPreviewPdf: _previewAttachedPdf,
                    onRemovePdf: _removeAttachedPdf,
                    onQuickBubbleSheet: _showQuickBubbleSheetDialog,
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // 3. Score Balance & Summary Header
                  CreateExamScoreSummaryBar(
                    questionsCount: _questions.length,
                    totalQuestionsPoints: _totalQuestionsPoints,
                    maxScoreNum: maxScoreNum,
                    defaultPointsController: _defaultPointsController,
                    isCreating: isCreating,
                    onAutoAdjustMaxScore: () {
                      setState(() {
                        _maxScoreController.text =
                            _totalQuestionsPoints.toString();
                        _passingScoreController.text =
                            (_totalQuestionsPoints * 0.6).round().toString();
                      });
                    },
                    onDefaultPointsChanged: (pts) =>
                        _defaultQuestionPoints = pts,
                    onApplyDefaultPoints: _applyDefaultPointsToAllQuestions,
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // 4. Questions Section Header
                  CreateExamQuestionsToolbar(
                    questionsCount: _questions.length,
                    isCreating: isCreating,
                    hasExpandedQuestions: _questions.any((q) => q.isExpanded),
                    onToggleExpandCollapse: () {
                      if (_questions.any((q) => q.isExpanded)) {
                        _collapseAllQuestions();
                      } else {
                        _expandAllQuestions();
                      }
                    },
                    onImportFromBank: _openQuestionBankPicker,
                    onBulkFillOptions: _showBulkFillOptionsSheet,
                    onAddQuestion: _addQuestion,
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // 5. Questions List (Accordion Pattern)
                  CreateExamQuestionsListSection(
                    questions: _questions,
                    isCreating: isCreating,
                    onToggleExpanded: _toggleQuestionExpanded,
                    onRemove: _removeQuestion,
                    onImagePicked: _handleQuestionImagePicked,
                    onPointsChanged: _autoUpdateMaxScoreIfBalanced,
                    onAddOption: _addOptionToQuestion,
                    onRemoveOption: _removeOptionFromQuestion,
                    onQuickFillOptions: _quickFillQuestionOptions,
                  ),

                  // 6. Bottom Add Question Card and Submit/Publish Action Button
                  CreateExamBottomBar(
                    isCreating: isCreating,
                    isSubmitting: _isSubmitting,
                    isEditing: widget.existingExam != null || _savedExamId != null,
                    onAddQuestion: _addQuestion,
                    onSubmit: _submitExam,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
