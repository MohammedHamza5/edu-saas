import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../domain/entities/exam_folder_entity.dart';

const List<String> kExamFolderColors = [
  '#5B4FE0', // Deep Indigo (Academic)
  '#0284C7', // Ocean Blue
  '#10B981', // Emerald Green
  '#F59E0B', // Amber
  '#8B5CF6', // Purple
  '#EF4444', // Red
  '#0D9488', // Teal
];

Color parseHexColor(String? colorStr, {Color defaultColor = AppColors.primary}) {
  if (colorStr == null || colorStr.isEmpty) return defaultColor;
  try {
    final hex = colorStr.replaceAll('#', '');
    if (hex.length == 6) {
      return Color(int.parse('FF$hex', radix: 16));
    }
  } catch (_) {}
  return defaultColor;
}

class CreateOrEditExamFolderDialog extends StatefulWidget {
  final ExamFolderEntity? initialFolder;
  final Future<bool> Function({
    required String name,
    String? color,
    String? description,
  }) onSave;

  const CreateOrEditExamFolderDialog({
    super.key,
    this.initialFolder,
    required this.onSave,
  });

  static Future<bool?> show(
    BuildContext context, {
    ExamFolderEntity? initialFolder,
    required Future<bool> Function({
      required String name,
      String? color,
      String? description,
    }) onSave,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => CreateOrEditExamFolderDialog(
        initialFolder: initialFolder,
        onSave: onSave,
      ),
    );
  }

  @override
  State<CreateOrEditExamFolderDialog> createState() =>
      _CreateOrEditExamFolderDialogState();
}

class _CreateOrEditExamFolderDialogState
    extends State<CreateOrEditExamFolderDialog> {
  late final TextEditingController _nameController;
  late String _selectedColor;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialFolder?.name ?? '',
    );
    _selectedColor = widget.initialFolder?.color ?? kExamFolderColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _error = context.l10n.folderNameRequired;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final success = await widget.onSave(
      name: name,
      color: _selectedColor,
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialFolder != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: parseHexColor(_selectedColor).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_outlined,
              color: parseHexColor(_selectedColor),
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              isEditing
                  ? context.l10n.editFolderAction
                  : context.l10n.newFolderAction,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name Field
            Text(
              context.l10n.folderNameLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.l10n.folderNameHint,
                errorText: _error,
                filled: true,
                fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s10,
                ),
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: AppSpacing.s16),

            // Color Selection
            Text(
              context.l10n.folderColorLabel,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kExamFolderColors.map((colorHex) {
                final isSelected = _selectedColor == colorHex;
                final c = parseHexColor(colorHex);
                return InkWell(
                  onTap: () => setState(() => _selectedColor = colorHex),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text(context.l10n.cancel),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: parseHexColor(_selectedColor),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(context.l10n.save),
        ),
      ],
    );
  }
}

class MoveExamFolderDialog extends StatelessWidget {
  final String examTitle;
  final String? currentFolderId;
  final List<ExamFolderEntity> folders;
  final Future<void> Function(String? newFolderId) onSelectFolder;

  const MoveExamFolderDialog({
    super.key,
    required this.examTitle,
    required this.currentFolderId,
    required this.folders,
    required this.onSelectFolder,
  });

  static Future<void> show(
    BuildContext context, {
    required String examTitle,
    required String? currentFolderId,
    required List<ExamFolderEntity> folders,
    required Future<void> Function(String? newFolderId) onSelectFolder,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => MoveExamFolderDialog(
        examTitle: examTitle,
        currentFolderId: currentFolderId,
        folders: folders,
        onSelectFolder: onSelectFolder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      title: Row(
        children: [
          const Icon(
            Icons.drive_file_move_outlined,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              context.l10n.moveExamDialogTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                examTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.s8),

              // Option 1: Uncategorized / Remove from folder
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  ),
                  child: const Icon(
                    Icons.folder_off_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
                title: Text(
                  context.l10n.removeFromFolderOption,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: currentFolderId == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: currentFolderId == null
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: currentFolderId == null
                    ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                    : null,
                onTap: () async {
                  Navigator.of(context).pop();
                  await onSelectFolder(null);
                },
              ),

              // Folders list
              ...folders.map((folder) {
                final isCurrent = currentFolderId == folder.id;
                final fColor = parseHexColor(folder.color);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: fColor.withValues(alpha: 0.15),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: Icon(Icons.folder_rounded, size: 16, color: fColor),
                  ),
                  title: Text(
                    folder.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.w500,
                      color: isCurrent ? fColor : AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    context.l10n.folderExamCount(folder.examCount),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: isCurrent
                      ? Icon(Icons.check, size: 18, color: fColor)
                      : null,
                  onTap: () async {
                    Navigator.of(context).pop();
                    await onSelectFolder(folder.id);
                  },
                );
              }),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
      ],
    );
  }
}
