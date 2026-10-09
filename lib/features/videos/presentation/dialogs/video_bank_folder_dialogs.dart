import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/core/widgets/app_text_field.dart';
import 'package:edu_saas/features/videos/domain/entities/video_folder_entity.dart';
import 'package:flutter/material.dart';

import '../utils/folder_color_palette.dart';

class CreateFolderResult {
  final String name;
  final String? color;

  const CreateFolderResult({required this.name, this.color});
}

class CreateFolderDialog extends StatefulWidget {
  const CreateFolderDialog({super.key});

  static Future<CreateFolderResult?> show(BuildContext context) {
    return showDialog<CreateFolderResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const CreateFolderDialog(),
    );
  }

  @override
  State<CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<CreateFolderDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedColorHex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(
        CreateFolderResult(
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
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activeColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            const BoxShadow(
              color: Color(0x80000000),
              blurRadius: 32,
              offset: Offset(0, 16),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: activeColor.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: activeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: activeColor.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.create_new_folder_rounded,
                      color: activeColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.createFolder,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.createFolderSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textMuted,
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: l10n.cancel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),

              // Input Field
              AppTextField(
                controller: _controller,
                labelText: l10n.folderName,
                hintText: l10n.folderNameHint,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                prefixIcon: Icon(
                  Icons.folder_outlined,
                  color: activeColor,
                  size: 20,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: AppSpacing.s16),

              // Color Selection Palette
              Text(
                l10n.selectFolderColor,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildColorDot(
                    color: AppColors.primary,
                    isSelected: _selectedColorHex == null,
                    tooltip: l10n.defaultFolderColor,
                    onTap: () => setState(() => _selectedColorHex = null),
                  ),
                  ...FolderColorPalette.items.map(
                    (item) => _buildColorDot(
                      color: item.color,
                      isSelected: _selectedColorHex == item.hex,
                      tooltip: _getColorName(context, item.nameKey),
                      onTap: () => setState(() => _selectedColorHex = item.hex),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: l10n.cancel,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: AppButton(
                      text: l10n.save,
                      icon: Icons.check_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: _submit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorDot({
    required Color color,
    required bool isSelected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? const Center(
                  child: Icon(Icons.check, size: 16, color: Colors.white),
                )
              : null,
        ),
      ),
    );
  }
}

class ChangeFolderColorDialog extends StatefulWidget {
  final VideoFolderEntity folder;

  const ChangeFolderColorDialog({super.key, required this.folder});

  static Future<String?> show(
    BuildContext context, {
    required VideoFolderEntity folder,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ChangeFolderColorDialog(folder: folder),
    );
  }

  @override
  State<ChangeFolderColorDialog> createState() =>
      _ChangeFolderColorDialogState();
}

class _ChangeFolderColorDialogState extends State<ChangeFolderColorDialog> {
  late String? _selectedHex;

  @override
  void initState() {
    super.initState();
    _selectedHex = widget.folder.color;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeColor = FolderColorPalette.getFolderColor(_selectedHex);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activeColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            const BoxShadow(
              color: Color(0x80000000),
              blurRadius: 32,
              offset: Offset(0, 16),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: activeColor.withValues(alpha: 0.15),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: activeColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    Icons.palette_rounded,
                    color: activeColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.s14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.changeFolderColor,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),

            // Live preview tile
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: activeColor.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.folder_rounded, color: activeColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.folder.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Subtitle
            Text(
              l10n.changeFolderColorSubtitle,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Color Palette Wrap
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildChoiceDot(
                  color: AppColors.primary,
                  isSelected: _selectedHex == null || _selectedHex!.isEmpty,
                  tooltip: l10n.defaultFolderColor,
                  onTap: () => setState(() => _selectedHex = ''),
                ),
                ...FolderColorPalette.items.map(
                  (item) => _buildChoiceDot(
                    color: item.color,
                    isSelected: _selectedHex == item.hex,
                    tooltip: _getColorName(context, item.nameKey),
                    onTap: () => setState(() => _selectedHex = item.hex),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            // Actions
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: l10n.cancel,
                    variant: AppButtonVariant.outlined,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: AppButton(
                    text: l10n.save,
                    icon: Icons.check_rounded,
                    variant: AppButtonVariant.primary,
                    onPressed: () =>
                        Navigator.of(context).pop(_selectedHex ?? ''),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceDot({
    required Color color,
    required bool isSelected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.white : Colors.transparent,
              width: 2.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.6),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: isSelected
              ? const Center(
                  child: Icon(Icons.check, size: 18, color: Colors.white),
                )
              : null,
        ),
      ),
    );
  }
}

String _getColorName(BuildContext context, String key) {
  final l10n = context.l10n;
  switch (key) {
    case 'colorIndigo':
      return l10n.folderColorIndigo;
    case 'colorCyan':
      return l10n.folderColorCyan;
    case 'colorEmerald':
      return l10n.folderColorEmerald;
    case 'colorAmber':
      return l10n.folderColorAmber;
    case 'colorRuby':
      return l10n.folderColorRuby;
    case 'colorViolet':
      return l10n.folderColorViolet;
    case 'colorRose':
      return l10n.folderColorRose;
    case 'colorSlate':
      return l10n.folderColorSlate;
    default:
      return key;
  }
}

class RenameFolderDialog extends StatefulWidget {
  final String currentName;

  const RenameFolderDialog({super.key, required this.currentName});

  static Future<String?> show(
    BuildContext context, {
    required String currentName,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
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

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderDark, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 32,
              offset: Offset(0, 16),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Color(0x1A6366F1),
              blurRadius: 24,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0x336366F1), Color(0x1438BDF8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.drive_file_rename_outline_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.renameFolder,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.renameFolderSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textMuted,
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: l10n.cancel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),

              // Input Field
              AppTextField(
                controller: _controller,
                labelText: l10n.folderName,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                prefixIcon: const Icon(
                  Icons.drive_file_rename_outline_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l10n.fieldRequired : null,
              ),
              const SizedBox(height: AppSpacing.s24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: l10n.cancel,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: AppButton(
                      text: l10n.save,
                      icon: Icons.check_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: _submit,
                    ),
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
      barrierDismissible: true,
      builder: (ctx) => MoveVideoDialog(
        allFolders: allFolders,
        currentFolderId: currentFolderId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderDark, width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 32,
              offset: Offset(0, 16),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Color(0x1A38BDF8),
              blurRadius: 24,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x3338BDF8), Color(0x146366F1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.drive_file_move_rounded,
                    color: AppColors.primaryLight,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.s14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.selectTargetFolder,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.moveVideo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textMuted,
                  splashRadius: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: l10n.cancel,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s20),

            // Scrollable Folders List
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 6,
                    ),
                    children: [
                      // Option 1: Root / All Videos
                      _buildFolderTile(
                        context: context,
                        icon: Icons.video_library_rounded,
                        iconColor: AppColors.primaryLight,
                        title: l10n.moveToRoot,
                        subtitle: l10n.rootFolderTitle,
                        isSelected: currentFolderId == null,
                        onTap: () => Navigator.of(context).pop('__ROOT__'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Divider(color: AppColors.border, height: 1),
                      ),
                      // Other Folders
                      ...allFolders.map(
                        (f) => _buildFolderTile(
                          context: context,
                          icon: Icons.folder_rounded,
                          iconColor: f.id == currentFolderId
                              ? AppColors.primary
                              : const Color(0xFFFBBF24),
                          title: f.name,
                          subtitle: l10n.nVideos(f.videoCount),
                          isSelected: f.id == currentFolderId,
                          onTap: () => Navigator.of(context).pop(f.id),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s20),

            // Cancel Button
            AppButton(
              text: l10n.cancel,
              variant: AppButtonVariant.outlined,
              isFullWidth: true,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: AppColors.surfaceVariant.withValues(alpha: 0.8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
