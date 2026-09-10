import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? label;
  final String? hintText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final int maxLines;
  final TextStyle? style;

  const AppTextField({
    super.key,
    this.controller,
    this.labelText,
    this.label,
    this.hintText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.style,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    Widget? effectiveSuffixIcon = widget.suffixIcon;

    if (widget.isPassword) {
      effectiveSuffixIcon = IconButton(
        mouseCursor: SystemMouseCursors.click,
        icon: Icon(
          _obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          size: 20,
        ),
        onPressed: () {
          setState(() {
            _obscureText = !_obscureText;
          });
        },
      );
    }

    final textColor = widget.style?.color ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.textPrimary);

    return TextFormField(
      controller: widget.controller,
      obscureText: _obscureText,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      validator: widget.validator,
      enabled: widget.enabled,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      style: (widget.style ?? const TextStyle(fontSize: 14)).copyWith(
        color: textColor,
      ),
      decoration: InputDecoration(
        labelText: widget.labelText ?? widget.label,
        hintText: widget.hintText,
        errorText: widget.errorText,
        prefixIcon: widget.prefixIcon,
        suffixIcon: effectiveSuffixIcon,
      ),
    );
  }
}
