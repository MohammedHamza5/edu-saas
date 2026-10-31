import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/repositories/exams_repository.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../models/create_exam_draft_models.dart';
import '../models/create_exam_form_state.dart';
import '../utils/create_exam_builder_helpers.dart';
import '../utils/create_exam_draft_coordinator.dart';
import '../utils/create_exam_draft_handler.dart';
import '../utils/create_exam_draft_manager.dart';
import '../utils/create_exam_pdf_coordinator.dart';
import '../utils/create_exam_pdf_state.dart';
import '../utils/create_exam_question_actions_handler.dart';
import '../utils/create_exam_questions_coordinator.dart';
import '../utils/create_exam_submission_coordinator.dart';
import '../utils/no_op_exams_repository.dart';
import '../widgets/create_exam_app_bar.dart';
import '../widgets/create_exam_body.dart';
import '../widgets/create_exam_floating_button.dart';

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

typedef _DraftQuestion = CreateExamDraftQuestion;

class _CreateExamPageState extends State<CreateExamPage> {
  final _controllers = CreateExamFormControllers();
  final _settings = CreateExamSettingsState();
  final _pdfState = CreateExamPdfState();

  bool _isSubmitting = false;
  String? _savedExamId;
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

    _controllers.addAutoSaveListeners(_scheduleAutoSave);

