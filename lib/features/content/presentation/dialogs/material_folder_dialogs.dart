import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/theme/folder_color_palette.dart';
import '../../domain/entities/material_folder_entity.dart';

class MaterialFolderResult {
  final String name;
  final String? color;

  const MaterialFolderResult({required this.name, this.color});
}

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
                        color: activeColor.withValues(alpha: 0.15),
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
                            ? l10n.editFolderName
                            : l10n.createNewFolderAction,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),

                AppTextField(
                  controller: _controller,
                  labelText: l10n.folderNameLabel,
                  hintText: l10n.folderNameLabel,
                  prefixIcon: const Icon(Icons.folder_outlined, size: 20),
                  autofocus: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.requiredField;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

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
                        _selectedColorHex?.toUpperCase() == item.hex.toUpperCase();
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
                            color: isSelected ? Colors.white : Colors.transparent,
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

class RenameMaterialDialog extends StatefulWidget {
  final String currentTitle;

  const RenameMaterialDialog({super.key, required this.currentTitle});

  static Future<String?> show(
    BuildContext context, {
    required String currentTitle,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RenameMaterialDialog(currentTitle: currentTitle),
    );
  }

  @override
  State<RenameMaterialDialog> createState() => _RenameMaterialDialogState();
}

class _RenameMaterialDialogState extends State<RenameMaterialDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMedium),
                      ),
                      child: const Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        l10n.editMaterialAction,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),
                AppTextField(
                  controller: _controller,
                  labelText: l10n.editMaterialAction,
                  hintText: l10n.materialsSearchHint,
                  autofocus: true,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.requiredField;
                    }
                    return null;
                  },
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
                      text: l10n.saveChangesAction,
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

class MoveMaterialDialog extends StatefulWidget {
  final String? currentFolderId;
  final List<MaterialFolderEntity> folders;

  const MoveMaterialDialog({
    super.key,
    this.currentFolderId,
    required this.folders,
  });

  static Future<String?> show(
    BuildContext context, {
    String? currentFolderId,
    required List<MaterialFolderEntity> folders,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => MoveMaterialDialog(
        currentFolderId: currentFolderId,
        folders: folders,
      ),
    );
  }

  @override
  State<MoveMaterialDialog> createState() => _MoveMaterialDialogState();
}

class _MoveMaterialDialogState extends State<MoveMaterialDialog> {
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = widget.currentFolderId;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: const Icon(
                      Icons.drive_file_move_rounded,
                      color: Color(0xFFEA580C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Text(
                      l10n.moveMaterialAction,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
              Expanded(
                child: ListView(
                  children: [
                    // Root
                    ListTile(
                      leading: const Icon(
                        Icons.home_outlined,
                        color: Color(0xFFEA580C),
                      ),
                      title: Text(l10n.rootMaterialsTitle),
                      trailing: _selectedFolderId == null
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFFEA580C),
                            )
                          : null,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      selected: _selectedFolderId == null,
                      onTap: () {
                        setState(() {
                          _selectedFolderId = null;
                        });
                      },
                    ),
                    const Divider(),
                    ...widget.folders.map((f) {
                      final isSelected = _selectedFolderId == f.id;
                      final fColor =
                          FolderColorPalette.getFolderColor(f.color);
                      return ListTile(
                        leading: Icon(
                          Icons.folder_rounded,
                          color: fColor,
                        ),
                        title: Text(f.name),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: fColor)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSmall),
                        ),
                        selected: isSelected,
                        onTap: () {
                          setState(() {
                            _selectedFolderId = f.id;
                          });
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancelAction),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  AppButton(
                    text: l10n.moveMaterialAction,
                    onPressed: () {
                      Navigator.of(context).pop(_selectedFolderId ?? '');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
