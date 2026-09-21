import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/content_entity.dart';

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
  }) onSave;

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
    }) onSave,
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
      final client = SupabaseService.client;
      final res = await client
          .from('exams')
          .select('id, title')
          .eq('group_id', widget.groupId)
          .order('title');
      if (mounted) {
        setState(() {
          _availableExams = List<Map<String, dynamic>>.from(res as List);
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

    final client = SupabaseService.client;
    final tenantId = widget.video.tenantId;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _pickedFile!.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
    final storagePath =
        'group_handouts/${widget.groupId}_${timestamp}_$safeName';

    await client.storage.from('group-content').uploadBinary(
          storagePath,
          Uint8List.fromList(_pickedFileBytes!),
          fileOptions:
              const FileOptions(contentType: 'application/pdf', upsert: true),
        );

    final fileRes = await client.from('files').insert({
      'tenant_id': tenantId,
      'content_id': widget.video.id,
      'storage_path': storagePath,
      'file_name': _pickedFile!.name,
      'mime_type': 'application/pdf',
      'file_size': _pickedFile!.size,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();

    return fileRes['id'] as String?;
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
        lessonTitle: _titleController.text.trim().isEmpty ||
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

    final hasPdf = !_removePdf &&
        (_pickedFile != null || _currentFileName != null);
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
                margin: const EdgeInsets.only(top: AppSpacing.s8, bottom: AppSpacing.s16),
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
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.play_circle_fill_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.video.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          widget.video.videoProvider == 'youtube'
                              ? 'YouTube'
                              : 'Bunny Stream',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s20),

            // Lesson Title
            AppTextField(
              controller: _titleController,
              label: l10n.lessonTitleLabel,
              hintText: widget.video.title,
            ),
            const SizedBox(height: AppSpacing.s20),

            // Study Material (PDF)
            _buildSectionLabel(l10n.studyMaterial, Icons.picture_as_pdf_rounded,
                const Color(0xFFEA580C)),
            const SizedBox(height: AppSpacing.s8),
            if (hasPdf) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(
                    color: const Color(0xFFEA580C).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded,
                        color: Color(0xFFEA580C), size: 20),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        pdfName ?? 'document.pdf',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickPdf,
                      child: Text(l10n.replacePdf,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _removePdf = true;
                        _pickedFile = null;
                        _pickedFileBytes = null;
                      }),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.error),
                      child: Text(l10n.removePdf,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(l10n.uploadPdf),
                onPressed: _pickPdf,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEA580C),
                  side: const BorderSide(
                      color: Color(0xFFEA580C), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.s20),

            // Lesson Quiz
            _buildSectionLabel(
                l10n.lessonQuizLabel, Icons.quiz_rounded, AppColors.primary),
            const SizedBox(height: AppSpacing.s8),
            if (_isLoadingExams)
              const LinearProgressIndicator()
            else ...[
              DropdownButtonFormField<String>(
                value: _selectedExamId,
                decoration: InputDecoration(
                  hintText: l10n.lessonQuizHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(
                      l10n.lessonQuizHint,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  ..._availableExams.map((exam) {
                    return DropdownMenuItem<String>(
                      value: exam['id'] as String,
                      child: Text(
                        exam['title'] as String? ?? '',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedExamId = val;
                  });
                },
              ),
              if (_selectedExamId != null) ...[
                const SizedBox(height: AppSpacing.s8),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          l10n.lessonQuizSequentialRequirement,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.s20),

            // Passing Score
            _buildSectionLabel(
                l10n.passingScoreLabel, Icons.percent_rounded, AppColors.success),
            const SizedBox(height: AppSpacing.s8),
            Column(
              children: [
                RadioListTile<bool>(
                  value: false,
                  groupValue: _useCustomScore,
                  onChanged: (v) => setState(() => _useCustomScore = false),
                  title: Text(
                    l10n.useCourseDefault(widget.defaultPassingScore),
                    style: const TextStyle(fontSize: 14),
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.primary,
                ),
                RadioListTile<bool>(
                  value: true,
                  groupValue: _useCustomScore,
                  onChanged: (v) => setState(() => _useCustomScore = true),
                  title: Row(
                    children: [
                      Text(
                        l10n.customPassingScore,
                        style: const TextStyle(fontSize: 14),
                      ),
                      if (_useCustomScore) ...[
                        const SizedBox(width: AppSpacing.s12),
                        SizedBox(
                          width: 80,
                          child: TextFormField(
                            controller: _customScoreController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              suffixText: '%',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeColor: AppColors.primary,
                ),
              ],
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
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
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

  Widget _buildSectionLabel(String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.s8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
