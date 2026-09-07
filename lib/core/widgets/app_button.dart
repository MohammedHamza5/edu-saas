import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

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

class _AppButtonState extends State<AppButton> {
  Timer? _debounceTimer;

  bool get _isDebouncing => _debounceTimer?.isActive ?? false;

  void _handlePress() {
    if (widget.isLoading || widget.onPressed == null || _isDebouncing) return;

    setState(() {});
    widget.onPressed!();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (widget.onPressed != null && !widget.isLoading) ? _handlePress : null;

    final childWidget = widget.isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.variant == AppButtonVariant.primary ? Colors.white : AppColors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18),
                const SizedBox(width: AppSpacing.s8),
              ],
              Text(widget.text),
            ],
          );

    final button = switch (widget.variant) {
      AppButtonVariant.primary => ElevatedButton(
          onPressed: effectiveOnPressed,
          child: childWidget,
        ),
      AppButtonVariant.secondary => ElevatedButton(
          onPressed: effectiveOnPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.surfaceVariant,
            foregroundColor: AppColors.textPrimary,
          ),
          child: childWidget,
        ),
      AppButtonVariant.outlined => OutlinedButton(
          onPressed: effectiveOnPressed,
          child: childWidget,
        ),
      AppButtonVariant.text => TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
          child: childWidget,
        ),
    };

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: button);
    }

    return button;
  }
}
