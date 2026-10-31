import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// بطاقة خيار واحد (A / B / C / D) — تعرض نصاً أو معادلة أو صورة
class OptionCard extends StatelessWidget {
  final String optionKey; // "A" / "B" / "C" / "D"
  final String text; // نص الخيار (أو LaTeX)
  final String? assetUrl; // URL الصورة إذا كان الخيار فيه رسمة
  final bool isSelected; // هل هو الإجابة الصحيحة المحددة؟
  final bool isInteractive; // هل يمكن للمدرس الضغط عليه؟
  final VoidCallback? onTap;

  const OptionCard({
    super.key,
    required this.optionKey,
    required this.text,
    this.assetUrl,
    this.isSelected = false,
    this.isInteractive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color borderColor = isSelected
        ? AppColors.success
        : theme.colorScheme.outlineVariant;
    final Color bgColor = isSelected
        ? AppColors.successLight.withAlpha(30)
        : theme.colorScheme.surface;
    final Color avatarBg = isSelected
        ? AppColors.success
        : theme.colorScheme.primaryContainer;
    final Color avatarFg = isSelected
        ? Colors.white
        : theme.colorScheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: InkWell(
        onTap: isInteractive ? onTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // حرف الخيار
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: avatarBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  optionKey,
                  style: TextStyle(
                    color: avatarFg,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),

              // محتوى الخيار
              Expanded(
                child: _buildOptionContent(context, theme),
              ),

              // علامة الصح إذا محدد
              if (isSelected)
                const Padding(
                  padding: EdgeInsetsDirectional.only(start: AppSpacing.s8),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),

              // أيقونة الضغط (interactive hint)
              if (isInteractive && !isSelected)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: AppSpacing.s8),
                  child: Icon(
                    Icons.radio_button_unchecked_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionContent(BuildContext context, ThemeData theme) {
    final baseStyle = theme.textTheme.bodyMedium?.copyWith(height: 1.5);

    // إذا كان في الخيار صورة (حالة نادرة جداً في امتحانات ExamView)
    if (assetUrl != null && assetUrl!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (text.isNotEmpty) Text(text, style: baseStyle),
          const SizedBox(height: AppSpacing.s4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            child: CachedNetworkImage(
              imageUrl: assetUrl!,
              memCacheWidth: 400,
              memCacheHeight: 200,
              maxWidthDiskCache: 600,
              fit: BoxFit.contain,
              height: 80,
              placeholder: (_, __) =>
                  const CircularProgressIndicator(strokeWidth: 2),
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined),
            ),
          ),
        ],
      );
    }

    // نص عادي أو LaTeX مضمّن
    if (text.isEmpty) return const SizedBox.shrink();

    // فحص LaTeX مضمّن
    final regex = RegExp(r'(\$\$[\s\S]+?\$\$|\$[^\$\n]+?\$)');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    // نص مختلط بمعادلات
    final widgets = <Widget>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final plain = text.substring(lastEnd, match.start);
        if (plain.isNotEmpty) widgets.add(Text(plain, style: baseStyle));
      }

      final rawMath = match.group(0)!;
      final isDisplay = rawMath.startsWith(r'$$') && rawMath.endsWith(r'$$');
      final cleanLatex = isDisplay
          ? rawMath.substring(2, rawMath.length - 2).trim()
          : rawMath.substring(1, rawMath.length - 1).trim();

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Math.tex(
            cleanLatex,
            textStyle: baseStyle?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
            onErrorFallback: (err) => Text(rawMath, style: baseStyle),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      widgets.add(Text(text.substring(lastEnd), style: baseStyle));
    }

    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: widgets);
  }
}
