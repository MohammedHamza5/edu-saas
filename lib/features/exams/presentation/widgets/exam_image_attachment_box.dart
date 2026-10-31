import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_logger.dart';
import 'app_image_cropper_dialog.dart';
import 'exam_image_attachment_controls_bar.dart';
import 'exam_image_attachment_empty_zone.dart';
import 'exam_image_attachment_preview.dart';

/// Question image attachment box supporting instant local preview, cropping, cloud upload, and alignment/width metadata.
class ExamImageAttachmentBox extends StatefulWidget {
  final String? initialImageUrl;
  final Uint8List? initialLocalBytes;
  final Map<String, dynamic>? initialImageMeta;
  final bool? isUploading;
  final String? uploadError;
  final VoidCallback? onRetryUpload;
  final void Function(Uint8List bytes, String filename)? onBytesSelected;
  final ValueChanged<
      ({
        String? imageUrl,
        Map<String, dynamic>? imageMeta,
        Uint8List? localBytes
      })> onChanged;

  const ExamImageAttachmentBox({
    super.key,
    this.initialImageUrl,
    this.initialLocalBytes,
    this.initialImageMeta,
    this.isUploading,
    this.uploadError,
    this.onRetryUpload,
    this.onBytesSelected,
    required this.onChanged,
  });

  @override
  State<ExamImageAttachmentBox> createState() =>
      _ExamImageAttachmentBoxState();
}

class _ExamImageAttachmentBoxState extends State<ExamImageAttachmentBox> {
  String? _imageUrl;
  Uint8List? _localBytes;
  late Map<String, dynamic> _imageMeta;
  bool _internalIsUploading = false;
  String? _internalError;

  bool get _effectiveIsUploading => widget.isUploading ?? _internalIsUploading;
  String? get _effectiveError => widget.uploadError ?? _internalError;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.initialImageUrl;
    _localBytes = widget.initialLocalBytes;
    _imageMeta = Map<String, dynamic>.from(
      widget.initialImageMeta ??
          {'alignment': 'center', 'width_percent': 75, 'enable_zoom': true},
    );
  }

  @override
  void didUpdateWidget(covariant ExamImageAttachmentBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialImageUrl != oldWidget.initialImageUrl) {
      _imageUrl = widget.initialImageUrl;
    }
    if (widget.initialLocalBytes != oldWidget.initialLocalBytes) {
      _localBytes = widget.initialLocalBytes;
    }
    if (widget.initialImageMeta != oldWidget.initialImageMeta &&
        widget.initialImageMeta != null) {
      _imageMeta = Map<String, dynamic>.from(widget.initialImageMeta!);
    }
  }

  void _notifyChange() {
    widget.onChanged((
      imageUrl: _imageUrl,
      imageMeta: (_imageUrl == null && _localBytes == null) ? null : _imageMeta,
      localBytes: _localBytes,
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
      '✂️ Cropper returned ${croppedBytes.length} bytes. Displaying preview instantly!',
    );

    final safeBytes = Uint8List.fromList(croppedBytes);

    setState(() {
      _localBytes = safeBytes;
      _imageUrl = null;
      _internalError = null;
    });
    _notifyChange();

    // If parent manages background upload (CreateExamPage)
    if (widget.onBytesSelected != null) {
      widget.onBytesSelected!(safeBytes, filename);
      return;
    }

    // Standalone fallback:
    setState(() => _internalIsUploading = true);
    try {
      final uploadBytes = Uint8List.fromList(safeBytes);
      final uploadedUrl =
          await InjectionContainer.examsRepository.uploadExamImage(
        bytes: uploadBytes,
        fileName: filename,
        mimeType: 'image/png',
      );
      if (mounted) {
        setState(() {
          _imageUrl = uploadedUrl;
          _internalIsUploading = false;
        });
        _notifyChange();
      } else {
        _imageUrl = uploadedUrl;
        _internalIsUploading = false;
        _notifyChange();
      }
    } catch (e, st) {
      AppLogger.e('ExamImageBox', '❌ Error uploading image: $e',
          error: e, stackTrace: st);
      if (mounted) {
        setState(() {
          _internalIsUploading = false;
          _internalError = e.toString();
        });
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
      _localBytes = null;
      _internalError = null;
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
    final hasImage =
        _localBytes != null || (_imageUrl != null && _imageUrl!.isNotEmpty);

    if (hasImage) {
      final alignment = _imageMeta['alignment'] as String? ?? 'center';
      final widthPercent =
          (_imageMeta['width_percent'] as num?)?.toInt() ?? 75;

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
            ExamImageAttachmentPreview(
              localBytes: _localBytes,
              imageUrl: _imageUrl,
              alignment: alignment,
              widthPercent: widthPercent,
            ),
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s8),

            // Controls Bar: Status Badges + Alignment + Width Selector + Delete
            ExamImageAttachmentControlsBar(
              isUploading: _effectiveIsUploading,
              imageUrl: _imageUrl,
              uploadError: _effectiveError,
              onRetryUpload: widget.onRetryUpload,
              alignment: alignment,
              widthPercent: widthPercent,
              onAlignmentChanged: _setAlignment,
              onWidthPercentChanged: _setWidthPercent,
              onRemoveImage: _removeImage,
            ),
          ],
        ),
      );
    }

    // Empty Attachment Box (Drop Zone / Paste Box)
    return ExamImageAttachmentEmptyZone(
      onPickFile: _pickFile,
      onHandlePaste: _handlePaste,
    );
  }
}
