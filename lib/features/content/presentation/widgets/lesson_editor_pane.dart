import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/add_video_to_bank_dialog.dart';
import 'video_picker_sheet.dart';

/// The Right-side Pane for the Master-Detail Course Builder UX.
class LessonEditorPane extends StatefulWidget {
  final ContentEntity? editingLesson;
  final String groupId;
  final String groupName;
  final int defaultPassingScore;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const LessonEditorPane({
    super.key,
    required this.editingLesson,
    required this.groupId,
    required this.groupName,
    required this.defaultPassingScore,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<LessonEditorPane> createState() => _LessonEditorPaneState();
}

class _LessonEditorPaneState extends State<LessonEditorPane> {
  ContentEntity? _selectedVideo;
  late final TextEditingController _titleController;
  late final TextEditingController _customScoreController;

  String? _currentFileId;
  String? _currentFileName;
  PlatformFile? _pickedFile;
  Uint8List? _pickedFileBytes;
  bool _removePdf = false;

  String? _selectedExamId;
  List<Map<String, dynamic>> _availableExams = [];
  bool _isLoadingExams = true;

  bool _useCustomScore = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFromProps();
  }

  @override
  void didUpdateWidget(covariant LessonEditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingLesson?.id != widget.editingLesson?.id) {
      _initFromProps();
    }
  }

  void _initFromProps() {
    _titleController = TextEditingController(
      text: widget.editingLesson?.title ?? '',
    );
    _selectedVideo = widget.editingLesson;
    _currentFileId = widget.editingLesson?.file?.id;
    _currentFileName = widget.editingLesson?.file?.fileName;
    _selectedExamId = widget.editingLesson?.associatedExamId;

    _pickedFile = null;
    _pickedFileBytes = null;
    _removePdf = false;

    // We assume widget.editingLesson carries passingScore inside config, but
    // our entity doesn't map passingScoreOverride directly yet. We'll default.
    _useCustomScore = false;
    _customScoreController = TextEditingController(
      text: widget.defaultPassingScore.toString(),
    );

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
      setState(() => _isLoadingExams = true);
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
    final tenantId = _selectedVideo!.tenantId;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _pickedFile!.name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
    final storagePath = 'group_handouts/${widget.groupId}_${timestamp}_$safeName';

    await client.storage.from('group-content').uploadBinary(
          storagePath,
          Uint8List.fromList(_pickedFileBytes!),
          fileOptions:
              const FileOptions(contentType: 'application/pdf', upsert: true),
        );

    final fileRes = await client.from('files').insert({
      'tenant_id': tenantId,
      'content_id': _selectedVideo!.id,
      'storage_path': storagePath,
      'file_name': _pickedFile!.name,
      'mime_type': 'application/pdf',
      'file_size': _pickedFile!.size,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    }).select('id').single();

    return fileRes['id'] as String?;
  }

  Future<void> _handleSave() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a video first.')),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final fileId = await _uploadPdfIfNeeded();
      final passingScore = _useCustomScore
          ? (int.tryParse(_customScoreController.text.trim()) ??
              widget.defaultPassingScore)
          : null;

      final lessonTitle = _titleController.text.trim().isEmpty ||
              _titleController.text.trim() == _selectedVideo!.title
          ? null
          : _titleController.text.trim();

      if (!mounted) return;
      final cubit = context.read<ContentCubit>();
      await cubit.assignContentToGroups(
        contentId: _selectedVideo!.id,
        groupIds: [widget.groupId],
        groupConfigs: [
          {
            'group_id': widget.groupId,
            if (lessonTitle != null) 'custom_title': lessonTitle,
            if (fileId != null) 'file_id': fileId,
            if (fileId == null && _removePdf) 'file_id': null,
            if (_selectedExamId != null) 'associated_exam_id': _selectedExamId,
            if (_selectedExamId == null) 'associated_exam_id': null,
            if (passingScore != null) 'passing_score_override': passingScore,
            if (passingScore == null) 'passing_score_override': null,
          }
        ],
      );
      
