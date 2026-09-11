import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';
import '../theme/math_tokens.dart';

/// A prestigious academic hero banner with a mathematical aesthetic,
/// deep indigo gradient, and subtle formula watermarks.
class AcademicHeroBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? academicTrack;
  final String? badgeText;
  final Widget? trailing;
  final VoidCallback? onActionTap;
  final String? actionLabel;

  const AcademicHeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.academicTrack,
    this.badgeText,
    this.trailing,
    this.onActionTap,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final mathTokens = Theme.of(context).extension<MathTokens>() ?? MathTokens.light;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        gradient: mathTokens.primaryButtonGradient,
        boxShadow: mathTokens.cardShadowElevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Mathematical formula watermark in the background
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _BannerMathWatermarkPainter(),
              ),
            ),
          ),

          // Main banner content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s24,
              vertical: AppSpacing.s20,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Badges row
                      Wrap(
                        spacing: AppSpacing.s8,
                        runSpacing: AppSpacing.s8,
                        children: [
                          if (academicTrack != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s10,
                                vertical: AppSpacing.s4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4ADE80), // Emerald dot
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s6),
                                  Flexible(
                                    child: Text(
                                      academicTrack!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (badgeText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s10,
                                vertical: AppSpacing.s4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                              ),
                              child: Text(
                                badgeText!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      // Title
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s6),

                      // Subtitle
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 13,
                          fontWeight: FontWeight.normal,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.s16),
                  Flexible(child: trailing!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerMathWatermarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const textStyle = TextStyle(
      color: Color(0x15FFFFFF),
      fontSize: 28,
      fontWeight: FontWeight.w700,
      fontStyle: FontStyle.italic,
    );

    final formulas = [
      'f(x) = ax² + bx + c',
      '∑ π √x',
      'e^{iπ} + 1 = 0',
      'lim_{x→0} sin(x)/x = 1',
    ];

    // Right-aligned watermark text
    for (int i = 0; i < formulas.length; i++) {
      final span = TextSpan(text: formulas[i], style: textStyle);
      final tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();

      final dy = 12.0 + (i * 24.0);
      if (dy + tp.height < size.height + 20) {
        tp.paint(canvas, Offset(size.width - tp.width - 24, dy));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
