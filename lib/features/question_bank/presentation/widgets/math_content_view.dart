import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/extensions/localized_context_extension.dart';

/// A rich content viewer that parses LaTeX formulas ($...$ or $$...$$),
/// renders pure KaTeX math via [flutter_math_fork], and displays visual diagram assets.
/// Forces LTR text directionality for academic mathematical content to prevent RTL distortion.
class MathContentView extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;
  final TextStyle? mathStyle;
  final String? assetUrl;
  final double? maxAssetHeight;
  final bool isMath;
  final TextDirection textDirection;

  const MathContentView({
    super.key,
    required this.text,
    this.textStyle,
    this.mathStyle,
    this.assetUrl,
    this.maxAssetHeight = 220,
    this.isMath = false,
    this.textDirection = TextDirection.ltr,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveTextStyle =
        textStyle ?? theme.textTheme.bodyLarge?.copyWith(height: 1.6);
    final effectiveMathStyle =
        mathStyle ??
        effectiveTextStyle?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        );

    final widgets = <Widget>[];

    // If there is an associated asset image/crop
    if (assetUrl != null && assetUrl!.isNotEmpty) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          child: _buildAssetWidget(context, assetUrl!),
        ),
      );
    }

    if (text.isNotEmpty) {
      widgets.add(
        _buildParsedText(context, effectiveTextStyle, effectiveMathStyle),
      );
    }

    if (widgets.isEmpty) {
      return const SizedBox.shrink();
    }

    final content = widgets.length == 1
        ? widgets.first
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: widgets,
          );

    return Directionality(textDirection: textDirection, child: content);
  }

  Widget _buildParsedText(
    BuildContext context,
    TextStyle? bodyStyle,
    TextStyle? mathTextStyle,
  ) {
    // If explicitly marked as math or detected as pure LaTeX / mathematical expression
    if (isMath || _isPureLatex(text)) {
      final clean = text.trim();
      final formula = (clean.startsWith(r'$$') && clean.endsWith(r'$$'))
          ? clean.substring(2, clean.length - 2).trim()
          : (clean.startsWith(r'$') && clean.endsWith(r'$'))
          ? clean.substring(1, clean.length - 1).trim()
          : clean;

      return Math.tex(
        formula,
        textStyle: mathTextStyle,
        mathStyle: MathStyle.display,
        onErrorFallback: (err) => Text(text, style: bodyStyle),
      );
    }

    // Split text by $...$ and $$...$$
    final regex = RegExp(r'(\$\$[\s\S]+?\$\$|\$[^\$\n]+?\$)');
    final matches = regex.allMatches(text);

    if (matches.isEmpty) {
      return Text(text, style: bodyStyle);
    }

    final spans = <Widget>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final plain = text.substring(lastEnd, match.start);
        spans.add(Text(plain, style: bodyStyle));
      }

      final rawMath = match.group(0)!;
      final isDisplay = rawMath.startsWith(r'$$') && rawMath.endsWith(r'$$');
      final cleanLatex = isDisplay
          ? rawMath.substring(2, rawMath.length - 2).trim()
          : rawMath.substring(1, rawMath.length - 1).trim();

      spans.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Math.tex(
            cleanLatex,
            textStyle: mathTextStyle,
            mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
            onErrorFallback: (err) => Text(rawMath, style: bodyStyle),
          ),
        ),
      );

      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd);
      spans.add(Text(remaining, style: bodyStyle));
    }

    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: spans);
  }

  bool _isPureLatex(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith(r'\') ||
        trimmed.startsWith(r'$$') ||
        trimmed.startsWith(r'$')) {
      return true;
    }
    // Equations containing equals and exponents or fractions
    if (trimmed.contains('=') &&
        (trimmed.contains('^') ||
            trimmed.contains(r'\') ||
            trimmed.contains('_'))) {
      return true;
    }
    return trimmed.startsWith(r'\frac') ||
        trimmed.startsWith(r'\sqrt') ||
        trimmed.startsWith(r'\sum') ||
        trimmed.startsWith(r'\int') ||
        trimmed.startsWith(r'\begin{') ||
        trimmed.startsWith(r'\[') ||
        trimmed.startsWith(r'\(');
  }

  Widget _buildAssetWidget(BuildContext context, String url) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxAssetHeight ?? 220),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            if (url.startsWith('http://') || url.startsWith('https://'))
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (context, _) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.s16),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, _, __) => Container(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  color: AppColors.errorLight.withAlpha(40),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image, color: AppColors.error),
                      const SizedBox(width: AppSpacing.s8),
                      Text(
                        context.l10n.imageNotAccessible,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: Row(
                  children: [
                    const Icon(Icons.image, color: AppColors.info),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        'Asset: $url',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            IconButton(
              icon: const Icon(Icons.zoom_in, size: 20),
              tooltip: context.l10n.zoomAsset,
              onPressed: () => _showZoomDialog(context, url),
            ),
          ],
        ),
      ),
    );
  }

  void _showZoomDialog(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: url.startsWith('http')
                    ? CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)
                    : Container(
                        padding: const EdgeInsets.all(32),
                        color: Colors.white,
                        child: Text('Asset: $url'),
                      ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