      widget.onSaved();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred while saving.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickVideoFromBank() async {
    final cubit = context.read<ContentCubit>();
    if (cubit.state is! ContentLoaded) {
      await cubit.loadCentralVideoBank();
    }
    if (!mounted) return;
    final video = await VideoPickerSheet.show(context);
    if (video != null) {
      setState(() {
        _selectedVideo = video;
        if (_titleController.text.isEmpty) {
          _titleController.text = video.title;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.editingLesson != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Lesson' : 'Add New Lesson',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onCancel,
                  tooltip: context.l10n.cancel,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Source Video Selection
                  Text(
                    'Source Video',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  if (_selectedVideo != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.play_circle_fill_rounded,
                              color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedVideo!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (!isEditing)
                            IconButton(
                              icon: const Icon(Icons.change_circle_outlined,
                                  color: AppColors.primary),
                              onPressed: _pickVideoFromBank,
                              tooltip: 'Change Video',
                            ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: 'Select from Library',
                            icon: Icons.video_library_rounded,
                            onPressed: _pickVideoFromBank,
                            variant: AppButtonVariant.outlined,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: AppButton(
                            text: 'Upload New',
                            icon: Icons.cloud_upload_rounded,
                            onPressed: () async {
                              await AddVideoToBankDialog.show(
                                context,
                                onCreated: (created) {
                                  if (!mounted) return;
                                  setState(() {
                                    _selectedVideo = created;
                                    _titleController.text = created.title;
                                  });
                                },
                              );
                            },
                            variant: AppButtonVariant.outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s24),

                  // 2. Lesson Title
                  Text(
                    'Lesson Title (Optional Override)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  AppTextField(
                    controller: _titleController,
                    hintText: _selectedVideo?.title ?? 'Enter lesson title',
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  // 3. Attach PDF
                  Text(
                    'Study Material (PDF)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  if (!_removePdf &&
                      (_pickedFile != null || _currentFileName != null)) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded,
                              color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pickedFile?.name ?? _currentFileName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Colors.orange),
                            onPressed: () => setState(() {
                              _removePdf = true;
                              _pickedFile = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    AppButton(
                      text: 'Upload PDF',
                      icon: Icons.upload_file_rounded,
                      onPressed: _pickPdf,
                      variant: AppButtonVariant.outlined,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s24),

                  // 4. Attach Quiz
                  Text(
                    'Lesson Quiz',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  if (_isLoadingExams)
                    const Center(child: CircularProgressIndicator())
                  else if (_availableExams.isEmpty)
                    const Text(
                      'No quizzes available in this group.',
                      style: TextStyle(color: AppColors.textMuted),
                    )
                  else
                    DropdownButtonFormField<String?>(
                      value: _selectedExamId,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('No Quiz'),
                        ),
                        ..._availableExams.map((e) => DropdownMenuItem(
                              value: e['id'] as String,
                              child: Text(e['title'] as String),
                            )),
                      ],
                      onChanged: (val) => setState(() => _selectedExamId = val),
                    ),
                  const SizedBox(height: AppSpacing.s24),

                  // 5. Passing Score
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Passing Score Requirements',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Switch(
                        value: _useCustomScore,
                        onChanged: (val) =>
                            setState(() => _useCustomScore = val),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  if (_useCustomScore)
                    AppTextField(
                      controller: _customScoreController,
                      keyboardType: TextInputType.number,
                      label: 'Custom Passing Score',
                      suffixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text('%', style: TextStyle(fontSize: 16))],
                        ),
                      ),
                    )
                  else
                    Text(
                      'Using default group passing score (${widget.defaultPassingScore}%)',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
          ),

          // Footer
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(context.l10n.cancel),
                ),
                const SizedBox(width: AppSpacing.s8),
                AppButton(
                  text: context.l10n.save,
                  isLoading: _isSaving,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
