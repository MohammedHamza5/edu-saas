import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/folder_color_palette.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/material_folder_entity.dart';

/// Modal dialog allowing a teacher to move a material between folders.
class MoveMaterialDialog extends StatefulWidget {
  final String? currentFolderId;
  final List<MaterialFolderEntity> folders;

  const MoveMaterialDialog({
    super.key,
    this.currentFolderId,
    required this.folders,
  });

  /// Displays the move material dialog and returns the target folderId (or empty string for root).
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