    if (widget.existingExam != null) {
      final ex = widget.existingExam!;
      _controllers.title.text = ex.title;
      _controllers.duration.text = ex.durationMinutes.toString();
      _controllers.maxScore.text = ex.maxScore.toString();
      if (ex.passingScore != null) {
        _controllers.passingScore.text = ex.passingScore.toString();
      }
      _settings.shuffle = ex.shuffleQuestions;
      _settings.showResult = ex.showResult;
      _settings.allowRetake = ex.allowRetake;
      _settings.isPublished = ex.isPublished;
      _pdfState.fileId = ex.pdfFileId;
      _pdfState.fileName = ex.pdfFileName;
      _pdfState.fileSize = ex.pdfFileSize;
      _pdfState.storagePath = ex.pdfStoragePath;

      final existingQuestions = ex.activeVersion?.questions;
      if (existingQuestions != null && existingQuestions.isNotEmpty) {
        _settings.defaultQuestionPoints = existingQuestions.first.points;
        _controllers.defaultPoints.text =
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
      _controllers.title.text = widget.initialTitle!.trim();
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
    _controllers.removeAutoSaveListeners(_scheduleAutoSave);
    _controllers.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _bindQuestionListeners(_DraftQuestion q) {
    CreateExamDraftHandler.bindQuestionListeners(q, _scheduleAutoSave);
  }

  void _scheduleAutoSave() {
    _draftCoordinator.scheduleAutoSave(
      isSubmitting: _isSubmitting,
      onPersist: _persistDraft,
    );
  }

  Future<void> _persistDraft() async {
    if (!mounted || _isSubmitting) return;

    final saved = await CreateExamDraftHandler.persistDraft(
      draftCoordinator: _draftCoordinator,
      isSubmitting: _isSubmitting,
      controllers: _controllers,
      settings: _settings,
      pdfState: _pdfState,
      questions: _questions,
    );
    if (saved && mounted) {
      setState(() => _isAutoSaved = true);
    }
  }

  Future<void> _checkForSavedDraft() async {
    if (!mounted) return;
    final draft = await _draftCoordinator.checkForSavedDraft();
    if (draft != null && mounted) {
      setState(() => _savedDraftData = draft);
    }
  }

  void _restoreDraft() {
    if (_savedDraftData == null) return;
    CreateExamDraftHandler.restoreDraft(
      context: context,
      savedDraftData: _savedDraftData!,
      controllers: _controllers,
      settings: _settings,
      pdfState: _pdfState,
      questions: _questions,
      onBindListeners: _bindQuestionListeners,
      onUpdate: () {
        setState(() {
          _savedDraftData = null;
          _autoUpdateMaxScoreIfBalanced();
        });
      },
    );
  }

  void _discardDraft() {
    CreateExamDraftManager.discardDraft(
      context: context,
      draftCoordinator: _draftCoordinator,
    );
    setState(() => _savedDraftData = null);
  }

  void _handleQuestionImagePicked(int qIndex, Uint8List bytes, String filename) {
    if (qIndex < 0 || qIndex >= _questions.length) return;
    CreateExamQuestionActionsHandler.uploadQuestionImage(
      context: context,
      q: _questions[qIndex],
      qIndex: qIndex,
      bytes: bytes,
      filename: filename,
      uploadService: _uploadService,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _addQuestion() {
    setState(() {
      CreateExamQuestionsCoordinator.addQuestion(
        questions: _questions,
        defaultPoints: _settings.defaultQuestionPoints,
        onBindListeners: _bindQuestionListeners,
        scrollController: _controllers.scrollController,
      );
      _autoUpdateMaxScoreIfBalanced();
      _scheduleAutoSave();
    });
  }

  void _autoUpdateMaxScoreIfBalanced() {
    final scores = CreateExamQuestionsCoordinator.calculateBalancedScores(
      _totalQuestionsPoints,
    );
    if (scores.maxScore > 0) {
      _controllers.maxScore.text = scores.maxScore.toString();
      _controllers.passingScore.text = scores.passingScore.toString();
    }
  }

  Future<void> _submitExam() async {
    if (_isSubmitting) return;
    if (!_controllers.formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final resultExam = await CreateExamSubmissionCoordinator.submit(
        context: context,
        cubit: context.read<ExamsCubit>(),
        targetExamId: widget.existingExam?.id ?? _savedExamId,
        groupId: widget.groupId,
        title: _controllers.title.text.trim(),
        durationText: _controllers.duration.text.trim(),
        maxScoreText: _controllers.maxScore.text.trim(),
        passingScoreText: _controllers.passingScore.text.trim(),
        shuffle: _settings.shuffle,
        showResult: _settings.showResult,
        allowRetake: _settings.allowRetake,
        isPublished: _settings.isPublished,
        saveToQuestionBank: _settings.saveToQuestionBank,
        clearPdfOnSave: _pdfState.clearPdfOnSave,
        attachedPdfFileId: _pdfState.fileId,
        questions: _questions,
        onClearDraft: () => _draftCoordinator.clearDraft(),
      );

      if (resultExam != null && mounted) {
        _savedExamId = resultExam.id;
        Navigator.of(context).pop(resultExam);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showQuickBubbleSheetDialog() async {
    await CreateExamPdfCoordinator.handleQuickBubbleSheet(
      context: context,
      defaultPoints: _settings.defaultQuestionPoints,
      questions: _questions,
      onBindListeners: _bindQuestionListeners,
      onApplyScores: (totalScore, points) {
        _controllers.maxScore.text = totalScore.toString();
        _controllers.passingScore.text = (totalScore * 0.6).round().toString();
        _settings.defaultQuestionPoints = points;
        _controllers.defaultPoints.text = points.toString();
        setState(() {});
        _scheduleAutoSave();
      },
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
              int.tryParse(_controllers.maxScore.text.trim()) ?? 0;

          return CreateExamBody(
            scrollController: _controllers.scrollController,
            formKey: _controllers.formKey,
            savedDraftData: _savedDraftData,
            onDiscardDraft: _discardDraft,
            onRestoreDraft: _restoreDraft,
            titleController: _controllers.title,
            durationController: _controllers.duration,
            maxScoreController: _controllers.maxScore,
            passingScoreController: _controllers.passingScore,
            defaultPointsController: _controllers.defaultPoints,
            isCreating: isCreating,
            shuffle: _settings.shuffle,
            showResult: _settings.showResult,
            allowRetake: _settings.allowRetake,
            isPublished: _settings.isPublished,
            saveToQuestionBank: _settings.saveToQuestionBank,
            onApplyDefaultPoints: () {
              CreateExamQuestionActionsHandler.applyDefaultPointsToAll(
                context: context,
                defaultPointsController: _controllers.defaultPoints,
                questions: _questions,
                onPointsApplied: (pts) => _settings.defaultQuestionPoints = pts,
                onUpdate: () {
                  _autoUpdateMaxScoreIfBalanced();
                  setState(() {});
                },
                onScheduleAutoSave: _scheduleAutoSave,
              );
            },
            onDefaultPointsChanged: (pts) => _settings.defaultQuestionPoints = pts,
            onShuffleChanged: (v) => setState(() => _settings.shuffle = v),
            onShowResultChanged: (v) => setState(() => _settings.showResult = v),
            onAllowRetakeChanged: (v) => setState(() => _settings.allowRetake = v),
            onIsPublishedChanged: (v) => setState(() => _settings.isPublished = v),
            onSaveToQuestionBankChanged: (v) =>
                setState(() => _settings.saveToQuestionBank = v),
            onMaxScoreChanged: () => setState(() {}),
            hasPdf: _pdfState.hasPdf,
            isUploadingPdf: _pdfState.isUploading,
            attachedPdfFileName: _pdfState.fileName,
            attachedPdfFileSize: _pdfState.fileSize,
            attachedPdfStoragePath: _pdfState.storagePath,
            onPickFromLibrary: () => _pdfState.pickFromLibrary(
              context,
              onStateChanged: () => setState(() {}),
              onScheduleAutoSave: _scheduleAutoSave,
            ),
            onPickFromDevice: () => _pdfState.pickFromDevice(
              context,
              onUploadStateChanged: (_) => setState(() {}),
              onStateChanged: () => setState(() {}),
              onScheduleAutoSave: _scheduleAutoSave,
            ),
            onPreviewPdf: () => _pdfState.previewPdf(
              context,
              tenantId: widget.existingExam?.tenantId,
            ),
            onRemovePdf: () => _pdfState.removePdf(
              onStateChanged: () => setState(() {}),
              onScheduleAutoSave: _scheduleAutoSave,
            ),
            onQuickBubbleSheet: _showQuickBubbleSheetDialog,
            questionsCount: _questions.length,
            totalQuestionsPoints: _totalQuestionsPoints,
            maxScoreNum: maxScoreNum,
            onAutoAdjustMaxScore: () {
              setState(() {
                _controllers.maxScore.text = _totalQuestionsPoints.toString();
                _controllers.passingScore.text =
                    (_totalQuestionsPoints * 0.6).round().toString();
              });
            },
            hasExpandedQuestions: _questions.any((q) => q.isExpanded),
            onToggleExpandCollapse: () {
              setState(() {
                if (_questions.any((q) => q.isExpanded)) {
                  CreateExamQuestionsCoordinator.collapseAll(_questions);
                } else {
                  CreateExamQuestionsCoordinator.expandAll(_questions);
                }
              });
            },
            onImportFromBank: () {
              CreateExamQuestionActionsHandler.openQuestionBankPicker(
                context,
                questions: _questions,
                defaultPoints: _settings.defaultQuestionPoints,
                onBindListeners: _bindQuestionListeners,
                onUpdate: () {
                  _autoUpdateMaxScoreIfBalanced();
                  setState(() {});
                },
                onScheduleAutoSave: _scheduleAutoSave,
              );
            },
            onBulkFillOptions: () {
              CreateExamQuestionActionsHandler.showBulkFillOptionsSheet(
                context,
                questions: _questions,
                onUpdate: () => setState(() {}),
                onScheduleAutoSave: _scheduleAutoSave,
              );
            },
            onAddQuestion: _addQuestion,
            questions: _questions,
            onToggleExpanded: (idx) => setState(
              () => CreateExamQuestionsCoordinator.toggleExpanded(
                _questions,
                idx,
              ),
            ),
            onRemoveQuestion: (idx) {
              setState(() {
                CreateExamQuestionsCoordinator.removeQuestion(
                  questions: _questions,
                  index: idx,
                );
                _autoUpdateMaxScoreIfBalanced();
                _scheduleAutoSave();
              });
            },
            onImagePicked: _handleQuestionImagePicked,
            onPointsChanged: _autoUpdateMaxScoreIfBalanced,
            onAddOption: (q) {
              setState(() {
                CreateExamQuestionsCoordinator.addOption(
                  question: q,
                  onScheduleAutoSave: _scheduleAutoSave,
                );
              });
              _scheduleAutoSave();
            },
            onRemoveOption: (q, optIdx) {
              setState(() {
                CreateExamQuestionsCoordinator.removeOption(
                  question: q,
                  optIdx: optIdx,
                );
              });
              _scheduleAutoSave();
            },
            onQuickFillOptions: (q, letters) {
              setState(() {
                CreateExamQuestionsCoordinator.quickFillOptions(
                  question: q,
                  letters: letters,
                  onScheduleAutoSave: _scheduleAutoSave,
                );
              });
              _scheduleAutoSave();
            },
            isSubmitting: _isSubmitting,
            isEditing: widget.existingExam != null || _savedExamId != null,
            onSubmit: _submitExam,
          );
        },
      ),
    );
  }
}
