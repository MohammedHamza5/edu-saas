import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'crop_aspect_ratio.dart';

class InteractiveCropCanvas extends StatelessWidget {
  static const double _minNormalizedSize = 0.04;

  final ui.Image decodedImage;
  final Uint8List imageBytes;
  final int rotationDegrees;
  final Rect cropRectNormalized;
  final CropAspectRatio selectedRatio;
  final ValueChanged<Rect> onCropRectChanged;

  const InteractiveCropCanvas({
    super.key,
    required this.decodedImage,
    required this.imageBytes,
    required this.rotationDegrees,
    required this.cropRectNormalized,
    required this.selectedRatio,
    required this.onCropRectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isRotated = (rotationDegrees == 90 || rotationDegrees == 270);
        final w = isRotated
            ? decodedImage.height.toDouble()
            : decodedImage.width.toDouble();
        final h = isRotated
            ? decodedImage.width.toDouble()
            : decodedImage.height.toDouble();

        final scale = math.min(
          constraints.maxWidth / w,
          constraints.maxHeight / h,
        );
        final displayedW = w * scale;
        final displayedH = h * scale;

        final boxL = cropRectNormalized.left * displayedW;
        final boxT = cropRectNormalized.top * displayedH;
        final boxW = cropRectNormalized.width * displayedW;
        final boxH = cropRectNormalized.height * displayedH;

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
                    quarterTurns: rotationDegrees ~/ 90,
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),

                // Shading overlay outside crop rect
                Positioned.fill(
                  child: CustomPaint(
                    painter: CropOverlayPainter(
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
                            onPanUpdate: (d) =>
                                _onPanMove(d, displayedW, displayedH),
                            child: Container(
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                size: Size.infinite,
                                painter: RuleOfThirdsPainter(),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Edge Resizers (available in free ratio)
                      if (selectedRatio.value == null) ...[
                        Positioned(
                          top: -6,
                          left: 14,
                          right: 14,
                          height: 14,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeUpDown,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (d) =>
                                  _onResizeTop(d, displayedW, displayedH),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -6,
                          left: 14,
                          right: 14,
                          height: 14,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeUpDown,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (d) =>
                                  _onResizeBottom(d, displayedW, displayedH),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -6,
                          top: 14,
                          bottom: 14,
                          width: 14,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (d) =>
                                  _onResizeLeft(d, displayedW, displayedH),
                            ),
                          ),
                        ),
                        Positioned(
                          right: -6,
                          top: 14,
                          bottom: 14,
                          width: 14,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeLeftRight,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanUpdate: (d) =>
                                  _onResizeRight(d, displayedW, displayedH),
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
      },
    );
  }

  void _onPanMove(
    DragUpdateDetails details,
    double displayedW,
    double displayedH,
  ) {
    final dxNorm = details.delta.dx / displayedW;
    final dyNorm = details.delta.dy / displayedH;
    final newLeft = (cropRectNormalized.left + dxNorm)
        .clamp(0.0, 1.0 - cropRectNormalized.width);
    final newTop = (cropRectNormalized.top + dyNorm)
        .clamp(0.0, 1.0 - cropRectNormalized.height);

    onCropRectChanged(
      Rect.fromLTWH(
        newLeft,
        newTop,
        cropRectNormalized.width,
        cropRectNormalized.height,
      ),
    );
  }

  void _onResizeTopLeft(
    DragUpdateDetails details,
    double displayedW,
    double displayedH,
  ) {
    final dxNorm = details.delta.dx / displayedW;
    final dyNorm = details.delta.dy / displayedH;

    final currentRight = cropRectNormalized.right;
    final currentBottom = cropRectNormalized.bottom;

    double newLeft = (cropRectNormalized.left + dxNorm).clamp(
      0.0,
      currentRight - _minNormalizedSize,
    );
    double newTop = (cropRectNormalized.top + dyNorm).clamp(
      0.0,
      currentBottom - _minNormalizedSize,
    );

    final ratio = selectedRatio.value;
    if (ratio != null) {
      final targetW = (currentBottom - newTop) * ratio;
      newLeft = (currentRight - targetW).clamp(
        0.0,
        currentRight - _minNormalizedSize,
      );
    }

    onCropRectChanged(Rect.fromLTRB(newLeft, newTop, currentRight, currentBottom));
  }

  void _onResizeTopRight(
    DragUpdateDetails details,
    double displayedW,
    double displayedH,
  ) {
    final dxNorm = details.delta.dx / displayedW;
    final dyNorm = details.delta.dy / displayedH;

    final currentLeft = cropRectNormalized.left;
    final currentBottom = cropRectNormalized.bottom;

    double newRight = (cropRectNormalized.right + dxNorm).clamp(
      currentLeft + _minNormalizedSize,
      1.0,
    );
    double newTop = (cropRectNormalized.top + dyNorm).clamp(
      0.0,
      currentBottom - _minNormalizedSize,
    );

    final ratio = selectedRatio.value;
    if (ratio != null) {
      final targetW = (currentBottom - newTop) * ratio;
      newRight = (currentLeft + targetW).clamp(
        currentLeft + _minNormalizedSize,
        1.0,
      );
    }

    onCropRectChanged(Rect.fromLTRB(currentLeft, newTop, newRight, currentBottom));
  }

  void _onResizeBottomLeft(
    DragUpdateDetails details,
    double displayedW,
    double displayedH,
  ) {
    final dxNorm = details.delta.dx / displayedW;
    final dyNorm = details.delta.dy / displayedH;

    final currentRight = cropRectNormalized.right;
    final currentTop = cropRectNormalized.top;

    double newLeft = (cropRectNormalized.left + dxNorm).clamp(
      0.0,
      currentRight - _minNormalizedSize,
    );
    double newBottom = (cropRectNormalized.bottom + dyNorm).clamp(
      currentTop + _minNormalizedSize,
      1.0,
    );

    final ratio = selectedRatio.value;
    if (ratio != null) {
      final targetW = (newBottom - currentTop) * ratio;
      newLeft = (currentRight - targetW).clamp(
        0.0,
        currentRight - _minNormalizedSize,
      );
    }

    onCropRectChanged(Rect.fromLTRB(newLeft, currentTop, currentRight, newBottom));
  }

  void _onResizeBottomRight(
    DragUpdateDetails details,
    double displayedW,
    double displayedH,
  ) {
    final dxNorm = details.delta.dx / displayedW;
    final dyNorm = details.delta.dy / displayedH;

    final currentLeft = cropRectNormalized.left;
    final currentTop = cropRectNormalized.top;

    double newRight = (cropRectNormalized.right + dxNorm).clamp(
      currentLeft + _minNormalizedSize,
      1.0,
    );
    double newBottom = (cropRectNormalized.bottom + dyNorm).clamp(
      currentTop + _minNormalizedSize,
      1.0,
    );

    final ratio = selectedRatio.value;
    if (ratio != null) {
      final targetW = (newBottom - currentTop) * ratio;
      newRight = (currentLeft + targetW).clamp(
        currentLeft + _minNormalizedSize,
        1.0,
      );
    }

    onCropRectChanged(Rect.fromLTRB(currentLeft, currentTop, newRight, newBottom));
  }

  void _onResizeTop(
    DragUpdateDetails details,
    double displayedW,
    double displayedH,
  ) {
    if (selectedRatio.value != null) return;
    final dyNorm = details.delta.dy / displayedH;
    final currentBottom = cropRectNormalized.bottom;
    final newTop = (cropRectNormalized.top + dyNorm).clamp(
      0.0,
      currentBottom - _minNormalizedSize,
    );
    onCropRectChanged(
      Rect.fromLTRB(
        cropRectNormalized.left,
        newTop,
        cropRectNormalized.right,
        currentBottom,
      ),
    );
  }

  void _onResizeBottom(
    DragUpdateDetails details,
    double displayedW,
    double displayedH,
  ) {
    if (selectedRatio.value != null) return;
    final dyNorm = details.delta.dy / displayedH;
    final currentTop = cropRectNormalized.top;
    final newBottom = (cropRectNormalized.bottom + dyNorm).clamp(
      currentTop + _minNormalizedSize,
      1.0,
    );
    onCropRectChanged(
      Rect.fromLTRB(
        cropRectNormalized.left,
        currentTop,
        cropRectNormalized.right,
        newBottom,
      ),
    );
  }

  void _onResizeLeft(
    DragUpdateDetails details,
    double displayedW,
    double displayedH,
  ) {
    if (selectedRatio.value != null) return;
    final dxNorm = details.delta.dx / displayedW;
    final currentRight = cropRectNormalized.right;
    final newLeft = (cropRectNormalized.left + dxNorm).clamp(
      0.0,
      currentRight - _minNormalizedSize,
    );
    onCropRectChanged(
      Rect.fromLTRB(
        newLeft,
        cropRectNormalized.top,
        currentRight,
        cropRectNormalized.bottom,
      ),
    );
  }

  void _onResizeRight(
    DragUpdateDetails details,
    double displayedW,
    double displayedH,
  ) {
    if (selectedRatio.value != null) return;
    final dxNorm = details.delta.dx / displayedW;
    final currentLeft = cropRectNormalized.left;
    final newRight = (cropRectNormalized.right + dxNorm).clamp(
      currentLeft + _minNormalizedSize,
      1.0,
    );
    onCropRectChanged(
      Rect.fromLTRB(
        currentLeft,
        cropRectNormalized.top,
        newRight,
        cropRectNormalized.bottom,
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
          color: Colors.transparent,
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
