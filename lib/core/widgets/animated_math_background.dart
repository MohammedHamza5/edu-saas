import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../theme/math_tokens.dart';

/// خلفية الشبكة الرياضية التفاعلية والمتحركة (Harmonic Mathematical Canvas)
/// ترسم شبكة إحداثيات ديكارتية انسيابية مع موجات جيب توافقية (Harmonic Sine Waves)
/// ونقاط تقاطع نابضة ورموز رياضية خافتة بكفاءة 60fps فائقة الخفة وبدون أي حمل على المعالج.
class AnimatedMathBackground extends StatefulWidget {
  final Widget? child;
  final Color? gridColor;
  final Color? waveColor;
  final double gridSpacing;
  final double opacity;
  final bool showWave;
  final bool showAxes;
  final bool showFormulas;
  final bool showNodes;
  final Duration cycleDuration;

  const AnimatedMathBackground({
    super.key,
    this.child,
    this.gridColor,
    this.waveColor,
    this.gridSpacing = 36.0,
    this.opacity = 0.045,
    this.showWave = true,
    this.showAxes = true,
    this.showFormulas = true,
    this.showNodes = true,
    this.cycleDuration = const Duration(seconds: 28),
  });

  @override
  State<AnimatedMathBackground> createState() => _AnimatedMathBackgroundState();
}

class _AnimatedMathBackgroundState extends State<AnimatedMathBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;

  static bool get _isInTest {
    final bindingName = WidgetsBinding.instance.runtimeType.toString();
    if (bindingName.contains('Test')) return true;
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: widget.cycleDuration,
    );
    if (!_isInTest) {
      _controller.repeat();
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!_isInTest && !_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedMathBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cycleDuration != widget.cycleDuration) {
      _controller.duration = widget.cycleDuration;
      if (!_isInTest && !_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mathTokens = Theme.of(context).extension<MathTokens>();
    final effectiveGridColor = widget.gridColor ?? mathTokens?.gridLineColor ?? const Color(0xFF1E293B);
    final effectiveWaveColor = widget.waveColor ?? mathTokens?.statisticHighlightColor ?? const Color(0xFF38BDF8);

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    if (reduceMotion) {
      return Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _AnimatedMathPainter(
                  progress: 0.0,
                  gridColor: effectiveGridColor,
                  waveColor: effectiveWaveColor,
                  spacing: widget.gridSpacing,
                  opacity: widget.opacity,
                  showWave: widget.showWave,
                  showAxes: widget.showAxes,
                  showFormulas: widget.showFormulas,
                  showNodes: widget.showNodes,
                ),
              ),
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AnimatedMathPainter(
                    progress: _controller.value,
                    gridColor: effectiveGridColor,
                    waveColor: effectiveWaveColor,
                    spacing: widget.gridSpacing,
                    opacity: widget.opacity,
                    showWave: widget.showWave,
                    showAxes: widget.showAxes,
                    showFormulas: widget.showFormulas,
                    showNodes: widget.showNodes,
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.child != null) widget.child!,
      ],
    );
  }
}

class _AnimatedMathPainter extends CustomPainter {
  final double progress;
  final Color gridColor;
  final Color waveColor;
  final double spacing;
  final double opacity;
  final bool showWave;
  final bool showAxes;
  final bool showFormulas;
  final bool showNodes;

  // Cached paint objects to eliminate GC pressure per frame
  static final Paint _basePaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _nodePaint = Paint()..style = PaintingStyle.fill;
  static final Paint _wavePaint = Paint()..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
  static final Paint _secondaryPaint = Paint()..style = PaintingStyle.stroke;
  static final Paint _axesPaint = Paint();
  static final Paint _originPaint = Paint()..style = PaintingStyle.stroke;

  // Cached TextPainters to avoid running layout() 60-120 times per second
  static List<TextPainter>? _cachedFormulas;
  static Color? _lastFormulaColor;
  static double? _lastFormulaOpacity;

  static const List<String> _formulaStrings = [
    'f(x) = A sin(kx - ωt)',
    '∫ f(x) dx = F(x) + C',
    'e^(iπ) + 1 = 0',
    '∑ (xᵢ - μ)² / N',
    'Target 800 • SAT Math',
  ];

  _AnimatedMathPainter({
    required this.progress,
    required this.gridColor,
    required this.waveColor,
    required this.spacing,
    required this.opacity,
    required this.showWave,
    required this.showAxes,
    required this.showFormulas,
    required this.showNodes,
  });

