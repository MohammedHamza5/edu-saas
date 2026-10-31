import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

import '../../../../core/theme/app_spacing.dart';
import 'question_asset_block.dart';

export 'option_card.dart';
export 'question_asset_block.dart';

/// واجهة عرض سؤال كاملة — نص + معادلات + رسومات (إذا وُجدت)
///
/// تعرض السؤال كـ نص رقمي أنيق بالكامل.
/// الصور تظهر فقط إذا كانت رسومات بيانية/أشكال هندسية حقيقية.
/// تدعم: نص عادي / LaTeX / نص مختلط بمعادلات.
class QuestionStemView extends StatelessWidget {
  /// قائمة blocks من قاعدة البيانات (content.stem)
  final List<Map<String, dynamic>> blocks;

  /// دالة لتحويل المسار النسبي → URL كامل
  final String? Function(String?) resolveUrl;

  /// حجم الخط (اختياري)
  final double? fontSize;

  const QuestionStemView({
    super.key,
    required this.blocks,
    required this.resolveUrl,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks.map((block) => _buildBlock(context, block)).toList(),
    );
  }

  Widget _buildBlock(BuildContext context, Map<String, dynamic> block) {
    final type = block['type']?.toString() ?? 'text';
    final value = block['latex']?.toString() ??
        block['value']?.toString() ??
        '';

    switch (type) {
      case 'image':
      case 'asset':
        final rawAsset = block['crop_asset'] ??
            block['path'] ??
            block['url'] ??
            value;
        final url = resolveUrl(rawAsset?.toString());
        final description = value.isNotEmpty && !value.contains('/') && !value.startsWith('http') ? value : null;
        return QuestionAssetBlock(
          url: url,
          description: description,
        );

      case 'math':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
          child: _MathBlock(formula: value, fontSize: fontSize),
        );

      case 'text':
      default:
        if (value.isEmpty) return const SizedBox.shrink();

        final trimmed = value.trim();
        // Check if value is a standalone image URL
        if (isImageUrl(trimmed)) {
          return QuestionAssetBlock(url: resolveUrl(trimmed));
        }

        // Check for markdown image format ![alt](url)
        final mdImgMatch = RegExp(r'^!\[(.*?)\]\((https?://[^\)]+)\)$').firstMatch(trimmed);
        if (mdImgMatch != null) {
          final alt = mdImgMatch.group(1);
          final imgUrl = mdImgMatch.group(2);
          return QuestionAssetBlock(
            url: resolveUrl(imgUrl),
            description: alt != null && alt.isNotEmpty ? alt : null,
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s4),
          child: _RichTextBlock(text: value, fontSize: fontSize),
        );
    }
  }

  static bool isImageUrl(String str) {
    final lower = str.trim().toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return false;
    }
    return lower.contains('.png') ||
        lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.webp') ||
        lower.contains('.gif') ||
        lower.contains('/storage/v1/object/') ||
        lower.contains('/exam_images/');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Text Block: نص عادي مع دعم LaTeX مضمّن $...$
// ─────────────────────────────────────────────────────────────────────────────

class _RichTextBlock extends StatelessWidget {
  final String text;
  final double? fontSize;

  const _RichTextBlock({required this.text, this.fontSize});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.bodyLarge?.copyWith(
      height: 1.7,
      fontSize: fontSize ?? 15,
      color: theme.colorScheme.onSurface,
    );

    // فحص: هل النص يحتوي على LaTeX مضمّن؟
    final regex = RegExp(r'(\$\$[\s\S]+?\$\$|\$[^\$\n]+?\$)');
    final matches = regex.allMatches(text);

    final trimmed = text.trim();
    if (QuestionStemView.isImageUrl(trimmed)) {
      return QuestionAssetBlock(url: trimmed);
    }

    if (matches.isEmpty) {
      // نص عادي بالكامل
      return SelectableText(text, style: baseStyle);
    }

    // نص مختلط بمعادلات → Wrap
    final widgets = <Widget>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final plain = text.substring(lastEnd, match.start);
        if (plain.isNotEmpty) {
          widgets.add(
            Text(plain, style: baseStyle),
          );
        }
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

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Math Block: معادلة LaTeX خالصة بشكل بارز
// ─────────────────────────────────────────────────────────────────────────────

class _MathBlock extends StatelessWidget {
  final String formula;
  final double? fontSize;

  const _MathBlock({required this.formula, this.fontSize});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clean = formula.trim()
        .replaceFirst(RegExp(r'^\$\$'), '')
        .replaceFirst(RegExp(r'\$\$$'), '')
        .replaceFirst(RegExp(r'^\$'), '')
        .replaceFirst(RegExp(r'\$$'), '')
        .trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withAlpha(20),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.primary.withAlpha(80),
            width: 3,
          ),
        ),
      ),
      child: Math.tex(
        clean,
        textStyle: TextStyle(
          fontSize: (fontSize ?? 15) + 1,
          color: theme.colorScheme.onSurface,
        ),
        mathStyle: MathStyle.display,
        onErrorFallback: (err) => SelectableText(
          formula,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
