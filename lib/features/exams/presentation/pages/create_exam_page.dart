import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/datasources/exam_draft_local_datasource.dart';
import '../../data/services/exam_image_upload_service.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../widgets/exam_image_attachment_box.dart';
import '../widgets/question_bank_picker_sheet.dart';
import '../../../../core/di/injection_container.dart';
import '../../../question_bank/domain/entities/question_revision_entity.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/file_attachment_entity.dart';
import '../../../content/presentation/widgets/material_viewer_sheet.dart';
import '../../../content/presentation/dialogs/select_material_from_library_dialog.dart';

class CreateExamPage extends StatefulWidget {
  final String? groupId;
  final String? groupName;
  final String? initialTitle;
  final ExamEntity? existingExam;

  const CreateExamPage({
    super.key,
    this.groupId,
    this.groupName,
    this.initialTitle,
    this.existingExam,
  });

  @override
  State<CreateExamPage> createState() => _CreateExamPageState();
}

class _DraftOption {
  final TextEditingController controller;
  bool isCorrect;
  String? imageUrl;
  Map<String, dynamic>? imageMeta;

  _DraftOption({
    String text = '',
    this.isCorrect = false,
  }) : controller = TextEditingController(text: text);

  Map<String, dynamic> toJson() => {
        'text': controller.text,
        'isCorrect': isCorrect,
        'imageUrl': imageUrl,
        'imageMeta': imageMeta,
      };

  static _DraftOption fromJson(Map<String, dynamic> json) {
    final opt = _DraftOption(
      text: json['text'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
    );
    opt.imageUrl = json['imageUrl'] as String?;
    if (json['imageMeta'] is Map) {
      opt.imageMeta = Map<String, dynamic>.from(json['imageMeta'] as Map);
    }
    return opt;
  }

  void dispose() {
    controller.dispose();
  }
}

class _DraftQuestion {
  final TextEditingController textController;
  final TextEditingController pointsController;
  QuestionType type = QuestionType.multipleChoice;
  int points;
  bool trueFalseAnswer =
      true; // true = OptionTrue is correct, false = OptionFalse is correct
  late List<_DraftOption> options;
  String? imageUrl;
  Uint8List? localImageBytes;
  Map<String, dynamic>? imageMeta;
  Future<String>? uploadFuture;
  bool isUploadingImage = false;
  String? uploadError;
  String? contextId;
  bool isExpanded;

  _DraftQuestion({
    this.isExpanded = true,
    int initialPoints = 5,
    String initialText = '',
  })  : points = initialPoints,
        textController = TextEditingController(text: initialText),
        pointsController =
            TextEditingController(text: initialPoints.toString()) {
    options = [
      _DraftOption(isCorrect: true),
      _DraftOption(isCorrect: false),
      _DraftOption(isCorrect: false),
      _DraftOption(isCorrect: false),
    ];
  }

  Map<String, dynamic> toJson() => {
        'text': textController.text,
        'points': points,
        'type': type.name,
        'trueFalseAnswer': trueFalseAnswer,
        'imageUrl': imageUrl,
        'imageMeta': imageMeta,
        'contextId': contextId,
        'isExpanded': isExpanded,
        'options': options.map((o) => o.toJson()).toList(),
      };

  static _DraftQuestion fromJson(Map<String, dynamic> json) {
    final q = _DraftQuestion(
      isExpanded: json['isExpanded'] as bool? ?? false,
      initialPoints: json['points'] as int? ?? 5,
      initialText: json['text'] as String? ?? '',
    );
    q.type = QuestionType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => QuestionType.multipleChoice,
    );
    q.trueFalseAnswer = json['trueFalseAnswer'] as bool? ?? true;
    q.imageUrl = json['imageUrl'] as String?;
    if (json['imageMeta'] is Map) {
      q.imageMeta = Map<String, dynamic>.from(json['imageMeta'] as Map);
    }
    q.contextId = json['contextId'] as String?;
    final rawOptions = json['options'] as List?;
    if (rawOptions != null && rawOptions.isNotEmpty) {
      for (final opt in q.options) {
        opt.dispose();
      }
      q.options = rawOptions
          .map((o) => _DraftOption.fromJson(o as Map<String, dynamic>))
          .toList();
    }
    return q;
  }

