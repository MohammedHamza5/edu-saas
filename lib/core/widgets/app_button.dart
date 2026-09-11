import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/math_tokens.dart';
import 'app_loading_view.dart';

enum AppButtonVariant { primary, secondary, outlined, text }

class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final double? width;

  const AppButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.width,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  Timer? _debounceTimer;
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  bool get _isDebouncing => _debounceTimer?.isActive ?? false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pressController.dispose();
    super.dispose();
  }

  void _handlePress() {
    if (widget.isLoading || widget.onPressed == null || _isDebouncing) return;

    _pressController.forward().then((_) {
      if (mounted) _pressController.reverse();
    });

    widget.onPressed!();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final mathTokens =
        Theme.of(context).extension<MathTokens>() ?? MathTokens.light;

    final effectiveOnPressed =
        (widget.onPressed != null && !widget.isLoading) ? _handlePress : null;

    final childWidget = widget.isLoading
        ? AppLoadingView.compact(
            size: 20,
            color: widget.variant == AppButtonVariant.primary
                ? Colors.white
                : AppColors.primary,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const SizedBox(width: AppSpacing.s8),
              ],
              Flexible(
                child: Text(
                  widget.text,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          );

    final isDisabled = effectiveOnPressed == null;

    Widget button;

    if (widget.variant == AppButtonVariant.primary) {
      // Premium gradient primary button
      button = GestureDetector(
        onTap: effectiveOnPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 50,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: isDisabled
                  ? null
                  : mathTokens.primaryButtonGradient,
              color: isDisabled ? AppColors.border : null,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              boxShadow: isDisabled
                  ? null
                  : [
                      BoxShadow(
                        color: AppColors.primary.withValues(
                          alpha: _isHovered ? 0.45 : 0.30,
                        ),
                        blurRadius: _isHovered ? 16 : 12,
                        offset: Offset(0, _isHovered ? 6 : 4),
                        spreadRadius: _isHovered ? -1 : -2,
                      ),
                    ],
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.1,
              ),
              child: IconTheme(
                data: const IconThemeData(color: Colors.white, size: 18),
                child: Center(child: childWidget),
              ),
            ),
          ),
        ),
      );
    } else {
      button = switch (widget.variant) {
        AppButtonVariant.primary => const SizedBox.shrink(), // handled above
        AppButtonVariant.secondary => ElevatedButton(
            onPressed: effectiveOnPressed,
            style: ElevatedButton.styleFrom(
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.basic,
              backgroundColor: AppColors.surfaceVariant,
              foregroundColor: AppColors.textPrimary,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                side: const BorderSide(color: AppColors.border),
              ),
              elevation: 0,
            ),
            child: childWidget,
          ),
        AppButtonVariant.outlined => OutlinedButton(
            onPressed: effectiveOnPressed,
            style: OutlinedButton.styleFrom(
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.basic,
              minimumSize: const Size(double.infinity, 50),
            ),
            child: childWidget,
          ),
        AppButtonVariant.text => TextButton(
            onPressed: effectiveOnPressed,
            style: TextButton.styleFrom(
              enabledMouseCursor: SystemMouseCursors.click,
              disabledMouseCursor: SystemMouseCursors.basic,
              foregroundColor: AppColors.primary,
            ),
            child: childWidget,
          ),
      };

      // Wrap non-primary buttons with scale animation too
      button = AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: button,
      );
    }

    final sizedButton = widget.width != null
        ? SizedBox(width: widget.width, child: button)
        : button;

    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        if (!isDisabled && mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (!isDisabled && mounted) setState(() => _isHovered = false);
      },
      child: sizedButton,
    );
  }
}
