import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Paints a subtle academic graph-paper grid + scattered math watermarks.
/// Used as the background for Splash, Login, and Onboarding screens.
///
/// Usage:
/// ```dart
/// Stack(children: [
///   const MathBackground(),
///   // your content
/// ])
/// ```
class MathBackground extends StatelessWidget {
  const MathBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(
        painter: _MathBackgroundPainter(),
      ),
    );
  }
}

class _MathBackgroundPainter extends CustomPainter {
  static const List<_Symbol> _symbols = [
    _Symbol('∑', 0.12, 0.08, 64),
    _Symbol('π', 0.78, 0.06, 56),
    _Symbol('f(x)', 0.88, 0.55, 38),
    _Symbol('∫', 0.05, 0.60, 70),
    _Symbol('√', 0.82, 0.82, 52),
    _Symbol('∞', 0.20, 0.88, 44),
    _Symbol('Δ', 0.55, 0.92, 40),
    _Symbol('θ', 0.40, 0.10, 36),
    _Symbol('∂', 0.68, 0.30, 42),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawSymbols(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.45)
      ..strokeWidth = 0.6
      ..isAntiAlias = false;

    const step = 28.0; // grid cell size in px

    // Vertical lines
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Horizontal lines
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawSymbols(Canvas canvas, Size size) {
    for (final sym in _symbols) {
      final tp = TextPainter(
        text: TextSpan(
          text: sym.text,
          style: TextStyle(
            color: AppColors.textMuted.withValues(alpha: 0.055),
            fontSize: sym.fontSize,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(
          size.width * sym.xFraction - tp.width / 2,
          size.height * sym.yFraction - tp.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MathBackgroundPainter oldDelegate) => false;
}

class _Symbol {
  final String text;
  final double xFraction; // 0..1 relative to canvas width
  final double yFraction; // 0..1 relative to canvas height
  final double fontSize;

  const _Symbol(this.text, this.xFraction, this.yFraction, this.fontSize);
}
