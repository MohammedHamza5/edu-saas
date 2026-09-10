import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../config/tenant_registry.dart';
import '../theme/tenant_theme_cubit.dart';

/// The platform's Venn Diagram logo mark.
///
/// Two overlapping circles representing the intersection of knowledge,
/// with an academic signature symbol (e.g. ∑, ∫, Δ) in the intersection area.
/// Automatically adapts to the active teacher / tenant's visual branding.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showName;
  final String? platformName;
  final Color? nameColor;
  final Color? primaryColor;
  final Color? secondaryColor;
  final String? symbol;

  const AppLogo({
    super.key,
    this.size = 64,
    this.showName = false,
    this.platformName,
    this.nameColor,
    this.primaryColor,
    this.secondaryColor,
    this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Resolve tenant branding if available
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();

    final effectivePrimary = primaryColor ?? colorScheme.primary;
    final effectiveSecondary = secondaryColor ?? branding.primaryLight;
    final effectiveSymbol = symbol ?? branding.signatureSymbol;
    final effectiveName = platformName ?? branding.brandName;
    final effectiveNameColor = nameColor ?? effectivePrimary;

    if (!showName) {
      return SizedBox(
        width: size,
        height: size * 0.65, // aspect ratio of the venn diagram
        child: CustomPaint(
          painter: _VennPainter(
            primary: effectivePrimary,
            secondary: effectiveSecondary,
            symbol: effectiveSymbol,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size * 0.65,
          child: CustomPaint(
            painter: _VennPainter(
              primary: effectivePrimary,
              secondary: effectiveSecondary,
              symbol: effectiveSymbol,
            ),
          ),
        ),
        SizedBox(height: size * 0.14),
        Text(
          effectiveName,
          style: TextStyle(
            color: effectiveNameColor,
            fontSize: size * 0.28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

/// CustomPainter that draws the Venn Diagram mark.
///
/// Layout (normalized to a 100×65 canvas):
///   Left circle  center: (33, 32.5) radius 28  — Deep Indigo stroke
///   Right circle center: (67, 32.5) radius 28  — Royal Blue stroke
///   Intersection lens filled with indigo→blue gradient
///   Σ character drawn in the center of the lens
class _VennPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final String symbol;

  const _VennPainter({
    required this.primary,
    required this.secondary,
    required this.symbol,
  });

  static const double _strokeWidth = 2.4;

  @override
  void paint(Canvas canvas, Size size) {
    // --- Coordinate system (normalized units → pixels) ---
    final scaleX = size.width / 100.0;
    final scaleY = size.height / 65.0;
    final scale = math.min(scaleX, scaleY);

    // Center the drawing
    final dx = (size.width - 100 * scale) / 2;
    final dy = (size.height - 65 * scale) / 2;
    canvas.translate(dx, dy);
    canvas.scale(scale);

    const Offset leftCenter = Offset(33, 32.5);
    const Offset rightCenter = Offset(67, 32.5);
    const double r = 28.0;

    // --- 1. Clip to left circle and fill gradient in lens region ---
    _drawLensFill(canvas, leftCenter, rightCenter, r);

    // --- 2. Left circle stroke (Teacher Primary) ---
    final leftPaint = Paint()
      ..color = primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..isAntiAlias = true;
    canvas.drawCircle(leftCenter, r, leftPaint);

    // --- 3. Right circle stroke (Teacher Secondary) ---
    final rightPaint = Paint()
      ..color = secondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..isAntiAlias = true;
    canvas.drawCircle(rightCenter, r, rightPaint);

    // --- 4. Symbol in intersection ---
    _drawSymbol(canvas, const Offset(50, 32.5), r * 0.55);
  }

  void _drawLensFill(
      Canvas canvas, Offset left, Offset right, double r) {
    final d = (right - left).distance;
    final halfAngle = math.acos(d / (2 * r));

    final path = Path();
    final leftToRight = math.atan2(
        right.dy - left.dy, right.dx - left.dx);

    path.moveTo(
      left.dx + r * math.cos(leftToRight - halfAngle),
      left.dy + r * math.sin(leftToRight - halfAngle),
    );

    path.arcToPoint(
      Offset(
        left.dx + r * math.cos(leftToRight + halfAngle),
        left.dy + r * math.sin(leftToRight + halfAngle),
      ),
      radius: Radius.circular(r),
      clockwise: true,
    );

    path.arcToPoint(
      Offset(
        left.dx + r * math.cos(leftToRight - halfAngle),
        left.dy + r * math.sin(leftToRight - halfAngle),
      ),
      radius: Radius.circular(r),
      clockwise: false,
    );

    path.close();

    final lensCenter = Offset((left.dx + right.dx) / 2, (left.dy + right.dy) / 2);
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          primary.withValues(alpha: 0.28),
          secondary.withValues(alpha: 0.22),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromCenter(
        center: lensCenter,
        width: r * 0.9,
        height: r * 1.6,
      ))
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = primary.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..isAntiAlias = true;
    canvas.drawPath(path, borderPaint);
  }

  void _drawSymbol(Canvas canvas, Offset center, double fontSize) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(
          color: primary.withValues(alpha: 0.85),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _VennPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary ||
      oldDelegate.symbol != symbol;
}
