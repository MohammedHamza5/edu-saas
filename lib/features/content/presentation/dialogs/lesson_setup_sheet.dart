import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/content_cubit.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/content_entity.dart';
import '../widgets/lesson_setup_material_section.dart';
import '../widgets/lesson_setup_passing_score_section.dart';
import '../widgets/lesson_setup_quiz_section.dart';
import '../widgets/lesson_setup_video_preview_card.dart';

/// The canonical Lesson Setup sheet — used both when adding a new lesson
/// and when editing an existing lesson.
///
/// Configures:
///   - Lesson title (override of video title)
///   - Study material (PDF per-course)
///   - Lesson quiz (selects from group's exams)
///   - Passing score (course default or custom)
///
/// Calls [ContentCubit.assignContentToGroups] on save.
class LessonSetupSheet extends StatefulWidget {
  final ContentEntity video;
  final String groupId;
  final String groupName;
  final int defaultPassingScore;

  // Pre-filled values when editing an existing lesson
  final String? existingLessonTitle;
  final String? existingFileId;
  final String? existingFileName;
  final String? existingExamId;
  final String? existingExamTitle;
  final int? existingPassingScore;

  final Future<bool> Function({
    required String contentId,
    required String groupId,
    required String? lessonTitle,
    required String? fileId,
    required String? examId,
    required int? passingScoreOverride,
  })
  onSave;

  const LessonSetupSheet({
    super.key,
    required this.video,
    required this.groupId,
    required this.groupName,
    required this.defaultPassingScore,
    required this.onSave,
    this.existingLessonTitle,
    this.existingFileId,
    this.existingFileName,
    this.existingExamId,
    this.existingExamTitle,
    this.existingPassingScore,
  });

  static Future<bool> show(
    BuildContext context, {
    required ContentEntity video,
    required String groupId,
    required String groupName,
    required int defaultPassingScore,
    required Future<bool> Function({
      required String contentId,
      required String groupId,
      required String? lessonTitle,
      required String? fileId,
      required String? examId,
      required int? passingScoreOverride,
    })
    onSave,
    String? existingLessonTitle,
    String? existingFileId,
    String? existingFileName,
    String? existingExamId,
    String? existingExamTitle,
    int? existingPassingScore,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LessonSetupSheet(
        video: video,
        groupId: groupId,
        groupName: groupName,
        defaultPassingScore: defaultPassingScore,
        onSave: onSave,
        existingLessonTitle: existingLessonTitle,
        existingFileId: existingFileId,
        existingFileName: existingFileName,
        existingExamId: existingExamId,
        existingExamTitle: existingExamTitle,
        existingPassingScore: existingPassingScore,
      ),
    );
    return result == true;
  }

  @override
  State<LessonSetupSheet> createState() => _LessonSetupSheetState();
}

class _LessonSetupSheetState extends State<LessonSetupSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _customScoreController;

  // PDF state
  String? _currentFileId;
  String? _currentFileName;
  PlatformFile? _pickedFile;
  Uint8List? _pickedFileBytes;
  bool _removePdf = false;

  // Quiz state
  String? _selectedExamId;
  List<Map<String, dynamic>> _availableExams = [];
  bool _isLoadingExams = true;

  // Passing score state
  bool _useCustomScore = false;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.existingLessonTitle ?? widget.video.title,
    );
    _currentFileId = widget.existingFileId;
    _currentFileName = widget.existingFileName;
    _selectedExamId = widget.existingExamId;

    if (widget.existingPassingScore != null &&
        widget.existingPassingScore != widget.defaultPassingScore) {
      _useCustomScore = true;
      _customScoreController = TextEditingController(
        text: widget.existingPassingScore.toString(),
      );
    } else {
      _customScoreController = TextEditingController(
        text: widget.defaultPassingScore.toString(),
      );
    }

    _loadExams();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customScoreController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    try {
      final exams = await context.read<ContentCubit>().getAvailableExamsSummary();
      if (mounted) {
        setState(() {
          _availableExams = exams;
          _isLoadingExams = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingExams = false);
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFile = file;
          _pickedFileBytes = file.bytes;
          _removePdf = false;
        });
      }
    } catch (_) {}
  }

  Future<String?> _uploadPdfIfNeeded() async {
    if (_removePdf) return null;
    if (_pickedFile == null || _pickedFileBytes == null) return _currentFileId;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _pickedFile!.name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_.-]'),
      '_',
    );
    final storagePath = 'groups/${widget.groupId}/${timestamp}_$safeName';

    final cubit = context.read<ContentCubit>();
    return await cubit.uploadAndCreateFileRecord(
      tenantId: widget.video.tenantId,
      contentId: widget.video.id,
      fileName: _pickedFile!.name,
      mimeType: 'application/pdf',
      fileBytes: _pickedFileBytes!,
      storagePath: storagePath,
    );
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final fileId = await _uploadPdfIfNeeded();
      final passingScore = _useCustomScore
          ? (int.tryParse(_customScoreController.text.trim()) ??
                widget.defaultPassingScore)
          : null;

      final success = await widget.onSave(
        contentId: widget.video.id,
        groupId: widget.groupId,
        lessonTitle:
            _titleController.text.trim().isEmpty ||
                _titleController.text.trim() == widget.video.title
            ? null
            : _titleController.text.trim(),
        fileId: fileId,
        examId: _selectedExamId,
        passingScoreOverride: passingScore,
      );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotAddLesson),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final hasPdf =
        !_removePdf && (_pickedFile != null || _currentFileName != null);
    final pdfName = _pickedFile?.name ?? _currentFileName;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: AppSpacing.s8,
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        bottom: bottomInset > 0 ? bottomInset + AppSpacing.s16 : AppSpacing.s40,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(
                  top: AppSpacing.s8,
                  bottom: AppSpacing.s16,
                ),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.lessonSetupTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.groupName,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),

            // Video thumbnail & name (read-only)
            LessonSetupVideoPreviewCard(video: widget.video),
            const SizedBox(height: AppSpacing.s20),

            // Lesson Title
            AppTextField(
              controller: _titleController,
              label: l10n.lessonTitleLabel,
              hintText: widget.video.title,
            ),
            const SizedBox(height: AppSpacing.s20),

            // Study Material (PDF)
            LessonSetupMaterialSection(
              hasPdf: hasPdf,
              pdfName: pdfName,
              onPickPdf: _pickPdf,
              onRemovePdf: () => setState(() {
                _removePdf = true;
                _pickedFile = null;
                _pickedFileBytes = null;
              }),
            ),
            const SizedBox(height: AppSpacing.s20),

            // Lesson Quiz
            LessonSetupQuizSection(
              isLoadingExams: _isLoadingExams,
              selectedExamId: _selectedExamId,
              availableExams: _availableExams,
              onExamChanged: (val) => setState(() => _selectedExamId = val),
            ),
            const SizedBox(height: AppSpacing.s20),

            // Passing Score
            LessonSetupPassingScoreSection(
              useCustomScore: _useCustomScore,
              defaultPassingScore: widget.defaultPassingScore,
              customScoreController: _customScoreController,
              onToggleCustomScore: (val) => setState(() => _useCustomScore = val),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Save button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
              ),
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.addLesson,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
