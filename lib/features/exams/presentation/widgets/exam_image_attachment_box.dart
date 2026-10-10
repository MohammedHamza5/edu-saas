import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_logger.dart';
import '../../data/services/exam_image_upload_service.dart';
import 'app_image_cropper_dialog.dart';

class ExamImageAttachmentBox extends StatefulWidget {
  final String? initialImageUrl;
  final Map<String, dynamic>? initialImageMeta;
  final ValueChanged<({String? imageUrl, Map<String, dynamic>? imageMeta})>
  onChanged;

  const ExamImageAttachmentBox({
    super.key,
    this.initialImageUrl,
    this.initialImageMeta,
    required this.onChanged,
  });

  @override
  State<ExamImageAttachmentBox> createState() => _ExamImageAttachmentBoxState();
}

class _ExamImageAttachmentBoxState extends State<ExamImageAttachmentBox> {
  final _uploadService = ExamImageUploadService();

  String? _imageUrl;
  late Map<String, dynamic> _imageMeta;
  bool _isUploading = false;


  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
    _imageMeta = Map<String, dynamic>.from(
      widget.initialImageMeta ??
          {'alignment': 'center', 'width_percent': 50, 'enable_zoom': true},
    );
  }

  void _notifyChange() {
    widget.onChanged((
      imageUrl: _imageUrl,
      imageMeta: _imageUrl == null ? null : _imageMeta,
    ));
  }

  Future<void> _processRawBytes(Uint8List rawBytes, String filename) async {
    AppLogger.i(
      'ExamImageBox',
      '📷 [_processRawBytes] Received raw bytes: ${rawBytes.length} bytes for file: $filename',
    );

    // 1. Open in-app cropper dialog
    AppLogger.d('ExamImageBox', '🖼️ Opening AppImageCropperDialog...');
    final croppedBytes = await AppImageCropperDialog.show(context, rawBytes);

    if (croppedBytes == null) {
      AppLogger.w(
        'ExamImageBox',
        '⚠️ AppImageCropperDialog was cancelled or returned null',
      );
      return;
    }
    if (!mounted) {
      AppLogger.w('ExamImageBox', '⚠️ Widget not mounted after cropper dialog');
      return;
    }

    AppLogger.s(
      'ExamImageBox',
      '✂️ Cropper returned ${croppedBytes.length} bytes. Setting _isUploading = true',
    );

    setState(() => _isUploading = true);

    // Yield to the event loop so Flutter can render the _isUploading UI (loading indicator)
    // before the heavy Supabase upload logic blocks the thread.
    await Future<void>.delayed(const Duration(milliseconds: 150));

    try {
      final uploadStopwatch = Stopwatch()..start();
      AppLogger.i(
        'ExamImageBox',
        'PERF_TRACE: ☁️ Calling _uploadService.uploadExamImage started...',
      );
      // Deep-copy bytes so release web builds pass a real Uint8List to Supabase
      // (CanvasKit / FilePicker views can fail JS interop as upload payloads).
      final uploadBytes = Uint8List.fromList(croppedBytes);
      final uploadedUrl = await _uploadService.uploadExamImage(
        bytes: uploadBytes,
        fileName: filename,
        mimeType: 'image/png',
      );
      uploadStopwatch.stop();

      AppLogger.s(
        'ExamImageBox',
        'PERF_TRACE: 🎉 Image uploaded successfully! URL: $uploadedUrl. Took ${uploadStopwatch.elapsedMilliseconds}ms',
      );
      if (mounted) {
        setState(() {
          _imageUrl = uploadedUrl;
          _isUploading = false;

        });
        _notifyChange();
      }
    } catch (e, st) {
      AppLogger.e(
        'ExamImageBox',
        '❌ Error uploading image: $e',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.imageUploadFailed(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _pickFile() async {
    AppLogger.i(
      'ExamImageBox',
      '📂 [_pickFile] Triggered. Opening FilePicker...',
    );
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result == null) {
        AppLogger.w(
          'ExamImageBox',
          '📂 FilePicker returned null (user canceled)',
        );
        return;
      }

      if (result.files.isEmpty) {
        AppLogger.w('ExamImageBox', '📂 FilePicker returned empty files list');
        return;
      }

      final file = result.files.first;
      AppLogger.d(
        'ExamImageBox',
        '📂 Selected file: ${file.name}, size: ${file.size} bytes',
      );
      final bytes = file.bytes;
      if (bytes != null) {
        AppLogger.d(
          'ExamImageBox',
          '📂 File bytes loaded into memory (${bytes.length} bytes). Processing...',
        );
        await _processRawBytes(bytes, file.name);
      } else {
        AppLogger.e(
          'ExamImageBox',
          '❌ File bytes is null! FilePicker did not load bytes for ${file.name}',
        );
      }
    } catch (e, st) {
      AppLogger.e(
        'ExamImageBox',
        '❌ FilePicker exception: $e',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _handlePaste() async {
    // In web/desktop, try reading clipboard image
    // If not supported natively by platform clipboard, show guidance tooltip
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.pasteScreenshotTip),
        duration: const Duration(seconds: 3),
      ),
    );
    await _pickFile();
  }

  void _removeImage() {
    setState(() {
      _imageUrl = null;

    });
    _notifyChange();
  }

  void _setAlignment(String alignment) {
    setState(() {
      _imageMeta['alignment'] = alignment;
    });
    _notifyChange();
  }

  void _setWidthPercent(int percent) {
    setState(() {
      _imageMeta['width_percent'] = percent;
    });
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    if (_isUploading) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            const SizedBox(height: AppSpacing.s12),
            Text(
              context.l10n.uploadingImageToCloud,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_imageUrl != null) {
      final alignment = _imageMeta['alignment'] as String? ?? 'center';
      final widthPercent = (_imageMeta['width_percent'] as num?)?.toInt() ?? 75;

      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(AppSpacing.s12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Preview container with chosen width & alignment
            LayoutBuilder(
              builder: (ctx, constraints) {
                final displayW = constraints.maxWidth * (widthPercent / 100);
                Alignment align = Alignment.center;
                if (alignment == 'right') align = Alignment.centerRight;
                if (alignment == 'left') align = Alignment.centerLeft;

                return Align(
                  alignment: align,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      width: displayW,
                      child: CachedNetworkImage(
                        imageUrl: _imageUrl!,
                        memCacheWidth: 600,
                        memCacheHeight: 600,
                        maxWidthDiskCache: 800,
                        fit: BoxFit.contain,
                        placeholder: (ctx, _) => Container(
                          height: 140,
                          color: AppColors.surfaceVariant,
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (ctx, _, __) => Container(
                          height: 100,
                          color: AppColors.error.withValues(alpha: 0.1),
                          child: Center(
                            child: Text(
                              context.l10n.failedToLoadImage,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s8),

            // Controls Bar: Alignment + Width Selector + Delete
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        context.l10n.imageAlignmentLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      _buildAlignButton(
                        'right',
                        Icons.format_align_right_rounded,
                        alignment,
                      ),
                      _buildAlignButton(
                        'center',
                        Icons.format_align_center_rounded,
                        alignment,
                      ),
                      _buildAlignButton(
                        'left',
                        Icons.format_align_left_rounded,
                        alignment,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.l10n.imageWidthLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      _buildWidthChip(30, '30%', widthPercent),
                      _buildWidthChip(50, '50%', widthPercent),
                      _buildWidthChip(75, '75%', widthPercent),
                      _buildWidthChip(100, '100%', widthPercent),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  tooltip: context.l10n.removeImageAction,
                  onPressed: _removeImage,
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Empty Attachment Box (Drop Zone / Paste Box)
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 480;
        return InkWell(
          onTap: _pickFile,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
                width: 1.2,
              ),
            ),
            child: isCompact
                ? _buildCompactLayout(context)
                : _buildFullLayout(context),
          ),
        );
      },
    );
  }

  Widget _buildCompactLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_photo_alternate_outlined,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.attachImageOrScreenshotTitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.attachImageOrScreenshotSubtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file_rounded, size: 16),
              label: Text(context.l10n.browseAction),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFullLayout(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.add_photo_alternate_outlined,
            color: AppColors.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.attachImageOrScreenshotTitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                context.l10n.attachImageOrScreenshotSubtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _handlePaste,
          icon: const Icon(Icons.content_paste_rounded, size: 16),
          label: const Text('Ctrl+V'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.upload_file_rounded, size: 16),
          label: Text(context.l10n.browseAction),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Widget _buildAlignButton(
    String alignKey,
    IconData icon,
    String currentAlign,
  ) {
    final isSelected = alignKey == currentAlign;
    return InkWell(
      onTap: () => _setAlignment(alignKey),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildWidthChip(int percent, String label, int currentPercent) {
    final isSelected = percent == currentPercent;
    return InkWell(
      onTap: () => _setWidthPercent(percent),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
