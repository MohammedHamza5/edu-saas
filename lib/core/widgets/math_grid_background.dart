import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

import 'animated_math_background.dart';

/// خلفية الشبكة الرياضية الأكاديمية (Mathematical Coordinate Grid Canvas)
/// ترسم شبكة إحداثيات هندسية فائقة النعومة مع رموز رياضية خافتة
/// تمنح المنصة طابعاً أكاديمياً عالمياً راقياً لمحاكاة كراسات الهندسة وأنظمة الـ Graphing
class MathGridBackground extends StatelessWidget {
  final Widget child;
  final Color? gridColor;
  final double gridSpacing;
  final double opacity;
  final bool showCartesianAxes;
  final bool showFormulas;
  final bool animated;

  const MathGridBackground({
    super.key,
    required this.child,
    this.gridColor,
    this.gridSpacing = 32.0,
    this.opacity = 0.045,
    this.showCartesianAxes = false,
    this.showFormulas = false,
    this.animated = true,
  });

  @override
  Widget build(BuildContext context) {
    if (animated) {
      return AnimatedMathBackground(
        gridColor: gridColor,
        gridSpacing: gridSpacing,
        opacity: opacity,
        showAxes: showCartesianAxes,
        showFormulas: showFormulas,
        child: child,
      );
    }

    final effectiveColor = gridColor ?? AppColors.primary;

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _MathGridPainter(
                color: effectiveColor,
                spacing: gridSpacing,
                opacity: opacity,
                showAxes: showCartesianAxes,
                showFormulas: showFormulas,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _MathGridPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double opacity;
  final bool showAxes;
  final bool showFormulas;

  _MathGridPainter({
    required this.color,
    required this.spacing,
    required this.opacity,
    required this.showAxes,
    required this.showFormulas,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color.withValues(alpha: opacity * 1.8)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Draw vertical grid lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    // Draw horizontal grid lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw intersection dots for high precision aesthetic
    for (double x = 0; x < size.width; x += spacing * 2) {
      for (double y = 0; y < size.height; y += spacing * 2) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }

    // Optional Cartesian coordinate axes
    if (showAxes) {
      final axesPaint = Paint()
        ..color = color.withValues(alpha: opacity * 2.5)
        ..strokeWidth = 1.25;

      final midX = size.width / 2;
      final midY = size.height / 2;

      // X-Axis
      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), axesPaint);
      // Y-Axis
      canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), axesPaint);
    }

    // Optional faint mathematical formulas
    if (showFormulas && size.width > 300) {
      final textStyle = TextStyle(
        color: color.withValues(alpha: opacity * 1.4),
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontStyle: FontStyle.italic,
        fontFamily: 'serif',
      );

      final formulas = [
        'ax² + bx + c = 0',
        '∑ (x - μ)²',
        'sin²θ + cos²θ = 1',
        'f\'(x) = lim Δy/Δx',
        'Target 800 • SAT Math',
      ];

      for (int i = 0; i < formulas.length; i++) {
        final tp = TextPainter(
          text: TextSpan(text: formulas[i], style: textStyle),
          textDirection: TextDirection.ltr,
        )..layout();

        final dy = 30.0 + (i * 120.0);
        if (dy + tp.height < size.height) {
          final dx = (i % 2 == 0) ? 24.0 : size.width - tp.width - 24.0;
          tp.paint(canvas, Offset(dx, dy));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MathGridPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.opacity != opacity ||
        oldDelegate.showAxes != showAxes ||
        oldDelegate.showFormulas != showFormulas;
  }
}