  void dispose() {
    textController.dispose();
    pointsController.dispose();
    for (final opt in options) {
      opt.dispose();
    }
  }
}

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
  final _uploadService = ExamImageUploadService();
  final _draftStorage = const ExamDraftLocalDataSource();

  Timer? _autoSaveDebounceTimer;
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

    _titleController.addListener(_scheduleAutoSave);
    _durationController.addListener(_scheduleAutoSave);
    _maxScoreController.addListener(_scheduleAutoSave);
    _passingScoreController.addListener(_scheduleAutoSave);
    _defaultPointsController.addListener(_scheduleAutoSave);

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

        for (int i = 0; i < existingQuestions.length; i++) {
          final eq = existingQuestions[i];
          final dq = _DraftQuestion(isExpanded: i == 0);
          dq.textController.text = eq.questionText.trim();
          dq.pointsController.text = eq.points.toString();
          dq.points = eq.points;
          dq.type = eq.questionType;
          dq.imageUrl = eq.imageUrl;
          dq.localImageBytes = null;
          dq.imageMeta = eq.imageMeta;
          dq.contextId = eq.contextId;

          if (eq.questionType == QuestionType.trueFalse) {
            final correctOpt = eq.options
                    .where((o) => o.isCorrect == true)
                    .firstOrNull ??
                eq.options.firstOrNull;
            dq.trueFalseAnswer = correctOpt != null &&
                (correctOpt.optionText == 'True' ||
                    correctOpt.optionText == 'صح');
          } else {
            for (final opt in dq.options) {
              opt.dispose();
            }
            dq.options = eq.options.map((opt) {
              final dOpt = _DraftOption(
                text: opt.optionText,
                isCorrect: opt.isCorrect ?? false,
              );
              dOpt.imageUrl = opt.imageUrl;
              dOpt.imageMeta = opt.imageMeta;
              return dOpt;
            }).toList();
            if (dq.options.isEmpty) {
              dq.options = [
                _DraftOption(isCorrect: true),
                _DraftOption(isCorrect: false),
              ];
            }
          }
          _questions.add(dq);
        }
      }
    } else if (widget.initialTitle != null && widget.initialTitle!.trim().isNotEmpty) {
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
    _autoSaveDebounceTimer?.cancel();
    _titleController.removeListener(_scheduleAutoSave);
    _durationController.removeListener(_scheduleAutoSave);
    _maxScoreController.removeListener(_scheduleAutoSave);
    _passingScoreController.removeListener(_scheduleAutoSave);
    _defaultPointsController.removeListener(_scheduleAutoSave);

    _scrollController.dispose();
    _titleController.dispose();
    _durationController.dispose();
    _defaultPointsController.dispose();
    _maxScoreController.dispose();
    _passingScoreController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
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
    _autoSaveDebounceTimer?.cancel();
    _autoSaveDebounceTimer = Timer(const Duration(milliseconds: 1500), () {
      _persistDraft();
    });
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

    final draftData = <String, dynamic>{
      'savedAt': DateTime.now().toIso8601String(),
      'title': _titleController.text,
      'duration': _durationController.text,
      'maxScore': _maxScoreController.text,
      'passingScore': _passingScoreController.text,
      'defaultPoints': _defaultPointsController.text,
      'shuffle': _shuffle,
      'showResult': _showResult,
      'allowRetake': _allowRetake,
      'isPublished': _isPublished,
      'saveToQuestionBank': _saveToQuestionBank,
      'pdfFileId': _attachedPdfFileId,
      'pdfFileName': _attachedPdfFileName,
      'pdfFileSize': _attachedPdfFileSize,
      'pdfStoragePath': _attachedPdfStoragePath,
      'questions': _questions.map((q) => q.toJson()).toList(),
    };

    await _draftStorage.saveDraft(draftKey: _draftKey, data: draftData);
    if (mounted) {
      setState(() {
        _isAutoSaved = true;
      });
    }
  }

  Future<void> _checkForSavedDraft() async {
    if (!mounted) return;
    final draft = await _draftStorage.getDraft(_draftKey);
    if (draft == null || !mounted) return;

    final rawQuestions = draft['questions'] as List?;
    final hasQuestions = rawQuestions != null && rawQuestions.isNotEmpty;
    final title = draft['title'] as String? ?? '';

    if (hasQuestions || title.trim().isNotEmpty) {
      setState(() {
        _savedDraftData = draft;
      });
    }
  }

  void _restoreDraft() {
    if (_savedDraftData == null) return;
    final data = _savedDraftData!;

    setState(() {
      if (data['title'] != null && (data['title'] as String).isNotEmpty) {
        _titleController.text = data['title'] as String;
      }
      if (data['duration'] != null) {
        _durationController.text = data['duration'] as String;
      }
      if (data['maxScore'] != null) {
        _maxScoreController.text = data['maxScore'] as String;
      }
      if (data['passingScore'] != null) {
        _passingScoreController.text = data['passingScore'] as String;
      }
      if (data['defaultPoints'] != null) {
        _defaultPointsController.text = data['defaultPoints'] as String;
        _defaultQuestionPoints =
            int.tryParse(data['defaultPoints'] as String) ?? _defaultQuestionPoints;
      }
      if (data['shuffle'] is bool) _shuffle = data['shuffle'] as bool;
      if (data['showResult'] is bool) _showResult = data['showResult'] as bool;
      if (data['allowRetake'] is bool) _allowRetake = data['allowRetake'] as bool;
      if (data['isPublished'] is bool) _isPublished = data['isPublished'] as bool;
      if (data['saveToQuestionBank'] is bool) {
        _saveToQuestionBank = data['saveToQuestionBank'] as bool;
      }
      if (data['pdfFileId'] != null) {
        _attachedPdfFileId = data['pdfFileId'] as String?;
        _attachedPdfFileName = data['pdfFileName'] as String?;
        _attachedPdfFileSize = data['pdfFileSize'] as int?;
        _attachedPdfStoragePath = data['pdfStoragePath'] as String?;
        _clearPdfOnSave = false;
      }

      final rawQuestions = data['questions'] as List?;
      if (rawQuestions != null && rawQuestions.isNotEmpty) {
        for (final q in _questions) {
          q.dispose();
        }
        _questions.clear();
        for (int i = 0; i < rawQuestions.length; i++) {
          final q = _DraftQuestion.fromJson(
            rawQuestions[i] as Map<String, dynamic>,
          );
          q.isExpanded = i == 0;
          _bindQuestionListeners(q);
          _questions.add(q);
        }
      }

      _savedDraftData = null;
      _autoUpdateMaxScoreIfBalanced();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(context.l10n.examDraftRestoredSuccess),
          ],
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _discardDraft() {
    _draftStorage.clearDraft(_draftKey);
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

  Widget _buildDraftRecoveryBanner(BuildContext context) {
    final rawQuestions = _savedDraftData?['questions'] as List?;
    final count = rawQuestions?.length ?? 0;
    final savedAtStr = _savedDraftData?['savedAt'] as String?;
    String timeAgo = '';
    if (savedAtStr != null) {
      final savedAt = DateTime.tryParse(savedAtStr);
      if (savedAt != null) {
        final diff = DateTime.now().difference(savedAt);
        if (diff.inMinutes < 1) {
          timeAgo = '< 1m';
        } else if (diff.inHours < 1) {
          timeAgo = '${diff.inMinutes}m';
        } else if (diff.inDays < 1) {
          timeAgo = '${diff.inHours}h';
        } else {
          timeAgo = '${diff.inDays}d';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: const Color(0xFF5B4FE0).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: const Color(0xFF5B4FE0).withValues(alpha: 0.3),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 480;
          final header = Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B4FE0).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.history_edu_rounded,
                  color: Color(0xFF5B4FE0),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: Text(
                  context.l10n.examDraftFoundNotice(count, timeAgo),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          );

          final actions = Row(
            mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment:
                isNarrow ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              OutlinedButton(
                onPressed: _discardDraft,
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
                child: Text(
                  context.l10n.discardExamDraftAction,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilledButton.icon(
                onPressed: _restoreDraft,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: Text(
                  context.l10n.restoreExamDraftAction,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF5B4FE0),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                const SizedBox(height: 8),
                actions,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: header),
              const SizedBox(width: AppSpacing.s12),
              actions,
            ],
          );
        },
      ),
    );
  }

  void _handleQuestionImagePicked(
    int qIndex,
    Uint8List bytes,
    String filename,
  ) {
    if (qIndex < 0 || qIndex >= _questions.length) return;
    final q = _questions[qIndex];

    setState(() {
      q.localImageBytes = bytes;
      q.imageUrl = null;
      q.isUploadingImage = true;
      q.uploadError = null;
    });

    final uploadFuture = _uploadService.uploadExamImage(
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
      if (mounted) {
        setState(() {});
      }
    }).catchError((Object error, StackTrace stackTrace) {
      AppLogger.e(
        'CreateExamPage',
        '❌ Question ${qIndex + 1} background image upload failed: $error',
        error: error,
        stackTrace: stackTrace,
      );
      q.isUploadingImage = false;
      q.uploadError = error.toString();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.imageUploadFailed(error.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });
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
    setState(() {
      for (final rev in revisions) {
        final draftQ = _DraftQuestion(
          isExpanded: false,
          initialPoints: _defaultQuestionPoints,
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
            draftQ.options.add(_DraftOption(
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
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.pointsAppliedToAllSuccess(
                  pts,
                  _questions.length,
                ),
              ),
            ),
          ],
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
    int updatedCount = 0;
    setState(() {
      for (int qIdx = 0; qIdx < _questions.length; qIdx++) {
        final q = _questions[qIdx];
        if (q.type != QuestionType.multipleChoice) continue;

        if (onlyEmpty) {
          final isAnyFilled = q.options.any((o) => o.controller.text.trim().isNotEmpty);
          if (isAnyFilled) continue;
        }

        List<String> letters;
        if (pattern == 'act') {
          letters = (qIdx % 2 == 0) ? ['A', 'B', 'C', 'D'] : ['F', 'G', 'H', 'J'];
        } else if (pattern == 'ar') {
          letters = ['أ', 'ب', 'ج', 'د'];
        } else {
          letters = ['A', 'B', 'C', 'D'];
        }

        while (q.options.length < letters.length && q.options.length < 6) {
          q.options.add(_DraftOption(isCorrect: false));
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
    });

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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: const Icon(
                        Icons.auto_fix_high_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.bulkFillOptionsTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.l10n.bulkFillOptionsSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.format_list_bulleted_rounded, color: AppColors.primary),
                  title: Text(context.l10n.fillAllQuestionsAbcd),
                  subtitle: const Text('A, B, C, D'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _bulkFillAllQuestions('abcd', onlyEmpty: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.check_box_outline_blank_rounded, color: Color(0xFF0EA5E9)),
                  title: Text(context.l10n.fillEmptyQuestionsAbcd),
                  subtitle: const Text('A, B, C, D'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _bulkFillAllQuestions('abcd', onlyEmpty: true);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sync_alt_rounded, color: Color(0xFF8B5CF6)),
                  title: Text(context.l10n.fillActAlternatingPattern),
                  subtitle: const Text('Q1: A,B,C,D  ·  Q2: F,G,H,J ...'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _bulkFillAllQuestions('act', onlyEmpty: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.translate_rounded, color: Color(0xFF10B981)),
                  title: Text(context.l10n.fillArabicLettersPattern),
                  subtitle: const Text('أ ، ب ، ج ، د'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _bulkFillAllQuestions('ar', onlyEmpty: false);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitExam() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    // 1. If any question images are still actively uploading in the background, await them gracefully
    final pendingQuestions = _questions
        .where((q) => q.isUploadingImage && q.uploadFuture != null)
        .toList();

    if (pendingQuestions.isNotEmpty) {
      AppLogger.i(
        'CreateExamPage',
        '⏳ Waiting for ${pendingQuestions.length} pending question image uploads before saving exam...',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(context.l10n.syncingPendingImages),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      try {
        await Future.wait(pendingQuestions.map((q) => q.uploadFuture!));
      } catch (e) {
        AppLogger.e('CreateExamPage', '⚠️ Error while waiting for pending uploads: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.imageUploadPendingError),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    if (!mounted) return;

    // Validate that each question has text (or an attached image) and at least one correct option
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final hasImage = (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ||
          (q.localImageBytes != null);
      if (q.textController.text.trim().isEmpty && !hasImage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.fillQuestionTextError(i + 1)),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (q.type == QuestionType.multipleChoice) {
        final filledOptions = q.options
            .where((o) => o.controller.text.trim().isNotEmpty || o.imageUrl != null)
            .toList();
        final isImageBasedQuestion = (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ||
            (q.localImageBytes != null);
        if (filledOptions.length < 2 && (!isImageBasedQuestion || q.options.length < 2)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.atLeastTwoOptionsRequired),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }

        final hasCorrect = q.options.any((o) => o.isCorrect);
        if (!hasCorrect) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.selectCorrectOptionError(i + 1)),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }
    }

    final initialQuestions = _questions.asMap().entries.map((entry) {
      final idx = entry.key;
      final q = entry.value;

      List<QuestionOptionEntity> optionsList;

      if (q.type == QuestionType.trueFalse) {
        // True/False options: explicitly defined
        optionsList = [
          QuestionOptionEntity(
            id: 'opt-${idx + 1}-1',
            questionId: 'q-${idx + 1}',
            optionText: context.l10n.optionTrue,
            sortOrder: 1,
            isCorrect: q.trueFalseAnswer == true,
          ),
          QuestionOptionEntity(
            id: 'opt-${idx + 1}-2',
            questionId: 'q-${idx + 1}',
            optionText: context.l10n.optionFalse,
            sortOrder: 2,
            isCorrect: q.trueFalseAnswer == false,
          ),
        ];
      } else {
        // Multiple choice options: if teacher left texts blank (common in math image questions),
        // gracefully fallback to standard letter options (A, B, C, D) so options are NEVER lost!
        const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
        final textFilled = q.options
            .where((o) => o.controller.text.trim().isNotEmpty || o.imageUrl != null)
            .toList();
        final effectiveDraftOptions =
            (textFilled.length >= 2) ? textFilled : q.options;

        optionsList = effectiveDraftOptions.asMap().entries.map((optEntry) {
          final optIdx = optEntry.key;
          final opt = optEntry.value;
          final letter = optIdx < letters.length ? letters[optIdx] : '${optIdx + 1}';
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

        if (optionsList.isNotEmpty && !optionsList.any((o) => o.isCorrect == true)) {
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

    setState(() {
      _isSubmitting = true;
    });

    try {
      final targetExamId = widget.existingExam?.id ?? _savedExamId;
      final isEditing = targetExamId != null;
      final ExamEntity? resultExam;
      if (isEditing) {
        resultExam = await context.read<ExamsCubit>().updateDraftExamQuestions(
          examId: targetExamId,
          title: _titleController.text.trim(),
          durationMinutes: int.tryParse(_durationController.text.trim()) ?? 60,
          maxScore: int.tryParse(_maxScoreController.text.trim()) ?? 100,
          passingScore: int.tryParse(_passingScoreController.text.trim()),
          shuffleQuestions: _shuffle,
          showResult: _showResult,
          allowRetake: _allowRetake,
          isPublished: _isPublished,
          pdfFileId: _clearPdfOnSave ? null : _attachedPdfFileId,
          clearPdfFile: _clearPdfOnSave,
          questions: initialQuestions,
        );
      } else {
        resultExam = await context.read<ExamsCubit>().createExam(
          groupId: widget.groupId,
          title: _titleController.text.trim(),
          durationMinutes: int.tryParse(_durationController.text.trim()) ?? 60,
          maxScore: int.tryParse(_maxScoreController.text.trim()) ?? 100,
          passingScore: int.tryParse(_passingScoreController.text.trim()),
          shuffleQuestions: _shuffle,
          showResult: _showResult,
          allowRetake: _allowRetake,
          isPublished: _isPublished,
          pdfFileId: _clearPdfOnSave ? null : _attachedPdfFileId,
          initialQuestions: initialQuestions,
        );
        if (resultExam != null) {
          _savedExamId = resultExam.id;
        }
      }

      if (!mounted) return;

      if (resultExam != null) {
        await _draftStorage.clearDraft(_draftKey);
        if (_saveToQuestionBank) {
          _syncQuestionsToBank();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? context.l10n.examDraftUpdatedSuccess
                  : context.l10n.examBuiltAndPublishedSuccess,
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(resultExam);
      } else {
        final state = context.read<ExamsCubit>().state;
        String errorMsg = 'Failed';
        if (state is TeacherExamsLoaded && state.message != null) {
          errorMsg = state.message!;
        } else if (state is ExamsError) {
          errorMsg = state.message;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isEditing
                  ? context.l10n.examUpdateFailed(errorMsg)
                  : context.l10n.examPublishFailed(errorMsg),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _syncQuestionsToBank() {
    final examTitle = _titleController.text.trim().isEmpty ? 'Exam' : _titleController.text.trim();
    final qbRepo = InjectionContainer.questionBankRepository;

    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
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
      final sourceLabel = '$examTitle-Q${i + 1}';

      qbRepo.createManualQuestion(
        sourceLabel: sourceLabel,
        questionType: q.type == QuestionType.trueFalse ? 'true_false' : 'multiple_choice',
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
      ).catchError((Object err) {
        AppLogger.w('CreateExamPage', 'Could not sync question ${i + 1} to question bank: $err');
        return '';
      });
    }
  }

  Future<void> _pickPdfFromLibrary() async {
    final selected = await SelectMaterialFromLibraryDialog.show(context);
    if (selected != null && mounted) {
      setState(() {
        _attachedPdfFileId = selected.id;
        _attachedPdfFileName = selected.fileName;
        _attachedPdfFileSize = selected.fileSize;
        _attachedPdfStoragePath = selected.storagePath;
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
  }

  Future<void> _pickPdfFromDevice() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        final bytes = file.bytes;
        if (bytes == null) return;

        setState(() => _isUploadingPdf = true);

        final computedHash = sha256.convert(bytes).toString();
        final dupRes = await InjectionContainer.materialsLibraryRepository.checkDuplicate(
          fileHash: computedHash,
          fileName: file.name,
          fileSize: file.size,
        );

        final duplicate = dupRes.dataOrNull;
        if (duplicate != null && mounted) {
          setState(() {
            _attachedPdfFileId = duplicate.id;
            _attachedPdfFileName = duplicate.fileName;
            _attachedPdfFileSize = duplicate.fileSize;
            _attachedPdfStoragePath = duplicate.storagePath;
            _clearPdfOnSave = false;
            _isUploadingPdf = false;
          });
          _scheduleAutoSave();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.pdfAttachedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
          return;
        }

        final cleanTitle = file.name.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
        final uploadRes = await InjectionContainer.materialsLibraryRepository.uploadMaterial(
          title: cleanTitle,
          fileName: file.name,
          fileBytes: bytes,
          mimeType: 'application/pdf',
        );

        if (!mounted) return;
        setState(() => _isUploadingPdf = false);

        if (uploadRes.isSuccess && uploadRes.dataOrNull != null) {
          final uploaded = uploadRes.dataOrNull!;
          setState(() {
            _attachedPdfFileId = uploaded.id;
            _attachedPdfFileName = uploaded.fileName;
            _attachedPdfFileSize = uploaded.fileSize;
            _attachedPdfStoragePath = uploaded.storagePath;
            _clearPdfOnSave = false;
          });
          _scheduleAutoSave();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.pdfAttachedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(uploadRes.failureOrNull?.message ?? 'Failed to upload PDF'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPdf = false);
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
    if (_attachedPdfStoragePath == null || _attachedPdfStoragePath!.isEmpty) return;
    MaterialViewerSheet.show(
      context,
      content: ContentEntity(
        id: '',
        tenantId: widget.existingExam?.tenantId ?? '',
        title: _attachedPdfFileName ?? context.l10n.viewExamBooklet,
        type: ContentType.pdf,
        status: ContentStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        file: FileAttachmentEntity(
          id: _attachedPdfFileId ?? '',
          tenantId: widget.existingExam?.tenantId ?? '',
          contentId: '',
          storagePath: _attachedPdfStoragePath!,
          fileName: _attachedPdfFileName ?? 'booklet.pdf',
          mimeType: 'application/pdf',
          fileSize: _attachedPdfFileSize ?? 0,
          createdAt: DateTime.now(),
        ),
      ),
      onGetSignedUrl: (path) => context.read<ExamsCubit>().getSignedPdfUrl(path),
    );
  }

  Future<void> _showQuickBubbleSheetDialog() async {
    int questionCount = 20;
    int optionsCount = 4;
    int points = _defaultQuestionPoints;
    final countController = TextEditingController(text: '20');
    final pointsController = TextEditingController(text: _defaultQuestionPoints.toString());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    context.l10n.quickBubbleSheetGenerator,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.quickBubbleSheetPrompt,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    context.l10n.quickPresets,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s6,
                    children: [10, 20, 30, 40, 50].map((preset) {
                      final isSelected = questionCount == preset;
                      return ChoiceChip(
                        label: Text('$preset ${context.l10n.numberOfQuestions}'),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) {
                            setDialogState(() {
                              questionCount = preset;
                              countController.text = preset.toString();
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  AppTextField(
                    controller: countController,
                    labelText: context.l10n.numberOfQuestions,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.format_list_numbered_rounded),
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim());
                      if (parsed != null && parsed > 0 && parsed <= 200) {
                        setDialogState(() => questionCount = parsed);
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: pointsController,
                          labelText: context.l10n.defaultQuestionPointsLabel,
                          keyboardType: TextInputType.number,
                          prefixIcon: const Icon(Icons.stars_outlined),
                          onChanged: (val) {
                            final parsed = int.tryParse(val.trim());
                            if (parsed != null && parsed > 0) {
                              setDialogState(() => points = parsed);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: optionsCount,
                          decoration: InputDecoration(
                            labelText: context.l10n.numberOfOptionsPerQuestion,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: const [
                            DropdownMenuItem(value: 2, child: Text('2 (A, B)')),
                            DropdownMenuItem(value: 3, child: Text('3 (A, B, C)')),
                            DropdownMenuItem(value: 4, child: Text('4 (A, B, C, D)')),
                            DropdownMenuItem(value: 5, child: Text('5 (A, B, C, D, E)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => optionsCount = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  if (_questions.isNotEmpty && _questions.any((q) => q.textController.text.isNotEmpty))
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s10),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              context.l10n.overwriteQuestionsWarning,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: Text(context.l10n.generateQuestions),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed == true && mounted) {
      _applyQuickBubbleSheet(
        questionCount: questionCount,
        optionsCount: optionsCount,
        points: points,
      );
    }
  }

  void _applyQuickBubbleSheet({
    required int questionCount,
    required int optionsCount,
    required int points,
  }) {
    for (final q in _questions) {
      q.dispose();
    }
    _questions.clear();

    const optionLetters = ['A', 'B', 'C', 'D', 'E'];

    for (int i = 1; i <= questionCount; i++) {
      final dq = _DraftQuestion(
        isExpanded: i == 1,
        initialPoints: points,
        initialText: 'Question $i',
      );
      for (final opt in dq.options) {
        opt.dispose();
      }
      dq.options = List.generate(optionsCount, (idx) {
        final letter = idx < optionLetters.length ? optionLetters[idx] : '${idx + 1}';
        return _DraftOption(
          text: letter,
          isCorrect: idx == 0,
        );
      });
      _bindQuestionListeners(dq);
      _questions.add(dq);
    }

    final totalScore = questionCount * points;
    _maxScoreController.text = totalScore.toString();
    _passingScoreController.text = (totalScore * 0.6).round().toString();
    _defaultQuestionPoints = points;
    _defaultPointsController.text = points.toString();

    setState(() {});
    _scheduleAutoSave();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${context.l10n.generateQuestions}: $questionCount'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Widget _buildAttachedPdfCard(BuildContext context, bool isCreating) {
    final hasPdf = (_attachedPdfFileId != null && _attachedPdfFileId!.isNotEmpty) ||
        (_attachedPdfStoragePath != null && _attachedPdfStoragePath!.isNotEmpty);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFFEA580C),
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.attachedExamPdf,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.attachedExamPdfDesc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isUploadingPdf)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          if (!hasPdf) ...[
            Wrap(
              spacing: AppSpacing.s12,
              runSpacing: AppSpacing.s10,
              children: [
                OutlinedButton.icon(
                  onPressed: isCreating || _isUploadingPdf ? null : _pickPdfFromLibrary,
                  icon: const Icon(Icons.folder_shared_rounded, size: 18),
                  label: Text(context.l10n.selectFromMaterialsLibrary),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: isCreating || _isUploadingPdf ? null : _pickPdfFromDevice,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: Text(context.l10n.uploadNewPdfFromDevice),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFEA580C),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _attachedPdfFileName ?? 'Exam Booklet.pdf',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_attachedPdfFileSize != null && _attachedPdfFileSize! > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${(_attachedPdfFileSize! / (1024 * 1024)).toStringAsFixed(2)} MB',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  if (_attachedPdfStoragePath != null && _attachedPdfStoragePath!.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined),
                      tooltip: context.l10n.previewPdfBooklet,
                      onPressed: _previewAttachedPdf,
                    ),
                  PopupMenuButton<String>(
                    tooltip: context.l10n.replacePdfBooklet,
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (val) {
                      if (val == 'library') {
                        _pickPdfFromLibrary();
                      } else if (val == 'device') {
                        _pickPdfFromDevice();
                      } else if (val == 'remove') {
                        _removeAttachedPdf();
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'library',
                        child: Row(
                          children: [
                            const Icon(Icons.folder_shared_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(context.l10n.selectFromMaterialsLibrary),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'device',
                        child: Row(
                          children: [
                            const Icon(Icons.upload_file_rounded, size: 18),
                            const SizedBox(width: 8),
                            Text(context.l10n.uploadNewPdfFromDevice),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                            const SizedBox(width: 8),
                            Text(context.l10n.removeAttachedPdf, style: const TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            // Fast Bubble Sheet Call-to-action
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.quickBubbleSheetGenerator,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.quickBubbleSheetPrompt,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: isCreating ? null : _showQuickBubbleSheetDialog,
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: Text(context.l10n.quickPresets),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.existingExam != null
                  ? context.l10n.editDraftExamTitle
                  : context.l10n.createExamTitle,
            ),
            if (widget.groupName != null) ...[
              const SizedBox(height: 2),
              Text(
                widget.groupName!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        actions: [
          if (_isAutoSaved)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.s12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_done_outlined,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.autoSavedDraftBadge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          final isCreating =
              (state is TeacherExamsLoaded && state.isCreating) ||
              state is ExamsLoading;
          if (isCreating) return const SizedBox.shrink();

          return FloatingActionButton.extended(
            onPressed: _addQuestion,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 4,
            icon: const Icon(Icons.add_rounded),
            label: Text(
              context.l10n.addQuestionAction,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
      body: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          final isCreating =
              (state is TeacherExamsLoaded && state.isCreating) ||
              state is ExamsLoading;

          final maxScoreNum =
              int.tryParse(_maxScoreController.text.trim()) ?? 0;
          final isPointsMismatched =
              maxScoreNum > 0 && maxScoreNum != _totalQuestionsPoints;

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
                    _buildDraftRecoveryBanner(context),
                    const SizedBox(height: AppSpacing.s16),
                  ],
                  // 1. General Settings Card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.s8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Text(
                              context.l10n.examGeneralSettings,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        AppTextField(
                          controller: _titleController,
                          labelText: context.l10n.examTitleField,
                          hintText: context.l10n.examTitleHint,
                          prefixIcon: const Icon(Icons.assignment_outlined),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return context.l10n.examTitleRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 650;
                            final defaultPointsWidget = Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: _defaultPointsController,
                                    labelText:
                                        context.l10n.defaultQuestionPointsLabel,
                                    hintText: '5',
                                    keyboardType: TextInputType.number,
                                    prefixIcon:
                                        const Icon(Icons.stars_outlined),
                                    onChanged: (val) {
                                      final pts = int.tryParse(val.trim());
                                      if (pts != null && pts > 0) {
                                        _defaultQuestionPoints = pts;
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Tooltip(
                                  message: context.l10n.applyPointsToAllTooltip,
                                  child: SizedBox(
                                    height: 48,
                                    child: ElevatedButton.icon(
                                      onPressed: isCreating
                                          ? null
                                          : _applyDefaultPointsToAllQuestions,
                                      icon: const Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        context.l10n.applyPointsToAllAction,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusMedium,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );

                            if (isCompact) {
                              return Column(
                                children: [
                                  AppTextField(
                                    controller: _durationController,
                                    labelText:
                                        context.l10n.durationMinutesField,
                                    keyboardType: TextInputType.number,
                                    prefixIcon:
                                        const Icon(Icons.timer_outlined),
                                    validator: (v) {
                                      final num = int.tryParse(v ?? '');
                                      if (num == null || num <= 0) {
                                        return context
                                            .l10n.positiveNumberRequired;
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.s12),
                                  defaultPointsWidget,
                                  const SizedBox(height: AppSpacing.s12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AppTextField(
                                          controller: _maxScoreController,
                                          labelText:
                                              context.l10n.maxScoreField,
                                          keyboardType: TextInputType.number,
                                          prefixIcon:
                                              const Icon(Icons.grade_outlined),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.s12),
                                      Expanded(
                                        child: AppTextField(
                                          controller: _passingScoreController,
                                          labelText:
                                              context.l10n.passingScoreField,
                                          keyboardType: TextInputType.number,
                                          prefixIcon: const Icon(
                                            Icons.verified_outlined,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }

                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        controller: _durationController,
                                        labelText:
                                            context.l10n.durationMinutesField,
                                        keyboardType: TextInputType.number,
                                        prefixIcon:
                                            const Icon(Icons.timer_outlined),
                                        validator: (v) {
                                          final num = int.tryParse(v ?? '');
                                          if (num == null || num <= 0) {
                                            return context
                                                .l10n.positiveNumberRequired;
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s12),
                                    Expanded(child: defaultPointsWidget),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.s12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: AppTextField(
                                        controller: _maxScoreController,
                                        labelText: context.l10n.maxScoreField,
                                        keyboardType: TextInputType.number,
                                        prefixIcon:
                                            const Icon(Icons.grade_outlined),
                                        onChanged: (_) => setState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.s12),
                                    Expanded(
                                      child: AppTextField(
                                        controller: _passingScoreController,
                                        labelText:
                                            context.l10n.passingScoreField,
                                        keyboardType: TextInputType.number,
                                        prefixIcon: const Icon(
                                          Icons.verified_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: AppSpacing.s12),

                        // Toggles
                        SwitchListTile(
                          title: Text(
                            context.l10n.shuffleQuestionsTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.shuffleQuestionsSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          value: _shuffle,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: isCreating
                              ? null
                              : (v) => setState(() => _shuffle = v),
                        ),
                        SwitchListTile(
                          title: Text(
                            context.l10n.showResultTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.showResultSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          value: _showResult,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: isCreating
                              ? null
                              : (v) => setState(() => _showResult = v),
                        ),
                        SwitchListTile(
                          title: Text(
                            context.l10n.allowRetakeTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.allowRetakeSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          value: _allowRetake,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: isCreating
                              ? null
                              : (v) => setState(() => _allowRetake = v),
                        ),
                        const Divider(height: 20),
                        SwitchListTile(
                          title: Text(
                            context.l10n.examPublishImmediatelyTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.examPublishImmediatelyDesc,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          value: _isPublished,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: isCreating
                              ? null
                              : (v) => setState(() => _isPublished = v),
                        ),
                        const Divider(height: 20),
                        SwitchListTile(
                          title: Text(
                            context.l10n.saveToQuestionBankToggle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            context.l10n.saveToQuestionBankTooltip,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          value: _saveToQuestionBank,
                          activeColor: AppColors.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: isCreating
                              ? null
                              : (v) => setState(() => _saveToQuestionBank = v),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // 2. Attached Exam Booklet (PDF) Card
                  _buildAttachedPdfCard(context, isCreating),

                  const SizedBox(height: AppSpacing.s20),

                  // 3. Score Balance & Summary Header
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                      vertical: AppSpacing.s12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      border: Border.all(
                        color: isPointsMismatched
                            ? AppColors.warning.withValues(alpha: 0.5)
                            : AppColors.border,
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.s16,
                      runSpacing: AppSpacing.s10,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: AppSpacing.s12,
                          runSpacing: AppSpacing.s4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                              ),
                              child: Text(
                                context.l10n.totalQuestionsSummary(
                                  _questions.length,
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            Text(
                              context.l10n.totalPointsSummary(
                                _totalQuestionsPoints,
                                maxScoreNum,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isPointsMismatched
                                    ? AppColors.warning
                                    : AppColors.textPrimary,
                              ),
                            ),
                            if (isPointsMismatched)
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _maxScoreController.text =
                                        _totalQuestionsPoints.toString();
                                    _passingScoreController.text =
                                        (_totalQuestionsPoints * 0.6)
                                            .round()
                                            .toString();
                                  });
                                },
                                icon: const Icon(
                                  Icons.sync_alt_rounded,
                                  size: 16,
                                  color: AppColors.warning,
                                ),
                                label: Text(
                                  context.l10n.autoAdjustMaxScore(
                                    _totalQuestionsPoints,
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Quick Uniform Points in Header
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.tune_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${context.l10n.defaultQuestionPointsLabel}:',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            SizedBox(
                              width: 52,
                              height: 34,
                              child: TextField(
                                controller: _defaultPointsController,
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: EdgeInsets.zero,
                                  filled: true,
                                  fillColor: AppColors.surface,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppColors.border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                    borderSide: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                onChanged: (v) {
                                  final pts = int.tryParse(v.trim());
                                  if (pts != null && pts > 0) {
                                    _defaultQuestionPoints = pts;
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: context.l10n.applyPointsToAllTooltip,
                              child: OutlinedButton.icon(
                                onPressed: isCreating
                                    ? null
                                    : _applyDefaultPointsToAllQuestions,
                                icon: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                ),
                                label: Text(
                                  context.l10n.applyPointsToAllAction,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                    color: AppColors.primary,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // 3. Questions Section Header
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.s12,
                    runSpacing: AppSpacing.s8,
                    children: [
                      Text(
                        context.l10n.questionsSectionTitle(_questions.length),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s4,
                        children: [
                          if (_questions.length > 1)
                            OutlinedButton.icon(
                              onPressed: isCreating
                                  ? null
                                  : (_questions.any((q) => q.isExpanded)
                                      ? _collapseAllQuestions
                                      : _expandAllQuestions),
                              icon: Icon(
                                _questions.any((q) => q.isExpanded)
                                    ? Icons.unfold_less_rounded
                                    : Icons.unfold_more_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _questions.any((q) => q.isExpanded)
                                    ? context.l10n.collapseAllQuestions
                                    : context.l10n.expandAllQuestions,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s12,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium,
                                  ),
                                ),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed:
                                isCreating ? null : _openQuestionBankPicker,
                            icon: const Icon(Icons.functions_rounded, size: 18),
                            label: Text(
                              context.l10n.importFromQuestionBankAction,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF0EA5E9),
                              side: const BorderSide(color: Color(0xFF0EA5E9)),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed:
                                isCreating ? null : _showBulkFillOptionsSheet,
                            icon: const Icon(
                              Icons.auto_fix_high_rounded,
                              size: 18,
                            ),
                            label: Text(context.l10n.bulkFillOptionsTitle),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: isCreating ? null : _addQuestion,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(context.l10n.addQuestionAction),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // 4. Questions List (Accordion Pattern)
                  ..._questions.asMap().entries.map((entry) {
                    final qIndex = entry.key;
                    final q = entry.value;

                    if (!q.isExpanded) {
                      return _buildCollapsedQuestionCard(
                        qIndex: qIndex,
                        q: q,
                        isCreating: isCreating,
                      );
                    }

                    return _buildExpandedQuestionCard(
                      qIndex: qIndex,
                      q: q,
                      isCreating: isCreating,
                    );
                  }),

                  // Bottom Add Question Card Button
                  InkWell(
                    onTap: isCreating ? null : _addQuestion,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s10),
                          Text(
                            context.l10n.addQuestionAction,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s24),

                  // Bottom Publish Action Button
                  AppButton(
                    text: (widget.existingExam != null || _savedExamId != null)
                        ? context.l10n.saveExamDraftChanges
                        : context.l10n.saveAndPublishExam,
                    icon: (widget.existingExam != null || _savedExamId != null)
                        ? Icons.save_rounded
                        : Icons.publish_rounded,
                    isFullWidth: true,
                    onPressed: (isCreating || _isSubmitting) ? null : _submitExam,
                    isLoading: isCreating || _isSubmitting,
                  ),
                  const SizedBox(
                    height: 80,
                  ), // Clearance for FloatingActionButton
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCollapsedQuestionCard({
    required int qIndex,
    required _DraftQuestion q,
    required bool isCreating,
  }) {
    final hasImage = (q.imageUrl != null && q.imageUrl!.trim().isNotEmpty) ||
        (q.localImageBytes != null);
    final text = q.textController.text.trim();
    final displayText = text.isNotEmpty
        ? text
        : (hasImage
            ? context.l10n.hasAttachedImage
            : context.l10n.questionSummaryEmpty);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s12),
      child: InkWell(
        onTap: () => _toggleQuestionExpanded(qIndex),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Text(
                      context.l10n.questionNumberTitle(qIndex + 1),
                      style: const TextStyle(
                        fontSize: 13,
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
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
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
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Text(
                      q.type.localizedLabel(context),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (hasImage) ...[
                    const SizedBox(width: AppSpacing.s8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (q.isUploadingImage) ...[
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0EA5E9),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ] else ...[
                            const Icon(
                              Icons.image_rounded,
                              size: 14,
                              color: Color(0xFF0EA5E9),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            context.l10n.hasAttachedImage,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0EA5E9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_questions.length > 1)
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      tooltip: context.l10n.removeOption,
                      onPressed: isCreating ? null : () => _removeQuestion(qIndex),
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.expand_more_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    tooltip: context.l10n.clickToEditQuestion,
                    onPressed: () => _toggleQuestionExpanded(qIndex),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                displayText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: text.isNotEmpty ? AppColors.textPrimary : AppColors.textMuted,
                  fontStyle: text.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedQuestionCard({
    required int qIndex,
    required _DraftQuestion q,
    required bool isCreating,
  }) {
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
                        color: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Text(
                        context.l10n.questionNumberTitle(
                          qIndex + 1,
                        ),
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
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                        border: Border.all(
                          color: AppColors.border,
                        ),
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
                    if (_questions.length > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                        tooltip: context.l10n.removeOption,
                        onPressed: isCreating
                            ? null
                            : () => _removeQuestion(qIndex),
                      ),
                    IconButton(
                      icon: const Icon(
                        Icons.expand_less_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                      tooltip: context.l10n.collapseAllQuestions,
                      onPressed: () => _toggleQuestionExpanded(qIndex),
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
                  return context.l10n.fillQuestionTextError(
                    qIndex + 1,
                  );
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
                  ? () => _handleQuestionImagePicked(
                        qIndex,
                        q.localImageBytes!,
                        'question_${qIndex + 1}.png',
                      )
                  : null,
              onBytesSelected: (bytes, filename) {
                _handleQuestionImagePicked(qIndex, bytes, filename);
              },
              onChanged: (data) {
                AppLogger.i('CreateExamPage', '📸 Question ${qIndex + 1} image updated: url=${data.imageUrl}, meta=${data.imageMeta}');
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

            // Question Type and Points Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<QuestionType>(
                    value: q.type,
                    decoration: InputDecoration(
                      labelText: context.l10n.questionTypeField,
                      prefixIcon: Icon(
                        q.type == QuestionType.trueFalse
                            ? Icons.rule_rounded
                            : Icons.list_alt_rounded,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: QuestionType.multipleChoice,
                        child: Text(
                          QuestionType.multipleChoice
                              .localizedLabel(context),
                        ),
                      ),
                      DropdownMenuItem(
                        value: QuestionType.trueFalse,
                        child: Text(
                          QuestionType.trueFalse.localizedLabel(
                            context,
                          ),
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
                      prefixIcon: const Icon(
                        Icons.stars_outlined,
                      ),
                    ),
                    onChanged: (v) {
                      setState(() {
                        q.points = int.tryParse(v) ?? 1;
                        _autoUpdateMaxScoreIfBalanced();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),

            // 5. Options Area (True/False or Multiple Choice)
            if (q.type == QuestionType.trueFalse)
              _buildTrueFalseSelector(q, isCreating)
            else
              _buildMultipleChoiceOptions(q, isCreating),
          ],
        ),
      ),
    );
  }

  /// Builds modern interactive True/False choice selector
  Widget _buildTrueFalseSelector(_DraftQuestion q, bool isCreating) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: 6),
            Text(
              context.l10n.selectCorrectAnswerPrompt,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        Row(
          children: [
            Expanded(
              child: _buildTrueFalseChoiceCard(
                label: context.l10n.optionTrue,
                isTrue: true,
                isSelected: q.trueFalseAnswer == true,
                onTap: isCreating
                    ? null
                    : () {
                        setState(() {
                          q.trueFalseAnswer = true;
                        });
                      },
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: _buildTrueFalseChoiceCard(
                label: context.l10n.optionFalse,
                isTrue: false,
                isSelected: q.trueFalseAnswer == false,
                onTap: isCreating
                    ? null
                    : () {
                        setState(() {
                          q.trueFalseAnswer = false;
                        });
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrueFalseChoiceCard({
    required String label,
    required bool isTrue,
    required bool isSelected,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s16,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isTrue
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1))
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: isSelected
                ? (isTrue ? AppColors.success : AppColors.error)
                : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isTrue ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isTrue ? AppColors.success : AppColors.error,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected
                        ? (isTrue ? AppColors.success : AppColors.error)
                        : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isTrue ? AppColors.success : AppColors.error).withValues(
                        alpha: 0.2,
                      )
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Text(
                isSelected ? context.l10n.correctAnswerBadge : '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isTrue ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds Multiple Choice options list with addition/deletion and correct option radio
  Widget _buildMultipleChoiceOptions(_DraftQuestion q, bool isCreating) {
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    context.l10n.optionsSelectCorrectPrompt,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  InkWell(
                    onTap: isCreating
                        ? null
                        : () => _quickFillQuestionOptions(q, ['A', 'B', 'C', 'D']),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 13,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.l10n.quickFillAbcdChip,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: isCreating
                        ? null
                        : () => _quickFillQuestionOptions(q, ['F', 'G', 'H', 'J']),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        context.l10n.quickFillFghjChip,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (q.options.length < 6)
              TextButton.icon(
                onPressed: isCreating ? null : () => _addOptionToQuestion(q),
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.l10n.addOption),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),

        ...q.options.asMap().entries.map((optEntry) {
          final optIdx = optEntry.key;
          final opt = optEntry.value;
          final letter = optIdx < letters.length
              ? letters[optIdx]
              : '${optIdx + 1}';

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s8,
                vertical: AppSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: opt.isCorrect
                    ? AppColors.success.withValues(alpha: 0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: opt.isCorrect
                      ? AppColors.success.withValues(alpha: 0.6)
                      : AppColors.border,
                  width: opt.isCorrect ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Radio<int>(
                    value: optIdx,
                    groupValue: q.options.indexWhere((o) => o.isCorrect),
                    activeColor: AppColors.success,
                    onChanged: isCreating
                        ? null
                        : (_) {
                            setState(() {
                              for (int i = 0; i < q.options.length; i++) {
                                q.options[i].isCorrect = (i == optIdx);
                              }
                            });
                          },
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: opt.isCorrect
                          ? AppColors.success
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: opt.isCorrect ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: TextFormField(
                      controller: opt.controller,
                      decoration: InputDecoration(
                        hintText: context.l10n.optionLetter(letter),
                        isDense: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  if (opt.isCorrect)
                    Container(
                      margin: const EdgeInsets.only(left: 8, right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Text(
                        context.l10n.correctAnswerBadge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  if (q.options.length > 2)
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      tooltip: context.l10n.removeOption,
                      onPressed: isCreating
                          ? null
                          : () => _removeOptionFromQuestion(q, optIdx),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
