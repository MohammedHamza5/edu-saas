import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/content_entity.dart';

class CreateEditContentDialog extends StatefulWidget {
  final String groupId;
  final ContentEntity? initialContent;
  final Future<bool> Function({
    required String title,
    String? description,
    required ContentType type,
    required ContentStatus status,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
  }) onSave;

  const CreateEditContentDialog({
    super.key,
    required this.groupId,
    this.initialContent,
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

  @override
  void initState() {
    super.initState();
    final content = widget.initialContent;
    _titleController = TextEditingController(text: content?.title ?? '');
    _descriptionController =
        TextEditingController(text: content?.description ?? '');
    _fileNameController =
        TextEditingController(text: content?.file?.fileName ?? '');

    _selectedType = content?.type ?? ContentType.pdf;
    _selectedStatus = content?.status ?? ContentStatus.draft;
    _hasAttachment = content?.hasAttachment ?? false;
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
      final result = await FilePicker.platform.pickFiles(
        type: _selectedType == ContentType.pdf
            ? FileType.custom
            : _selectedType == ContentType.image
                ? FileType.image
                : FileType.any,
        allowedExtensions: _selectedType == ContentType.pdf ? ['pdf'] : null,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _hasAttachment = true;
          _fileNameController.text = file.name;
          _pickedFileSize = file.size;
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
      final sanitizedName =
          fileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
      storagePath =
          'groups/${widget.groupId}/content/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';
      mimeType = _selectedType == ContentType.pdf
          ? 'application/pdf'
          : _selectedType == ContentType.image
              ? 'image/jpeg'
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

    return Dialog(
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
                            ? 'تعديل المحتوى التعليمي'
                            : 'إضافة محتوى تعليمي جديد',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.s16),

                // Title Field
                AppTextField(
                  controller: _titleController,
                  labelText: 'عنوان المحتوى *',
                  hintText: 'مثال: مذكرة قوانين الهندسة وحساب المثلثات',
                  prefixIcon: const Icon(Icons.title_rounded),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'يرجى إدخال عنوان المحتوى';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.s12),

                // Description Field
                AppTextField(
                  controller: _descriptionController,
                  labelText: 'وصف إضافي أو تعليمات للطلاب (اختياري)',
                  hintText: 'توضيح النقاط المهمة أو الملاحظات المرفقة…',
                  maxLines: 2,
                  prefixIcon: const Icon(Icons.notes_rounded),
                ),

                const SizedBox(height: AppSpacing.s16),

                // Type Selection
                Text(
                  'نوع المادة التعليمية:',
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
                      label: Text(type.labelAr),
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
                  'حالة النشر:',
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
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_note_rounded,
                              size: 14, color: AppColors.warning),
                          SizedBox(width: 4),
                          Text('مسودة خاصة (لا تظهر للطلاب)'),
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
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: AppColors.success),
                          SizedBox(width: 4),
                          Text('نشر فوري للطلاب'),
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

                // Attachment Section
                AppCard(
                  variant: AppCardVariant.standard,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CheckboxListTile(
                        title: const Text(
                          'إرفاق ملف تعليمي (PDF / صورة / مستند)',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold),
                        ),
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
                                labelText: 'اسم الملف المرفق *',
                                hintText: 'مثال: Calculus_Formulas_Sheet.pdf',
                                prefixIcon:
                                    const Icon(Icons.attach_file_rounded),
                                validator: (val) {
                                  if (_hasAttachment &&
                                      (val == null || val.trim().isEmpty)) {
                                    return 'يرجى إدخال أو اختيار اسم الملف';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                              ),
                              onPressed: _pickFile,
                              icon: const Icon(Icons.folder_open_rounded,
                                  size: 18),
                              label: const Text('تصفح'),
                            ),
                          ],
                        ),
                      ],
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
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    AppButton(
                      text: isEdit ? 'حفظ التعديلات' : 'إنشاء وحفظ',
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
  );
  }
}
