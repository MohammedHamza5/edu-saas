import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/content_entity.dart';
import '../../../../core/network/supabase_service.dart';

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
  }) onSave;

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
    _descriptionController =
        TextEditingController(text: content?.description ?? '');
    _fileNameController =
        TextEditingController(text: content?.file?.fileName ?? '');

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
      final res = await SupabaseService.client
          .from('exams')
          .select('id, title')
          .eq('group_id', widget.groupId)
          .order('created_at');
      if (mounted) {
        setState(() {
          _availableExams = List<Map<String, dynamic>>.from(res);
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
      final isPdfOrVideo = _selectedType == ContentType.pdf || _selectedType == ContentType.video;
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

    if (_hasAttachment &&
        _fileNameController.text.trim().isNotEmpty) {
      fileName = _fileNameController.text.trim();
      final sanitizedName =
          fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
      storagePath =
          'groups/${widget.groupId}/content/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      final lower = fileName.toLowerCase();
      mimeType = (lower.endsWith('.pdf') || _selectedType == ContentType.pdf || _selectedType == ContentType.video)
          ? 'application/pdf'
          : (_selectedType == ContentType.image || lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
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
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
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
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
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

                // Type Selection
                Text(
                  context.l10n.materialTypeLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s6,
                  children: ContentType.values.map((type) {
                    final isSelected = _selectedType == type;
                    return ChoiceChip(
                      label: Text(type.localizedLabel(context)),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withAlpha(30),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedType = type);
                      },
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: AppSpacing.s16),

                // Publication Status Selection
                Text(
                  context.l10n.publicationStatusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: AppSpacing.s6,
                  children: [
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.edit_note_rounded,
                              size: 14, color: AppColors.warning),
                          const SizedBox(width: 4),
                          Text(context.l10n.draftPrivateNotice),
                        ],
                      ),
                      selected: _selectedStatus == ContentStatus.draft,
                      selectedColor: AppColors.warning.withAlpha(30),
                      onSelected: (selected) {
                        if (selected) {
                          setState(
                              () => _selectedStatus = ContentStatus.draft);
                        }
                      },
                    ),
                    ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              size: 14, color: AppColors.success),
                          const SizedBox(width: 4),
                          Text(context.l10n.publishImmediateNotice),
                        ],
                      ),
                      selected: _selectedStatus == ContentStatus.published,
                      selectedColor: AppColors.success.withAlpha(30),
                      onSelected: (selected) {
                        if (selected) {
                          setState(
                              () => _selectedStatus = ContentStatus.published);
                        }
                      },
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.s16),

                if (_selectedType == ContentType.video) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      border: Border.all(color: AppColors.primary.withAlpha(40)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 20, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.s10),
                        Expanded(
                          child: Text(
                            context.l10n.videoStreamingNotice,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ],

                // Attachment Section (for all materials, including video lesson notes)
                AppCard(
                  variant: AppCardVariant.standard,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckboxListTile(
                        title: Text(
                          _selectedType == ContentType.video
                              ? context.l10n.attachVideoMaterialNotice
                              : context.l10n.attachMaterialFile,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: _selectedType == ContentType.video
                            ? Text(
                                context.l10n.attachVideoMaterialHint,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              )
                            : null,
                        value: _hasAttachment,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setState(() => _hasAttachment = val ?? false);
                        },
                      ),
                      if (_hasAttachment) ...[
                        const SizedBox(height: AppSpacing.s6),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _fileNameController,
                                labelText: context.l10n.attachedFileNameLabel,
                                hintText: context.l10n.attachedFileNameHint,
                                prefixIcon:
                                    const Icon(Icons.attach_file_rounded),
                                validator: (val) {
                                  if (_hasAttachment &&
                                      (val == null || val.trim().isEmpty)) {
                                    return context.l10n.fileNameRequired;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _pickFile,
                                icon: const Icon(Icons.file_upload_outlined,
                                    size: 18),
                                label: Text(context.l10n.browseFileAction),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.surfaceVariant,
                                  foregroundColor: AppColors.textPrimary,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusSmall),
                                    side: const BorderSide(
                                        color: AppColors.border),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s24),

                if (_isLoading) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withAlpha(20),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                      border: Border.all(color: AppColors.warning.withAlpha(80)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 20, color: AppColors.warning),
                        const SizedBox(width: AppSpacing.s10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.uploadingFileKeepPageOpen,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.doNotClosePageWarning,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              const LinearProgressIndicator(
                                minHeight: 4,
                                backgroundColor: AppColors.surfaceVariant,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],
                // Sequential Learning Section
                AppCard(
                  variant: AppCardVariant.standard,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.sequentialLearningSectionTitle,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      
                      // Associated Exam
                      if (_isLoadingExams)
                        const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                      else
                        DropdownButtonFormField<String?>(
                          value: _availableExams.any((e) => e['id'] == _selectedAssociatedExamId) ? _selectedAssociatedExamId : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.l10n.associatedExamLabel,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(context.l10n.noneOption, style: const TextStyle(color: AppColors.textSecondary)),
                            ),
                            ..._availableExams.map((exam) {
                              return DropdownMenuItem(
                                value: exam['id'] as String,
                                child: Text(
                                  exam['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedAssociatedExamId = val);
                          },
                        ),

                      const SizedBox(height: AppSpacing.s12),

                      // Prerequisite Exam
                      if (!_isLoadingExams)
                        DropdownButtonFormField<String?>(
                          value: _availableExams.any((e) => e['id'] == _selectedPrerequisiteExamId) ? _selectedPrerequisiteExamId : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.l10n.prerequisiteExamLabel,
                            border: const OutlineInputBorder(),
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(context.l10n.noneOption, style: const TextStyle(color: AppColors.textSecondary)),
                            ),
                            ..._availableExams.map((exam) {
                              return DropdownMenuItem(
                                value: exam['id'] as String,
                                child: Text(
                                  exam['title'] as String,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() => _selectedPrerequisiteExamId = val);
                          },
                        ),
                    ],
                  ),
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
                      text: isEdit ? context.l10n.saveChanges : context.l10n.createAndSave,
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
