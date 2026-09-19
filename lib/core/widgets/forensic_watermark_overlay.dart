import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../network/supabase_service.dart';

/// Intelligent Academic Forensic Watermark Overlay
///
/// Provides a dual-layer defense against screen capture and unauthorized distribution:
/// 1. Dynamic Floating Badge: A drifting, high-contrast identification pill that
///    smoothly animates across a 9-point grid every 9 seconds, frustrating crop attempts.
/// 2. Micro Repeating Tiled Stamp: A faint diagonal lattice carrying the student's unique
///    identifier and contact details across the entire frame.
///
/// Completely non-intrusive to UX: wrapped in [IgnorePointer] so all player controls,
/// taps, scrubber gestures, and keyboard shortcuts remain 100% functional.
class ForensicWatermarkOverlay extends StatefulWidget {
  final Widget child;
  final String? studentName;
  final String? studentPhone;
  final String? studentId;
  final bool enabled;

  const ForensicWatermarkOverlay({
    super.key,
    required this.child,
    this.studentName,
    this.studentPhone,
    this.studentId,
    this.enabled = true,
  });

  @override
  State<ForensicWatermarkOverlay> createState() => _ForensicWatermarkOverlayState();
}

class _ForensicWatermarkOverlayState extends State<ForensicWatermarkOverlay> {
  Timer? _driftTimer;
  final Random _random = Random();

  static const List<Alignment> _gridPositions = [
    Alignment(-0.75, -0.75),
    Alignment(0.0, -0.65),
    Alignment(0.75, -0.75),
    Alignment(-0.70, 0.0),
    Alignment(0.0, 0.05),
    Alignment(0.70, 0.0),
    Alignment(-0.75, 0.70),
    Alignment(0.0, 0.60),
    Alignment(0.75, 0.70),
  ];

  Alignment _currentAlignment = const Alignment(0.0, 0.0);
  int _currentIndex = 4;

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      _startDrifting();
    }
  }

  void _startDrifting() {
    _driftTimer = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!mounted) return;
      int nextIndex = _random.nextInt(_gridPositions.length);
      if (nextIndex == _currentIndex) {
        nextIndex = (nextIndex + 1) % _gridPositions.length;
      }
      setState(() {
        _currentIndex = nextIndex;
        _currentAlignment = _gridPositions[_currentIndex];
      });
    });
  }

  @override
  void didUpdateWidget(ForensicWatermarkOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _driftTimer ??= Timer.periodic(const Duration(seconds: 9), (_) {
          if (!mounted) return;
          int nextIndex = _random.nextInt(_gridPositions.length);
          if (nextIndex == _currentIndex) {
            nextIndex = (nextIndex + 1) % _gridPositions.length;
          }
          setState(() {
            _currentIndex = nextIndex;
            _currentAlignment = _gridPositions[_currentIndex];
          });
        });
      } else {
        _driftTimer?.cancel();
        _driftTimer = null;
      }
    }
  }

  @override
  void dispose() {
    _driftTimer?.cancel();
    super.dispose();
  }

  String _resolveDisplayText() {
    final user = SupabaseService.currentUser;
    final metadata = user?.userMetadata;

    final name = widget.studentName ??
        (metadata?['full_name'] as String?) ??
        user?.email?.split('@').first ??
        '';

    final phone = widget.studentPhone ??
        (metadata?['phone'] as String?) ??
        user?.phone ??
        '';

    final id = widget.studentId ?? user?.id.substring(0, 8) ?? '';

    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (phone.isNotEmpty) parts.add(phone);
    if (id.isNotEmpty) parts.add('ID: $id');

    return parts.isEmpty ? 'EduSaaS Protected' : parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final watermarkText = _resolveDisplayText();

    return Stack(
      fit: StackFit.passthrough,
      children: [
        widget.child,

        // ── 1. Layer B: Micro Repeating Tiled Lattice ──
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: CustomPaint(
              painter: _RepeatingWatermarkPainter(
                text: watermarkText,
              ),
            ),
          ),
        ),

        // ── 2. Layer A: Dynamic Drifting Forensic Badge ──
        Positioned.fill(
          child: IgnorePointer(
            ignoring: true,
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeInOutCubic,
              alignment: _currentAlignment,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(60),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 11,
                      color: Colors.white.withAlpha(210),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        watermarkText,
                        style: TextStyle(
                          color: Colors.white.withAlpha(210),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                          shadows: const [
                            Shadow(
                              blurRadius: 2,
                              color: Colors.black,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tiled diagonal faint pattern across the entire viewport
class _RepeatingWatermarkPainter extends CustomPainter {
  final String text;

  _RepeatingWatermarkPainter({required this.text});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final textStyle = TextStyle(
      color: Colors.white.withAlpha(16), // ~6% opacity, ultra subtle
      fontSize: 11,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
    );

    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    final double stepX = max(textWidth + 80, 200.0);
    final double stepY = max(textHeight + 60, 100.0);

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    for (double y = -size.height * 0.2; y < size.height * 1.5; y += stepY) {
      for (double x = -size.width * 0.2; x < size.width * 1.5; x += stepX) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(-22 * pi / 180);
        textPainter.paint(canvas, Offset.zero);
        canvas.restore();
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _RepeatingWatermarkPainter oldDelegate) {
    return oldDelegate.text != text;
  }
}
