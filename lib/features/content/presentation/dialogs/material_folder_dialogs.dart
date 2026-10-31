import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/folder_color_palette.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

export 'move_material_dialog.dart';
export 'rename_material_dialog.dart';

class MaterialFolderResult {
  final String name;
  final String? color;

  const MaterialFolderResult({required this.name, this.color});
}

/// Modal dialog for creating or editing an academic material folder.
class CreateMaterialFolderDialog extends StatefulWidget {
  final String? initialName;
  final String? initialColor;
  final bool isEditing;

  const CreateMaterialFolderDialog({
    super.key,
    this.initialName,
    this.initialColor,
    this.isEditing = false,
  });

  /// Displays the create/edit folder dialog and returns the user's input.
  static Future<MaterialFolderResult?> show(
    BuildContext context, {
    String? initialName,
    String? initialColor,
    bool isEditing = false,
  }) {
    return showDialog<MaterialFolderResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CreateMaterialFolderDialog(
        initialName: initialName,
        initialColor: initialColor,
        isEditing: isEditing,
      ),
    );
  }

  @override
  State<CreateMaterialFolderDialog> createState() =>
      _CreateMaterialFolderDialogState();
}

class _CreateMaterialFolderDialogState
    extends State<CreateMaterialFolderDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();
  late String? _selectedColorHex;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
    _selectedColorHex = widget.initialColor ?? '#EA580C';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(
        MaterialFolderResult(
          name: _controller.text.trim(),
          color: _selectedColorHex,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeColor = FolderColorPalette.getFolderColor(_selectedColorHex);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMedium),
                      ),
                      child: Icon(
                        widget.isEditing
                            ? Icons.edit_rounded
                            : Icons.create_new_folder_rounded,
                        color: activeColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        widget.isEditing
                            ? l10n.editFolderAction
                            : l10n.createNewFolderAction,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),

                // Folder Name input
                AppTextField(
                  controller: _controller,
                  labelText: l10n.folderNameLabel,
                  hintText: l10n.materialsSearchHint,
                  autofocus: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.requiredField;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                // Color Picker section
                Text(
                  l10n.folderColorLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.s8),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: FolderColorPalette.items.map((item) {
                    final isSelected =
                        _selectedColorHex?.toUpperCase() ==
                        item.hex.toUpperCase();
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedColorHex = item.hex;
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color:
                                isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: item.color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 18,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.s24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.cancelAction),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    AppButton(
                      text: widget.isEditing
                          ? l10n.saveChangesAction
                          : l10n.createNewFolderAction,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
