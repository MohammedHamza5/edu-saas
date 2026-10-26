import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_colors.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/features/videos/domain/entities/video_folder_entity.dart';
import 'package:flutter/material.dart';

import '../utils/folder_color_palette.dart';

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
