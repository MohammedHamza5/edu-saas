import 'package:flutter/material.dart';
import 'package:edu_saas/features/exams/domain/entities/scratchpad_entity.dart';

/// Highly optimized CustomPainter for rendering scratchpad strokes and math grid.
class ScratchpadPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final DrawingStroke? currentStroke;
  final bool isGridBackground;
  final Color gridColor;

  const ScratchpadPainter({
    required this.strokes,
    this.currentStroke,
    this.isGridBackground = false,
    this.gridColor = const Color(0x1F94A3B8),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isGridBackground) {
      _drawMathGrid(canvas, size);
    }

    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawMathGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawStroke(Canvas canvas, DrawingStroke stroke) {
    if (stroke.points.isEmpty) return;

    if (stroke.tool == DrawingTool.eraser) {
      // In overlay mode, eraser paints with transparent blend mode
      final eraserPaint = Paint()
        ..blendMode = BlendMode.clear
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke;

      _paintPath(canvas, stroke.points, eraserPaint);
      return;
    }

    final isHighlighter = stroke.tool == DrawingTool.highlighter;
    final strokePaint = Paint()
      ..color = stroke.color.withValues(alpha: isHighlighter ? 0.38 : stroke.opacity)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke;

    _paintPath(canvas, stroke.points, strokePaint);
  }

  void _paintPath(Canvas canvas, List<DrawingPoint> points, Paint paint) {
    if (points.length == 1) {
      canvas.drawCircle(points.first.offset, paint.strokeWidth / 2, paint);
      return;
    }

    final path = Path();
    path.moveTo(points.first.offset.dx, points.first.offset.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].offset.dx, points[i].offset.dy);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ScratchpadPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.isGridBackground != isGridBackground;
  }
}
