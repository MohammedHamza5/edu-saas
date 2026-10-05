import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/video_folder_entity.dart';

class CreateFolderDialog extends StatefulWidget {
  const CreateFolderDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => const CreateFolderDialog(),
    );
  }

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.create_new_folder_outlined,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Text(l10n.createFolder),
        ],
      ),
      content: Form(
        key: _formKey,
        child: AppTextField(
          controller: _controller,
          label: l10n.folderName,
          hintText: l10n.folderNameHint,
          autofocus: true,
          validator: (v) =>
              v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        AppButton(
          text: l10n.save,
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
        ),
      ],
    );
  }
}

class RenameFolderDialog extends StatefulWidget {
  final String currentName;

  const RenameFolderDialog({super.key, required this.currentName});

  static Future<String?> show(BuildContext context, {required String currentName}) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => RenameFolderDialog(currentName: currentName),
    );
  }

  @override
  State<RenameFolderDialog> createState() => _RenameFolderDialogState();
}

class _RenameFolderDialogState extends State<RenameFolderDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      title: Text(l10n.renameFolder),
      content: Form(
        key: _formKey,
        child: AppTextField(
          controller: _controller,
          label: l10n.folderName,
          autofocus: true,
          validator: (v) =>
              v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        AppButton(
          text: l10n.save,
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
        ),
      ],
    );
  }
}

class MoveVideoDialog extends StatelessWidget {
  final List<VideoFolderEntity> allFolders;
  final String? currentFolderId;

  const MoveVideoDialog({
    super.key,
    required this.allFolders,
    this.currentFolderId,
  });

  static Future<String?> show(
    BuildContext context, {
    required List<VideoFolderEntity> allFolders,
    String? currentFolderId,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (ctx) => MoveVideoDialog(
        allFolders: allFolders,
        currentFolderId: currentFolderId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      title: Row(
        children: [
          const Icon(Icons.drive_file_move_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.s10),
          Text(l10n.selectTargetFolder),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 350,
        child: ListView(
          children: [
            // Option 1: Root / All Videos
            ListTile(
              leading: const Icon(Icons.home_outlined, color: AppColors.primary),
              title: Text(
                l10n.moveToRoot,
                style: TextStyle(
                  fontWeight: currentFolderId == null
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              selected: currentFolderId == null,
              onTap: () => Navigator.of(context).pop('__ROOT__'),
            ),
            const Divider(),
            ...allFolders.map(
              (f) => ListTile(
                leading: Icon(
                  Icons.folder_rounded,
                  color: f.id == currentFolderId
                      ? AppColors.primary
                      : Colors.amber.shade700,
                ),
                title: Text(f.name),
                subtitle: Text(
                  l10n.nVideos(f.videoCount),
                  style: const TextStyle(fontSize: 11),
                ),
                selected: f.id == currentFolderId,
                onTap: () => Navigator.of(context).pop(f.id),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
      ],
    );
  }
}
