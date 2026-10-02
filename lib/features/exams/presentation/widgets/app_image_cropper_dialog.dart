import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_logger.dart';

enum CropAspectRatio {
  free,
  ratio16x9,
  ratio4x3,
  ratio1x1;

  double? get value {
    switch (this) {
      case CropAspectRatio.free:
        return null;
      case CropAspectRatio.ratio16x9:
        return 16 / 9;
      case CropAspectRatio.ratio4x3:
        return 4 / 3;
      case CropAspectRatio.ratio1x1:
        return 1.0;
    }
  }

  String label(BuildContext context) {
    switch (this) {
      case CropAspectRatio.free:
        return context.l10n.cropRatioFree;
      case CropAspectRatio.ratio16x9:
        return '16:9';
      case CropAspectRatio.ratio4x3:
        return '4:3';
      case CropAspectRatio.ratio1x1:
        return '1:1';
    }
  }
}

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

    AppLogger.i('CropperDialog', '✂️ [_applyCropAndReturn] Applying crop...');

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
      AppLogger.d('CropperDialog', 'PERF_TRACE: ⏳ picture.toImage ($outW x $outH) started...');
      final croppedUiImage = await picture.toImage(outW, outH);
      toImageStopwatch.stop();
      AppLogger.d('CropperDialog', 'PERF_TRACE: ✅ picture.toImage took ${toImageStopwatch.elapsedMilliseconds}ms');
      
      final toByteDataStopwatch = Stopwatch()..start();
      AppLogger.d('CropperDialog', 'PERF_TRACE: ⏳ Converting croppedUiImage to PNG ByteData started (this blocks JS!)...');
      // This step blocks the UI thread on Web. Downscaling above minimizes the freeze time.
      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);
      toByteDataStopwatch.stop();
      AppLogger.d('CropperDialog', 'PERF_TRACE: ✅ toByteData(png) took ${toByteDataStopwatch.elapsedMilliseconds}ms');

      // Dispose CanvasKit native objects to prevent memory leaks (critical on Web!)
      croppedUiImage.dispose();
      picture.dispose();

      if (!mounted) {
        AppLogger.w('CropperDialog', '⚠️ Widget unmounted before dialog pop');
        return;
      }
      if (byteData != null) {
        // Deep copy the bytes so they don't depend on CanvasKit's WASM memory buffer, 
        // which can be garbage collected and cause TypeErrors in async HTTP requests.
        final originalBytes = byteData.buffer.asUint8List();
        final resultBytes = Uint8List.fromList(originalBytes);
        
        totalStopwatch.stop();
        AppLogger.s('CropperDialog', 'PERF_TRACE: 🎉 Crop success! Output PNG size: ${resultBytes.length} bytes. Total _applyCropAndReturn took ${totalStopwatch.elapsedMilliseconds}ms');
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
                    : LayoutBuilder(
                        builder: (ctx, constraints) {
                          return _buildCropCanvas(constraints);
                        },
                      ),
              ),
            ),

            // ── Toolbar: Ratios, Rotate, Cancel, Apply ───────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                children: [
                  // Aspect Ratios, Rotate, and Select All Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ...CropAspectRatio.values.map((ratio) {
                        final isSelected = _selectedRatio == ratio;
                        return ChoiceChip(
                          label: Text(ratio.label(context)),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (_) => _onRatioSelected(ratio),
                        );
                      }),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        onPressed: _selectAll,
                        icon: const Icon(Icons.select_all_rounded, size: 18),
                        label: Text(context.l10n.resetCropAction),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      OutlinedButton.icon(
                        onPressed: _rotateClockwise,
                        icon: const Icon(Icons.rotate_right_rounded, size: 18),
                        label: Text(context.l10n.rotate90Action),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // Actions: Cancel / Confirm
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isProcessing ? null : () => Navigator.of(context).pop(null),
                        child: Text(context.l10n.cancel),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _applyCropAndReturn,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded, size: 18),
                        label: Text(context.l10n.applyCropAction),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.s20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _minNormalizedSize = 0.04;

  void _selectAll() {
    setState(() {
      _selectedRatio = CropAspectRatio.free;
      _cropRectNormalized = const Rect.fromLTWH(0.0, 0.0, 1.0, 1.0);
    });
    AppLogger.d('CropperDialog', '🔄 Reset crop rect to full image (100%)');
  }

  void _onPanMove(DragUpdateDetails details, double displayedW, double displayedH) {
    setState(() {
      final dxNorm = details.delta.dx / displayedW;
      final dyNorm = details.delta.dy / displayedH;
      final newLeft = (_cropRectNormalized.left + dxNorm)
          .clamp(0.0, 1.0 - _cropRectNormalized.width);
      final newTop = (_cropRectNormalized.top + dyNorm)
          .clamp(0.0, 1.0 - _cropRectNormalized.height);

      _cropRectNormalized = Rect.fromLTWH(
        newLeft,
        newTop,
        _cropRectNormalized.width,
        _cropRectNormalized.height,
      );
    });
  }

  void _onResizeTopLeft(DragUpdateDetails details, double displayedW, double displayedH) {
    setState(() {
      final dxNorm = details.delta.dx / displayedW;
      final dyNorm = details.delta.dy / displayedH;

      final currentRight = _cropRectNormalized.right;
      final currentBottom = _cropRectNormalized.bottom;

      double newLeft = (_cropRectNormalized.left + dxNorm).clamp(0.0, currentRight - _minNormalizedSize);
      double newTop = (_cropRectNormalized.top + dyNorm).clamp(0.0, currentBottom - _minNormalizedSize);

      final ratio = _selectedRatio.value;
      if (ratio != null) {
        final targetW = (currentBottom - newTop) * ratio;
        newLeft = (currentRight - targetW).clamp(0.0, currentRight - _minNormalizedSize);
      }

      _cropRectNormalized = Rect.fromLTRB(newLeft, newTop, currentRight, currentBottom);
    });
  }

  void _onResizeTopRight(DragUpdateDetails details, double displayedW, double displayedH) {
    setState(() {
      final dxNorm = details.delta.dx / displayedW;
      final dyNorm = details.delta.dy / displayedH;

      final currentLeft = _cropRectNormalized.left;
      final currentBottom = _cropRectNormalized.bottom;

      double newRight = (_cropRectNormalized.right + dxNorm).clamp(currentLeft + _minNormalizedSize, 1.0);
      double newTop = (_cropRectNormalized.top + dyNorm).clamp(0.0, currentBottom - _minNormalizedSize);

      final ratio = _selectedRatio.value;
      if (ratio != null) {
        final targetW = (currentBottom - newTop) * ratio;
        newRight = (currentLeft + targetW).clamp(currentLeft + _minNormalizedSize, 1.0);
      }

      _cropRectNormalized = Rect.fromLTRB(currentLeft, newTop, newRight, currentBottom);
    });
  }

  void _onResizeBottomLeft(DragUpdateDetails details, double displayedW, double displayedH) {
    setState(() {
      final dxNorm = details.delta.dx / displayedW;
      final dyNorm = details.delta.dy / displayedH;

      final currentRight = _cropRectNormalized.right;
      final currentTop = _cropRectNormalized.top;

      double newLeft = (_cropRectNormalized.left + dxNorm).clamp(0.0, currentRight - _minNormalizedSize);
      double newBottom = (_cropRectNormalized.bottom + dyNorm).clamp(currentTop + _minNormalizedSize, 1.0);

      final ratio = _selectedRatio.value;
      if (ratio != null) {
        final targetW = (newBottom - currentTop) * ratio;
        newLeft = (currentRight - targetW).clamp(0.0, currentRight - _minNormalizedSize);
      }

      _cropRectNormalized = Rect.fromLTRB(newLeft, currentTop, currentRight, newBottom);
    });
  }

  void _onResizeBottomRight(DragUpdateDetails details, double displayedW, double displayedH) {
    setState(() {
      final dxNorm = details.delta.dx / displayedW;
      final dyNorm = details.delta.dy / displayedH;

      final currentLeft = _cropRectNormalized.left;
      final currentTop = _cropRectNormalized.top;

      double newRight = (_cropRectNormalized.right + dxNorm).clamp(currentLeft + _minNormalizedSize, 1.0);
      double newBottom = (_cropRectNormalized.bottom + dyNorm).clamp(currentTop + _minNormalizedSize, 1.0);

      final ratio = _selectedRatio.value;
      if (ratio != null) {
        final targetW = (newBottom - currentTop) * ratio;
        newRight = (currentLeft + targetW).clamp(currentLeft + _minNormalizedSize, 1.0);
      }

      _cropRectNormalized = Rect.fromLTRB(currentLeft, currentTop, newRight, newBottom);
    });
  }

  void _onResizeTop(DragUpdateDetails details, double displayedW, double displayedH) {
    if (_selectedRatio.value != null) return;
    setState(() {
      final dyNorm = details.delta.dy / displayedH;
      final currentBottom = _cropRectNormalized.bottom;
      final newTop = (_cropRectNormalized.top + dyNorm).clamp(0.0, currentBottom - _minNormalizedSize);
      _cropRectNormalized = Rect.fromLTRB(_cropRectNormalized.left, newTop, _cropRectNormalized.right, currentBottom);
    });
  }

  void _onResizeBottom(DragUpdateDetails details, double displayedW, double displayedH) {
    if (_selectedRatio.value != null) return;
    setState(() {
      final dyNorm = details.delta.dy / displayedH;
      final currentTop = _cropRectNormalized.top;
      final newBottom = (_cropRectNormalized.bottom + dyNorm).clamp(currentTop + _minNormalizedSize, 1.0);
      _cropRectNormalized = Rect.fromLTRB(_cropRectNormalized.left, currentTop, _cropRectNormalized.right, newBottom);
    });
  }

  void _onResizeLeft(DragUpdateDetails details, double displayedW, double displayedH) {
    if (_selectedRatio.value != null) return;
    setState(() {
      final dxNorm = details.delta.dx / displayedW;
      final currentRight = _cropRectNormalized.right;
      final newLeft = (_cropRectNormalized.left + dxNorm).clamp(0.0, currentRight - _minNormalizedSize);
      _cropRectNormalized = Rect.fromLTRB(newLeft, _cropRectNormalized.top, currentRight, _cropRectNormalized.bottom);
    });
  }

  void _onResizeRight(DragUpdateDetails details, double displayedW, double displayedH) {
    if (_selectedRatio.value != null) return;
    setState(() {
      final dxNorm = details.delta.dx / displayedW;
      final currentLeft = _cropRectNormalized.left;
      final newRight = (_cropRectNormalized.right + dxNorm).clamp(currentLeft + _minNormalizedSize, 1.0);
      _cropRectNormalized = Rect.fromLTRB(currentLeft, _cropRectNormalized.top, newRight, _cropRectNormalized.bottom);
    });
  }

  Widget _buildCropCanvas(BoxConstraints constraints) {
    final img = _decodedImage!;
    final isRotated = (_rotationDegrees == 90 || _rotationDegrees == 270);
    final w = isRotated ? img.height.toDouble() : img.width.toDouble();
    final h = isRotated ? img.width.toDouble() : img.height.toDouble();

    final scale = math.min(constraints.maxWidth / w, constraints.maxHeight / h);
    final displayedW = w * scale;
    final displayedH = h * scale;

    final boxL = _cropRectNormalized.left * displayedW;
    final boxT = _cropRectNormalized.top * displayedH;
    final boxW = _cropRectNormalized.width * displayedW;
    final boxH = _cropRectNormalized.height * displayedH;

    return Center(
      child: SizedBox(
        width: displayedW,
        height: displayedH,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // The Image with rotation
            Positioned.fill(
              child: RotatedBox(
                quarterTurns: _rotationDegrees ~/ 90,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),

            // Shading overlay outside crop rect
            Positioned.fill(
              child: CustomPaint(
                painter: _CropOverlayPainter(
                  cropRect: Rect.fromLTWH(boxL, boxT, boxW, boxH),
                ),
              ),
            ),

            // Fully interactive Crop Box
            Positioned(
              left: boxL,
              top: boxT,
              width: boxW,
              height: boxH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Center drag body (translates the crop box)
                  Positioned.fill(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.move,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (d) => _onPanMove(d, displayedW, displayedH),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _RuleOfThirdsPainter(),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Edge Resizers (available in free ratio)
                  if (_selectedRatio.value == null) ...[
                    // Top Edge
                    Positioned(
                      top: -6,
                      left: 14,
                      right: 14,
                      height: 14,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (d) => _onResizeTop(d, displayedW, displayedH),
                        ),
                      ),
                    ),
                    // Bottom Edge
                    Positioned(
                      bottom: -6,
                      left: 14,
                      right: 14,
                      height: 14,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeUpDown,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (d) => _onResizeBottom(d, displayedW, displayedH),
                        ),
                      ),
                    ),
                    // Left Edge
                    Positioned(
                      left: -6,
                      top: 14,
                      bottom: 14,
                      width: 14,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (d) => _onResizeLeft(d, displayedW, displayedH),
                        ),
                      ),
                    ),
                    // Right Edge
                    Positioned(
                      right: -6,
                      top: 14,
                      bottom: 14,
                      width: 14,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (d) => _onResizeRight(d, displayedW, displayedH),
                        ),
                      ),
                    ),
                  ],

                  // 4 Corner Handles with precise grab areas
                  Positioned(
                    top: -14,
                    left: -14,
                    child: _buildInteractiveHandle(
                      SystemMouseCursors.resizeUpLeftDownRight,
                      (d) => _onResizeTopLeft(d, displayedW, displayedH),
                    ),
                  ),
                  Positioned(
                    top: -14,
                    right: -14,
                    child: _buildInteractiveHandle(
                      SystemMouseCursors.resizeUpRightDownLeft,
                      (d) => _onResizeTopRight(d, displayedW, displayedH),
                    ),
                  ),
                  Positioned(
                    bottom: -14,
                    left: -14,
                    child: _buildInteractiveHandle(
                      SystemMouseCursors.resizeUpRightDownLeft,
                      (d) => _onResizeBottomLeft(d, displayedW, displayedH),
                    ),
                  ),
                  Positioned(
                    bottom: -14,
                    right: -14,
                    child: _buildInteractiveHandle(
                      SystemMouseCursors.resizeUpLeftDownRight,
                      (d) => _onResizeBottomRight(d, displayedW, displayedH),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveHandle(
    MouseCursor cursor,
    GestureDragUpdateCallback onPanUpdate,
  ) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: onPanUpdate,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          color: Colors.transparent, // Ensure hit test works over transparent padding
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  _CropOverlayPainter({required this.cropRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final path = Path()
      ..addRect(fullRect)
      ..addRect(cropRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CropOverlayPainter old) => old.cropRect != cropRect;
}

class _RuleOfThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    final oneThirdW = size.width / 3;
    final twoThirdW = size.width * 2 / 3;
    final oneThirdH = size.height / 3;
    final twoThirdH = size.height * 2 / 3;

    canvas.drawLine(Offset(oneThirdW, 0), Offset(oneThirdW, size.height), paint);
    canvas.drawLine(Offset(twoThirdW, 0), Offset(twoThirdW, size.height), paint);
    canvas.drawLine(Offset(0, oneThirdH), Offset(size.width, oneThirdH), paint);
    canvas.drawLine(Offset(0, twoThirdH), Offset(size.width, twoThirdH), paint);
  }

  @override
  bool shouldRepaint(_RuleOfThirdsPainter old) => false;
}

