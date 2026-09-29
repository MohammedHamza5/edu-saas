import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

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
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (img) => completer.complete(img));
    final img = await completer.future;
    if (mounted) {
      setState(() {
        _decodedImage = img;
        _resetCropToRatio();
      });
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
  }

  void _onRatioSelected(CropAspectRatio ratio) {
    setState(() {
      _selectedRatio = ratio;
      _resetCropToRatio();
    });
  }

  Future<void> _applyCropAndReturn() async {
    if (_decodedImage == null || _isProcessing) return;
    setState(() => _isProcessing = true);

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

      canvas.save();
      // Translate to center for rotation
      canvas.translate(-cropX, -cropY);

      if (_rotationDegrees != 0) {
        canvas.translate(srcW / 2, srcH / 2);
        canvas.rotate((_rotationDegrees * math.pi) / 180);
        canvas.translate(-img.width / 2, -img.height / 2);
      }

      canvas.drawImage(img, Offset.zero, Paint()..filterQuality = FilterQuality.high);
      canvas.restore();

      final picture = recorder.endRecording();
      final croppedUiImage = await picture.toImage(cropW.round(), cropH.round());
      final byteData = await croppedUiImage.toByteData(format: ui.ImageByteFormat.png);

      if (!mounted) return;
      if (byteData != null) {
        Navigator.of(context).pop(byteData.buffer.asUint8List());
      } else {
        Navigator.of(context).pop(widget.imageBytes);
      }
    } catch (_) {
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
                  // Aspect Ratios and Rotate Buttons
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
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _rotateClockwise,
                        icon: const Icon(Icons.rotate_right_rounded, size: 18),
                        label: Text(context.l10n.rotate90Action),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

  Widget _buildCropCanvas(BoxConstraints constraints) {
    final img = _decodedImage!;
    final isRotated = (_rotationDegrees == 90 || _rotationDegrees == 270);
    final w = isRotated ? img.height.toDouble() : img.width.toDouble();
    final h = isRotated ? img.width.toDouble() : img.height.toDouble();

    // Fit image inside container preserving aspect ratio
    final scale = math.min(constraints.maxWidth / w, constraints.maxHeight / h);
    final displayedW = w * scale;
    final displayedH = h * scale;

    return Center(
      child: SizedBox(
        width: displayedW,
        height: displayedH,
        child: Stack(
          children: [
            // The Image with rotation
            Positioned.fill(
              child: Transform.rotate(
                angle: (_rotationDegrees * math.pi) / 180,
                child: RawImage(
                  image: img,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Shading overlay outside crop rect
            Positioned.fill(
              child: CustomPaint(
                painter: _CropOverlayPainter(
                  cropRect: Rect.fromLTWH(
                    _cropRectNormalized.left * displayedW,
                    _cropRectNormalized.top * displayedH,
                    _cropRectNormalized.width * displayedW,
                    _cropRectNormalized.height * displayedH,
                  ),
                ),
              ),
            ),

            // Draggable Crop Box
            Positioned(
              left: _cropRectNormalized.left * displayedW,
              top: _cropRectNormalized.top * displayedH,
              width: _cropRectNormalized.width * displayedW,
              height: _cropRectNormalized.height * displayedH,
              child: GestureDetector(
                onPanUpdate: (details) {
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
                },
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
                  child: Stack(
                    children: [
                      // Grid lines inside crop
                      CustomPaint(
                        size: Size.infinite,
                        painter: _RuleOfThirdsPainter(),
                      ),
                      // Corner handles
                      Align(
                        alignment: Alignment.topLeft,
                        child: _buildHandle(),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: _buildHandle(),
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: _buildHandle(),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: _buildHandle(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
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
