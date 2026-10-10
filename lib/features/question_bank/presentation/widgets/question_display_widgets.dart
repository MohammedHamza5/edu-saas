import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        return _AssetBlock(
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
          return _AssetBlock(url: resolveUrl(trimmed));
        }

        // Check for markdown image format ![alt](url)
        final mdImgMatch = RegExp(r'^!\[(.*?)\]\((https?://[^\)]+)\)$').firstMatch(trimmed);
        if (mdImgMatch != null) {
          final alt = mdImgMatch.group(1);
          final imgUrl = mdImgMatch.group(2);
          return _AssetBlock(
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
      return _AssetBlock(url: trimmed);
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

// ─────────────────────────────────────────────────────────────────────────────
// Asset Block: رسمة بيانية/شكل هندسي حقيقي (ليس نصاً)
// ─────────────────────────────────────────────────────────────────────────────

class _AssetBlock extends StatelessWidget {
  final String? url;
  final String? description;

  const _AssetBlock({this.url, this.description});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (url == null || url!.isEmpty) {
      // لا يوجد URL — نعرض وصفاً نصياً فقط
      if (description != null && description!.isNotEmpty) {
        return _AssetDescription(description: description!, theme: theme);
      }
      return const SizedBox.shrink();
    }

    final isNetwork = url!.startsWith('http://') || url!.startsWith('https://');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شارة "رسم بياني"
          Row(
            children: [
              Icon(
                Icons.image_outlined,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.diagramLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),

          // الصورة نفسها
          GestureDetector(
            onTap: () => _showZoom(context, url!),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: isNetwork
                    ? CachedNetworkImage(
                        imageUrl: url!,
                        memCacheWidth: 800,
                        memCacheHeight: 800,
                        maxWidthDiskCache: 1200,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) => _BrokenImagePlaceholder(
                          label: l10n.imageNotAccessible,
                        ),
                      )
                    : _BrokenImagePlaceholder(label: url!),
              ),
            ),
          ),

          // وصف الرسمة (إذا وُجد)
          if (description != null && description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s6),
            Text(
              description!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // زر التكبير
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _showZoom(context, url!),
              icon: const Icon(Icons.zoom_in_rounded, size: 16),
              label: Text(l10n.zoomAsset),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showZoom(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black87,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: CachedNetworkImage(
                imageUrl: url,
                memCacheWidth: 1200,
                maxWidthDiskCache: 1600,
                fit: BoxFit.contain,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── مساعد: وصف نصي عندما لا تتوفر صورة ──────────────────────────────────────

class _AssetDescription extends StatelessWidget {
  final String description;
  final ThemeData theme;

  const _AssetDescription({required this.description, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.image_outlined,
              size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── مساعد: placeholder صورة مكسورة ──────────────────────────────────────────

class _BrokenImagePlaceholder extends StatelessWidget {
  final String label;

  const _BrokenImagePlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: AppColors.error),
          const SizedBox(width: AppSpacing.s8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OptionCard: بطاقة خيار واحد (A / B / C / D) — تعرض نصاً أو معادلة
// ─────────────────────────────────────────────────────────────────────────────

class OptionCard extends StatelessWidget {
  final String optionKey;         // "A" / "B" / "C" / "D"
  final String text;              // نص الخيار (أو LaTeX)
  final String? assetUrl;         // URL الصورة إذا كان الخيار فيه رسمة
  final bool isSelected;          // هل هو الإجابة الصحيحة المحددة؟
  final bool isInteractive;       // هل يمكن للمدرس الضغط عليه؟
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