  static List<TextPainter> _getOrCreateFormulas(Color gridColor, double opacity) {
    if (_cachedFormulas != null &&
        _lastFormulaColor == gridColor &&
        _lastFormulaOpacity == opacity) {
      return _cachedFormulas!;
    }

    _lastFormulaColor = gridColor;
    _lastFormulaOpacity = opacity;

    final textStyle = TextStyle(
      color: gridColor.withValues(alpha: opacity * 1.3),
      fontSize: 15,
      fontWeight: FontWeight.w600,
      fontStyle: FontStyle.italic,
      fontFamily: 'serif',
    );

    _cachedFormulas = _formulaStrings.map((formula) {
      final tp = TextPainter(
        text: TextSpan(text: formula, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      return tp;
    }).toList();

    return _cachedFormulas!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    _basePaint
      ..color = gridColor.withValues(alpha: opacity)
      ..strokeWidth = 0.7;

    // ── 1. Drifting Cartesian Coordinate Grid ──────────────────────────────
    final offsetX = (progress * spacing) % spacing;
    final offsetY = (progress * spacing * 0.5) % spacing;

    // Vertical Lines
    for (double x = -spacing + offsetX; x <= size.width + spacing; x += spacing) {
      if (x >= 0 && x <= size.width) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), _basePaint);
      }
    }

    // Horizontal Lines
    for (double y = -spacing + offsetY; y <= size.height + spacing; y += spacing) {
      if (y >= 0 && y <= size.height) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), _basePaint);
      }
    }

    // ── 2. Pulsing Coordinate Nodes (Intersection Points) ──────────────────
    if (showNodes) {
      final step = spacing * 2;
      for (double x = -step + offsetX; x <= size.width + step; x += step) {
        for (double y = -step + offsetY; y <= size.height + step; y += step) {
          if (x >= 0 && x <= size.width && y >= 0 && y <= size.height) {
            final phase = (x / 200.0) + (y / 200.0) + (progress * 2 * math.pi);
            final pulseAlpha = opacity * (1.2 + 0.8 * math.sin(phase)).clamp(0.0, 1.0);
            _nodePaint.color = gridColor.withValues(alpha: pulseAlpha * 2.2);

            final radius = 1.0 + 0.5 * math.sin(phase);
            canvas.drawCircle(Offset(x, y), radius, _nodePaint);
          }
        }
      }
    }

    // ── 3. Luminous Harmonic Sine Waves y = A * sin(kx - ωt) ────────────────
    if (showWave && size.width > 200) {
      final midY = size.height * 0.62;
      final waveLength = size.width * 0.75;
      const amplitude = 34.0;
      final k = 2 * math.pi / waveLength;
      final omegaT = progress * 2 * math.pi;

      final wavePath = Path();
      final secondaryWavePath = Path();

      bool first = true;
      for (double x = 0; x <= size.width; x += 6.0) {
        final envelope = math.sin((x / size.width) * math.pi);
        final y1 = midY + amplitude * math.sin(k * x - omegaT) * envelope;
        final y2 = midY + (amplitude * 0.45) * math.cos(2 * k * x - 1.5 * omegaT) * envelope;

        if (first) {
          wavePath.moveTo(x, y1);
          secondaryWavePath.moveTo(x, y2);
          first = false;
        } else {
          wavePath.lineTo(x, y1);
          secondaryWavePath.lineTo(x, y2);
        }
      }

      _secondaryPaint
        ..color = gridColor.withValues(alpha: opacity * 1.0)
        ..strokeWidth = 1.0;

      _wavePaint
        ..color = waveColor.withValues(alpha: opacity * 1.6)
        ..strokeWidth = 1.6;

      canvas.drawPath(secondaryWavePath, _secondaryPaint);
      canvas.drawPath(wavePath, _wavePaint);
    }

    // ── 4. Cartesian Coordinate Axes (X & Y) ─────────────────────────────────
    if (showAxes) {
      _axesPaint
        ..color = gridColor.withValues(alpha: opacity * 2.2)
        ..strokeWidth = 1.2;

      final midX = size.width * 0.5;
      final midY = size.height * 0.5;

      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), _axesPaint);
      canvas.drawLine(Offset(midX, 0), Offset(midX, size.height), _axesPaint);

      _originPaint
        ..color = gridColor.withValues(alpha: opacity * 2.8)
        ..strokeWidth = 1.2;
      canvas.drawCircle(Offset(midX, midY), 4.0, _originPaint);
    }

    // ── 5. Ambient Mathematical Formulas (Cached TextPainters) ──────────────
    if (showFormulas && size.width > 340) {
      final formulas = _getOrCreateFormulas(gridColor, opacity);

      for (int i = 0; i < formulas.length; i++) {
        final tp = formulas[i];
        final dy = 36.0 + (i * 130.0);
        if (dy + tp.height < size.height) {
          final dx = (i % 2 == 0) ? 28.0 : size.width - tp.width - 28.0;
          tp.paint(canvas, Offset(dx, dy));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedMathPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.waveColor != waveColor ||
        oldDelegate.opacity != opacity ||
        oldDelegate.showWave != showWave;
  }
}
