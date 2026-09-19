import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/math_tokens.dart';

enum AppCardVariant {
  /// Default card: subtle border, no shadow
  standard,

  /// Elevated card: soft shadow + hover lift animation
  elevated,

  /// Premium card: gradient border glow + deeper shadow
  premium,
}

class AppCard extends StatefulWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final AppCardVariant variant;

  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(AppSpacing.s16),
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.variant = AppCardVariant.standard,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late AnimationController _hoverController;
  late Animation<double> _shadowAnimation;
  late Animation<double> _scaleAnimation;

  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _shadowAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.004).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _onHover(bool hovered) {
    if (!mounted) return;
    setState(() => _isHovered = hovered);
    if (hovered) {
      _hoverController.forward();
    } else {
      _hoverController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final mathTokens =
        Theme.of(context).extension<MathTokens>() ?? MathTokens.light;

    final hasHeader = widget.title != null || widget.trailing != null;
    final Widget content = hasHeader
        ? Padding(
            padding: widget.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.title != null)
                            Text(
                              widget.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: AppSpacing.s4),
                            Text(
                              widget.subtitle!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.trailing != null) widget.trailing!,
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.s12),
                widget.child,
              ],
            ),
          )
        : Padding(
            padding: widget.padding,
            child: widget.child,
          );

    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        final canAnimate = widget.onTap != null || widget.variant != AppCardVariant.standard;

        List<BoxShadow> shadows() {
          if (widget.variant == AppCardVariant.premium) {
            return BoxShadow.lerpList(
              mathTokens.cardShadowElevated,
              mathTokens.cardShadowPremium,
              _shadowAnimation.value,
            ) ?? mathTokens.cardShadowElevated;
          }
          if (widget.variant == AppCardVariant.elevated || canAnimate) {
            return BoxShadow.lerpList(
              const [],
              mathTokens.cardShadowElevated,
              _shadowAnimation.value,
            ) ?? const [];
          }
          return const [];
        }

        final scale = canAnimate ? _scaleAnimation.value : 1.0;
        final borderColor = _isHovered
            ? (widget.variant == AppCardVariant.premium
                ? AppColors.borderPremium
                : const Color(0xFF38BDF8).withValues(alpha: 0.35))
            : (widget.borderColor ?? mathTokens.cardBorderColor);

        return Transform.scale(
          scale: scale,
          child: MouseRegion(
            cursor: widget.onTap != null
                ? SystemMouseCursors.click
                : MouseCursor.defer,
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: widget.backgroundColor ?? AppColors.surface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: borderColor, width: 1),
                boxShadow: shadows(),
              ),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: widget.onTap != null
                    ? InkWell(
                        onTap: widget.onTap,
                        mouseCursor: SystemMouseCursors.click,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                        child: content,
                      )
                    : content,
              ),
            ),
          ),
        );
      },
    );
  }
}
