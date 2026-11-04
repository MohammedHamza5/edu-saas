import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';

/// Interactive math/numerical input widget for Student-Produced Response (Grid-in) questions.
/// Features live input filtering, fast on-screen math utility chips, and real-time normalized preview.
class ExamGridInInputPane extends StatefulWidget {
  final String? currentAnswer;
  final ValueChanged<String> onAnswerChanged;
  final bool isSubmitting;

  const ExamGridInInputPane({
    super.key,
    required this.currentAnswer,
    required this.onAnswerChanged,
    required this.isSubmitting,
  });

  @override
  State<ExamGridInInputPane> createState() => _ExamGridInInputPaneState();
}

class _ExamGridInInputPaneState extends State<ExamGridInInputPane> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentAnswer ?? '');
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ExamGridInInputPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentAnswer != oldWidget.currentAnswer &&
        widget.currentAnswer != _controller.text) {
      _controller.text = widget.currentAnswer ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _appendChar(String char) {
    if (widget.isSubmitting) return;
    final current = _controller.text;
    final updated = current + char;
    _controller.text = updated;
    _controller.selection = TextSelection.collapsed(offset: updated.length);
    widget.onAnswerChanged(updated);
  }

  void _backspace() {
    if (widget.isSubmitting) return;
    final current = _controller.text;
    if (current.isNotEmpty) {
      final updated = current.substring(0, current.length - 1);
      _controller.text = updated;
      _controller.selection = TextSelection.collapsed(offset: updated.length);
      widget.onAnswerChanged(updated);
    }
  }

  void _clear() {
    if (widget.isSubmitting) return;
    _controller.clear();
    widget.onAnswerChanged('');
  }

  /// Calculates a client-side friendly normalized preview for user assurance
  String? _computeFriendlyPreview(String raw) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return null;

    // Convert Arabic numerals
    var normalized = cleaned;
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    for (int i = 0; i < 10; i++) {
      normalized = normalized.replaceAll(arabicDigits[i], '$i');
    }
    normalized = normalized.replaceAll('٫', '.').replaceAll(',', '.');
    normalized = normalized.replaceAll('−', '-').replaceAll('–', '-').replaceAll('—', '-');
    normalized = normalized.replaceAll(RegExp(r'\s+'), '');

    if (normalized.contains('/')) {
      final parts = normalized.split('/');
      if (parts.length == 2) {
        final n = double.tryParse(parts[0]);
        final d = double.tryParse(parts[1]);
        if (n != null && d != null && d != 0) {
          final val = n / d;
          return val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 4);
        }
      }
    } else {
      final val = double.tryParse(normalized);
      if (val != null) {
        return val.toStringAsFixed(val.truncateToDouble() == val ? 0 : 4);
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentText = _controller.text;
    final friendlyPreview = _computeFriendlyPreview(currentText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.gridInInputLabel,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Text Field with input filter
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: !widget.isSubmitting,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: AppColors.primary,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                    RegExp(r'[0-9\.\/\-\,\٠-\٩]'),
                  ),
                ],
                decoration: InputDecoration(
                  hintText: l10n.gridInAnswerPlaceholder,
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0,
                    color: AppColors.textMuted,
                  ),
                  filled: true,
                  fillColor: AppColors.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    borderSide: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  suffixIcon: currentText.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          tooltip: l10n.gridInClearAnswer,
                          onPressed: _clear,
                        )
                      : null,
                ),
                onChanged: (val) => widget.onAnswerChanged(val),
              ),

              const SizedBox(height: AppSpacing.s12),

              // 2. Math Utility Helper Chips (for easy tapping on mobile/tablets)
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  _buildMathChip('/', 'Fraction (/)'),
                  _buildMathChip('.', 'Decimal (.)'),
                  _buildMathChip('-', 'Negative (-)'),
                  ActionChip(
                    avatar: const Icon(Icons.backspace_outlined, size: 14),
                    label: const Text('⌫', style: TextStyle(fontSize: 13)),
                    backgroundColor: AppColors.surfaceVariant,
                    onPressed: widget.isSubmitting ? null : _backspace,
                  ),
                  if (currentText.isNotEmpty)
                    ActionChip(
                      label: Text(
                        l10n.gridInClearAnswer,
                        style: const TextStyle(fontSize: 12, color: AppColors.error),
                      ),
                      backgroundColor: AppColors.error.withValues(alpha: 0.08),
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                      onPressed: widget.isSubmitting ? null : _clear,
                    ),
                ],
              ),

              // 3. Normalized Math Confidence Badge
              if (friendlyPreview != null) ...[
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.s6),
                      Text(
                        '≈ $friendlyPreview',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMathChip(String symbol, String tooltip) {
    return ActionChip(
      label: Text(
        symbol,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
      tooltip: tooltip,
      backgroundColor: AppColors.surfaceVariant,
      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.15)),
      onPressed: widget.isSubmitting ? null : () => _appendChar(symbol),
    );
  }
}
