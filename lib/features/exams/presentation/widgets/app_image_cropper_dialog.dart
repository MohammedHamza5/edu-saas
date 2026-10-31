import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_logger.dart';
import 'crop_aspect_ratio.dart';
import 'crop_toolbar.dart';
import 'interactive_crop_canvas.dart';

export 'crop_aspect_ratio.dart';

class AppImageCropperDialog extends StatefulWidget {
  final Uint8List imageBytes;

  const AppImageCropperDialog({
    super.key,
    required this.imageBytes,
  });

  static Future<Uint8List?> show(BuildContext context, Uint8List imageBytes) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AppImageCropperDialog(imageBytes: imageBytes),
    );
  }

  @override
  State<AppImageCropperDialog> createState() => _AppImageCropperDialogState();
}

class _AppImageCropperDialogState extends State<AppImageCropperDialog> {
  ui.Image? _decodedImage;
  int _rotationDegrees = 0;
  CropAspectRatio _selectedRatio = CropAspectRatio.free;
  bool _isProcessing = false;

  // Normalized crop rectangle: values in 0.0 .. 1.0 relative to image
  Rect _cropRectNormalized = const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9);

  @override
  void initState() {
    super.initState();
    _loadImage(widget.imageBytes);
  }

  Future<void> _loadImage(Uint8List bytes) async {
    AppLogger.i('CropperDialog', '🔄 [_loadImage] Decoding image from bytes (${bytes.length} bytes)...');
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) {
        AppLogger.s('CropperDialog', '✅ Image decoded successfully: ${img.width}x${img.height}');
        completer.complete(img);
      });
      final img = await completer.future;
      if (mounted) {
        setState(() {
          _decodedImage = img;
          _resetCropToRatio();
        });
      }
    } catch (e, st) {
      AppLogger.e('CropperDialog', '❌ Failed to decode image: $e', error: e, stackTrace: st);
    }
  }

  void _resetCropToRatio() {
    final ratio = _selectedRatio.value;
    if (ratio == null) {
      _cropRectNormalized = const Rect.fromLTWH(0.05, 0.05, 0.9, 0.9);
    } else {
      // Calculate centered box matching ratio
      const defaultW = 0.85;
      final targetH = defaultW / ratio;
      if (targetH <= 0.85) {
        final top = (1.0 - targetH) / 2;
        _cropRectNormalized = Rect.fromLTWH((1.0 - defaultW) / 2, top, defaultW, targetH);
      } else {
        const defaultH = 0.85;
        final targetW = defaultH * ratio;
        final left = (1.0 - targetW) / 2;
        _cropRectNormalized = Rect.fromLTWH(left, (1.0 - defaultH) / 2, targetW, defaultH);
      }
    }
  }

  void _rotateClockwise() {
    setState(() {
      _rotationDegrees = (_rotationDegrees + 90) % 360;
    });
    AppLogger.d('CropperDialog', '🔄 Rotated clockwise to $_rotationDegrees degrees');
  }

  void _onRatioSelected(CropAspectRatio ratio) {
    setState(() {
      _selectedRatio = ratio;
      _resetCropToRatio();
    });
    AppLogger.d('CropperDialog', '📐 Ratio selected: $ratio');
  }

  void _selectAll() {
    setState(() {
      _selectedRatio = CropAspectRatio.free;
      _cropRectNormalized = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
    });
    AppLogger.d('CropperDialog', '🔄 Reset crop rect to full image (100%)');
  }

  Future<void> _applyCropAndReturn() async {
    if (_decodedImage == null || _isProcessing) {
      AppLogger.w('CropperDialog', '⚠️ _applyCropAndReturn called but _decodedImage is null or already processing');
      return;
    }
    setState(() => _isProcessing = true);
    // Allow UI to render the loading spinner before blocking the main thread (Crucial for Web)
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final totalStopwatch = Stopwatch()..start();
    AppLogger.i('CropperDialog', 'PERF_TRACE: ✂️ [_applyCropAndReturn] Applying crop started...');

    try {
      final img = _decodedImage!;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Handle rotated dimensions
      final isRotated90or270 = (_rotationDegrees == 90 || _rotationDegrees == 270);
      final srcW = isRotated90or270 ? img.height.toDouble() : img.width.toDouble();
      final srcH = isRotated90or270 ? img.width.toDouble() : img.height.toDouble();

      // Pixel crop rect
      final cropX = _cropRectNormalized.left * srcW;
      final cropY = _cropRectNormalized.top * srcH;
      final cropW = (_cropRectNormalized.width * srcW).clamp(1.0, srcW);
      final cropH = (_cropRectNormalized.height * srcH).clamp(1.0, srcH);

      // Downscale for Web performance. Large PNG encoding blocks the JS main thread completely.
      const double maxOutputDimension = 800.0;
      double scale = 1.0;
      if (cropW > maxOutputDimension || cropH > maxOutputDimension) {
        scale = cropW > cropH
            ? maxOutputDimension / cropW
            : maxOutputDimension / cropH;
      }

      final outW = (cropW * scale).round();
      final outH = (cropH * scale).round();

      AppLogger.d('CropperDialog', '✂️ Target crop dimensions: $outW x $outH (Scale: $scale)');

      canvas.save();
      // 1. Scale down the entire canvas drawing to match the output size
      canvas.scale(scale);

      // 2. Translate crop to origin
      canvas.translate(-cropX, -cropY);

      if (_rotationDegrees != 0) {
        canvas.translate(srcW / 2, srcH / 2);
        canvas.rotate((_rotationDegrees * math.pi) / 180);
        canvas.translate(-img.width / 2, -img.height / 2);
      }

      canvas.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.high);
      canvas.restore();

      final picture = recorder.endRecording();

      final toImageStopwatch = Stopwatch()..start();
      final croppedUiImage = await picture.toImage(outW, outH);
      toImageStopwatch.stop();

      final toByteDataStopwatch = Stopwatch()..start();
      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      toByteDataStopwatch.stop();

      // Dispose CanvasKit native objects to prevent memory leaks (critical on Web!)
      croppedUiImage.dispose();
      picture.dispose();

      if (!mounted) {
        AppLogger.w('CropperDialog', '⚠️ Widget unmounted before dialog pop');
        return;
      }
      if (byteData != null) {
        // Deep copy the bytes so they don't depend on CanvasKit's WASM memory buffer
        final originalBytes = byteData.buffer.asUint8List();
        final resultBytes = Uint8List.fromList(originalBytes);

        totalStopwatch.stop();
        AppLogger.s('CropperDialog', 'PERF_TRACE: 🎉 Crop success! Output PNG size: ${resultBytes.length} bytes.');
        Navigator.of(context).pop(resultBytes);
      } else {
        AppLogger.w('CropperDialog', '⚠️ byteData was null, falling back to original imageBytes');
        Navigator.of(context).pop(widget.imageBytes);
      }
    } catch (e, st) {
      AppLogger.e('CropperDialog', '❌ Exception during crop: $e', error: e, stackTrace: st);
      if (mounted) Navigator.of(context).pop(widget.imageBytes);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Column(
          children: [
            // ── Dialog Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: AppSpacing.s16,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.crop_rotate_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Text(
                    context.l10n.cropImageDialogTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _isProcessing ? null : () => Navigator.of(context).pop(null),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // ── Interactive Preview & Crop Area ──────────────────────────────
            Expanded(
              child: Container(
                color: const Color(0xFF0F172A), // Dark slate canvas for high focus
                alignment: Alignment.center,
                padding: const EdgeInsets.all(16),
                child: _decodedImage == null
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : InteractiveCropCanvas(
                        decodedImage: _decodedImage!,
                        imageBytes: widget.imageBytes,
                        rotationDegrees: _rotationDegrees,
                        cropRectNormalized: _cropRectNormalized,
                        selectedRatio: _selectedRatio,
                        onCropRectChanged: (newRect) {
                          setState(() => _cropRectNormalized = newRect);
                        },
                      ),
              ),
            ),

            // ── Toolbar: Ratios, Rotate, Cancel, Apply ───────────────────────
            CropToolbar(
              selectedRatio: _selectedRatio,
              onRatioSelected: _onRatioSelected,
              onSelectAll: _selectAll,
              onRotateClockwise: _rotateClockwise,
              onCancel: () => Navigator.of(context).pop(null),
              onApply: _applyCropAndReturn,
              isProcessing: _isProcessing,
            ),
          ],
        ),
      ),
    );
  }
}
