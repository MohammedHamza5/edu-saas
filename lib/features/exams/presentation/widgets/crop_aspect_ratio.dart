import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';

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

class CropOverlayPainter extends CustomPainter {
  final Rect cropRect;

  CropOverlayPainter({required this.cropRect});

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
  bool shouldRepaint(CropOverlayPainter old) => old.cropRect != cropRect;
}

class RuleOfThirdsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    final oneThirdW = size.width / 3;
    final twoThirdW = size.width * 2 / 3;
    final oneThirdH = size.height / 3;
    final twoThirdH = size.height * 2 / 3;

    canvas.drawLine(
      Offset(oneThirdW, 0),
      Offset(oneThirdW, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(twoThirdW, 0),
      Offset(twoThirdW, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, oneThirdH),
      Offset(size.width, oneThirdH),
      paint,
    );
    canvas.drawLine(
      Offset(0, twoThirdH),
      Offset(size.width, twoThirdH),
      paint,
    );
  }

  @override
  bool shouldRepaint(RuleOfThirdsPainter old) => false;
}
