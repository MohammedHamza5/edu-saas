import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/question_entity.dart';
import '../cubit/question_bank_cubit.dart';
import 'exam_extraction_success_view.dart';
import 'exam_upload_form_view.dart';

class UploadExamDialog extends StatefulWidget {
  const UploadExamDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<QuestionBankCubit>(),
        child: const UploadExamDialog(),
      ),
    );
  }

  @override
  State<UploadExamDialog> createState() => _UploadExamDialogState();
}

class _UploadExamDialogState extends State<UploadExamDialog> {
  final List<PlatformFile> _examFiles = [];
  PlatformFile? _answerKeyFile;
  bool _rightsAttested = true;
  bool _isProcessing = false;
  String? _statusMessage;
  String? _errorMessage;

  // Post-Extraction State
  bool _isDone = false;
  List<QuestionEntity> _extractedQuestions = const [];
  String _extractedFilename = '';

  // Group Assignment State
  List<Map<String, dynamic>> _groups = [];
  String? _selectedGroupId;
  final TextEditingController _examTitleController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(
    text: '60',
  );
  bool _showAssignForm = false;
  bool _isAssigning = false;
  String? _publishedExamId;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  @override
  void dispose() {
    _examTitleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroups() async {
    try {
      final list = await context.read<QuestionBankCubit>().getActiveGroups();
      if (mounted) {
        setState(() {
          _groups = list;
          if (_groups.isNotEmpty) {
            _selectedGroupId = _groups.first['id'] as String;
          }
        });
      }
    } catch (_) {
      // Ignored: groups can still be loaded if table is empty
    }
  }

  Future<void> _pickExamFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'tst', 'bnk'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _examFiles.addAll(result.files);
      });
    }
  }

  Future<void> _pickAnswerKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'csv', 'png', 'jpg'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _answerKeyFile = result.files.first;
      });
    }
  }

  Future<void> _startReconstruction() async {
    if (_examFiles.isEmpty) return;
    if (!_rightsAttested) return;

    final primaryFile = _examFiles.first;
    final fileBytes = primaryFile.bytes ?? <int>[];
    final l10n = context.l10n;
    final qbCubit = context.read<QuestionBankCubit>();

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _statusMessage = l10n.analyzingForensicStep;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted || !context.mounted) return;
      setState(() {
        _statusMessage = l10n.extractingFormulasStep;
      });

      // Call the real ingestion pipeline that writes to qb_documents, qb_questions, qb_question_revisions
      final questions = await qbCubit.ingestExamDocument(
        filename: primaryFile.name,
        bytes: fileBytes,
        answerKeyFilename: _answerKeyFile?.name,
        rightsAttestation: {
          'rights_attested': _rightsAttested,
          'attested_at': DateTime.now().toIso8601String(),
        },
      );

      if (!mounted) return;
      setState(() {
        _statusMessage = context.l10n.savingQuestionsStep;
      });

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _isDone = true;
        _extractedQuestions = questions;
        _extractedFilename = primaryFile.name;
        final cleanBase = primaryFile.name
            .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
            .replaceAll('_', ' ');
        _examTitleController.text = 'امتحان: $cleanBase';
      });
    } catch (e) {
      if (!mounted) return;

      final msg = e.toString();
      if (msg.contains('BACKGROUND_PROCESSING')) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'جاري معالجة الامتحان في الخلفية.. سيظهر في قائمة بنك الأسئلة فور الانتهاء.',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      setState(() {
        _isProcessing = false;
        _errorMessage = msg.replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _publishExamToGroup() async {
    if (_selectedGroupId == null || _examTitleController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isAssigning = true);
    try {
      final examId = await context
          .read<QuestionBankCubit>()
          .createExamFromQuestions(
            groupId: _selectedGroupId!,
            title: _examTitleController.text.trim(),
            durationMinutes:
                int.tryParse(_durationController.text.trim()) ?? 60,
            questions: _extractedQuestions,
          );

      if (!mounted) return;
      setState(() {
        _isAssigning = false;
        _publishedExamId = examId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAssigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to publish exam: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final adaptiveMaxHeight = media.size.height * 0.90;
    final adaptiveMaxWidth = math.min(640.0, media.size.width * 0.95);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: adaptiveMaxWidth,
          maxHeight: adaptiveMaxHeight,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _isDone
                ? ExamExtractionSuccessView(
                    extractedQuestions: _extractedQuestions,
                    extractedFilename: _extractedFilename,
                    publishedExamId: _publishedExamId,
                    showAssignForm: _showAssignForm,
                    isAssigning: _isAssigning,
                    groups: _groups,
                    selectedGroupId: _selectedGroupId,
                    examTitleController: _examTitleController,
                    durationController: _durationController,
                    onToggleAssignForm: (val) =>
                        setState(() => _showAssignForm = val),
                    onSelectedGroupChanged: (val) =>
                        setState(() => _selectedGroupId = val),
                    onPublishExam: _publishExamToGroup,
                    onNavigateToExams: () {
                      Navigator.of(context).pop();
                      context.push('/teacher/exams');
                    },
                    onClose: () => Navigator.of(context).pop(),
                  )
                : ExamUploadFormView(
                    examFiles: _examFiles,
                    answerKeyFile: _answerKeyFile,
                    rightsAttested: _rightsAttested,
                    isProcessing: _isProcessing,
                    statusMessage: _statusMessage,
                    errorMessage: _errorMessage,
                    onPickExamFiles: _pickExamFiles,
                    onPickAnswerKeyFile: _pickAnswerKeyFile,
                    onClearAnswerKeyFile: () =>
                        setState(() => _answerKeyFile = null),
                    onRightsAttestationChanged: (val) =>
                        setState(() => _rightsAttested = val),
                    onClearErrorMessage: () =>
                        setState(() => _errorMessage = null),
                    onStartReconstruction: _startReconstruction,
                    onClose: () => Navigator.of(context).pop(),
                  ),
          ),
        ),
      ),
    );
  }
}
