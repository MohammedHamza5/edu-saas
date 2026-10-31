import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/content_cubit.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/content_entity.dart';
import '../widgets/content_attachment_section.dart';
import '../widgets/content_sequential_learning_section.dart';
import '../widgets/content_type_status_selector.dart';

class CreateEditContentDialog extends StatefulWidget {
  final String groupId;
  final ContentEntity? initialContent;
  final ContentType? initialType;
  final Future<bool> Function({
    required String title,
    String? description,
    required ContentType type,
    required ContentStatus status,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  })
  onSave;

  const CreateEditContentDialog({
    super.key,
    required this.groupId,
    this.initialContent,
    this.initialType,
    required this.onSave,
  });

  @override
  State<CreateEditContentDialog> createState() =>
      _CreateEditContentDialogState();
}

class _CreateEditContentDialogState extends State<CreateEditContentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _fileNameController;

  late ContentType _selectedType;
  late ContentStatus _selectedStatus;
  bool _isLoading = false;
  bool _hasAttachment = false;
  int? _pickedFileSize;
  Uint8List? _pickedFileBytes;

  String? _selectedAssociatedExamId;
  String? _selectedPrerequisiteExamId;
  List<Map<String, dynamic>> _availableExams = [];
  bool _isLoadingExams = false;

  @override
  void initState() {
    super.initState();
    final content = widget.initialContent;
    _titleController = TextEditingController(text: content?.title ?? '');
    _descriptionController = TextEditingController(
      text: content?.description ?? '',
    );
    _fileNameController = TextEditingController(
      text: content?.file?.fileName ?? '',
    );

    _selectedType = content?.type ?? widget.initialType ?? ContentType.pdf;
    _selectedStatus = content?.status ?? ContentStatus.draft;
    _hasAttachment = content?.hasAttachment ?? false;
    _selectedAssociatedExamId = content?.associatedExamId;
    _selectedPrerequisiteExamId = content?.prerequisiteExamId;

    _loadExams();
  }

  Future<void> _loadExams() async {
    setState(() => _isLoadingExams = true);
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _fileNameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final isPdfOrVideo =
          _selectedType == ContentType.pdf ||
          _selectedType == ContentType.video;
      final result = await FilePicker.platform.pickFiles(
        type: isPdfOrVideo
            ? FileType.custom
            : _selectedType == ContentType.image
            ? FileType.image
            : FileType.any,
        allowedExtensions: isPdfOrVideo ? ['pdf', 'doc', 'docx'] : null,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _hasAttachment = true;
          _fileNameController.text = file.name;
          _pickedFileSize = file.size;
          _pickedFileBytes = file.bytes;
          if (_titleController.text.trim().isEmpty) {
            final cleanName = file.name
                .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                .replaceAll(RegExp(r'[_-]'), ' ')
                .trim();
            _titleController.text = cleanName;
          }
        });
      }
    } catch (_) {
      // Fallback to manual entry
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? storagePath;
    String? fileName;
    String? mimeType;
    int? fileSize;

    if (_hasAttachment && _fileNameController.text.trim().isNotEmpty) {
      fileName = _fileNameController.text.trim();
      final sanitizedName = fileName.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9_.-]'),
        '_',
      );
      storagePath =
          'groups/${widget.groupId}/content/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      final lower = fileName.toLowerCase();
      mimeType =
          (lower.endsWith('.pdf') ||
              _selectedType == ContentType.pdf ||
              _selectedType == ContentType.video)
          ? 'application/pdf'
          : (_selectedType == ContentType.image ||
                lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg'))
          ? 'image/jpeg'
          : lower.endsWith('.png')
          ? 'image/png'
          : 'application/octet-stream';
      fileSize = _pickedFileSize ?? (1024 * 500); // 500KB fallback
    }

    final success = await widget.onSave(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      type: _selectedType,
      status: _selectedStatus,
      fileName: fileName,
      storagePath: storagePath,
      mimeType: mimeType,
      fileSize: fileSize,
      fileBytes: _pickedFileBytes,
      associatedExamId: _selectedAssociatedExamId,
      prerequisiteExamId: _selectedPrerequisiteExamId,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.initialContent != null;

    return PopScope(
      canPop: !_isLoading,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: SizedBox(
            width: double.infinity,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                          ),
                          child: Icon(
                            isEdit
                                ? Icons.edit_note_rounded
                                : Icons.post_add_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Text(
                            isEdit
                                ? context.l10n.editContentDialogTitle
                                : context.l10n.newContentDialogTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // Title Field
                    AppTextField(
                      controller: _titleController,
                      labelText: context.l10n.contentTitleInputLabel,
                      hintText: context.l10n.contentTitleInputHint,
                      prefixIcon: const Icon(Icons.title_rounded),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return context.l10n.contentTitleRequired;
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.s12),

                    // Description Field
                    AppTextField(
                      controller: _descriptionController,
                      labelText: context.l10n.contentDescInputLabel,
                      hintText: context.l10n.contentDescInputHint,
                      maxLines: 2,
                      prefixIcon: const Icon(Icons.notes_rounded),
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // 1. Type & Status Selectors
                    ContentTypeStatusSelector(
                      selectedType: _selectedType,
                      selectedStatus: _selectedStatus,
                      onTypeChanged: (type) =>
                          setState(() => _selectedType = type),
                      onStatusChanged: (status) =>
                          setState(() => _selectedStatus = status),
                    ),

                    // 2. Attachment Section
                    ContentAttachmentSection(
                      selectedType: _selectedType,
                      hasAttachment: _hasAttachment,
                      fileNameController: _fileNameController,
                      isLoading: _isLoading,
                      onAttachmentChanged: (val) =>
                          setState(() => _hasAttachment = val),
                      onPickFile: _pickFile,
                    ),

                    const SizedBox(height: AppSpacing.s24),

                    // 3. Sequential Learning Section
                    ContentSequentialLearningSection(
                      isLoadingExams: _isLoadingExams,
                      availableExams: _availableExams,
                      selectedAssociatedExamId: _selectedAssociatedExamId,
                      selectedPrerequisiteExamId: _selectedPrerequisiteExamId,
                      onAssociatedExamChanged: (val) =>
                          setState(() => _selectedAssociatedExamId = val),
                      onPrerequisiteExamChanged: (val) =>
                          setState(() => _selectedPrerequisiteExamId = val),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: Text(context.l10n.cancel),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        AppButton(
                          text: isEdit
                              ? context.l10n.saveChanges
                              : context.l10n.createAndSave,
                          icon: isEdit
                              ? Icons.check_circle_outline_rounded
                              : Icons.add_circle_outline_rounded,
                          isLoading: _isLoading,
                          onPressed: _handleSubmit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
