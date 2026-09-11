import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// أدوات محاكاة اختبار الـ Digital SAT الرسمية
/// 1. ورقة القوانين الرياضية الرسمية (Reference Sheet)
/// 2. الحاسبة العلمية المدمجة (Exam Calculator)
class SatExamToolsSheet {
  SatExamToolsSheet._();

  /// عرض ورقة القوانين الرياضية الرسمية للـ Digital SAT
  static void showReferenceSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusLarge),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      ctx.l10n.satReferenceSheetTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s12),
              Expanded(
                child: ListView(
                  children: [
                    _buildFormulaGroup(
                      title: ctx.l10n.areaCircumferenceSection,
                      formulas: [
                        {'name': ctx.l10n.circleArea, 'math': 'A = π r²'},
                        {'name': ctx.l10n.circleCircumference, 'math': 'C = 2 π r'},
                        {'name': ctx.l10n.rectangleArea, 'math': 'A = l × w'},
                        {'name': ctx.l10n.triangleArea, 'math': 'A = ½ b × h'},
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    _buildFormulaGroup(
                      title: ctx.l10n.volumesSection,
                      formulas: [
                        {'name': ctx.l10n.rectangularPrismVolume, 'math': 'V = l × w × h'},
                        {'name': ctx.l10n.cylinderVolume, 'math': 'V = π r² h'},
                        {'name': ctx.l10n.sphereVolume, 'math': 'V = (4/3) π r³'},
                        {'name': ctx.l10n.coneVolume, 'math': 'V = (1/3) π r² h'},
                        {'name': ctx.l10n.pyramidVolume, 'math': 'V = (1/3) l × w × h'},
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    _buildFormulaGroup(
                      title: ctx.l10n.rightTrianglesSection,
                      formulas: [
                        {'name': ctx.l10n.pythagoreanTheorem, 'math': 'a² + b² = c²'},
                        {'name': ctx.l10n.triangle306090, 'math': ctx.l10n.triangle306090Sides},
                        {'name': ctx.l10n.triangle454590, 'math': ctx.l10n.triangle454590Sides},
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s16),
                    _buildFormulaGroup(
                      title: ctx.l10n.degreesRadiansSection,
                      formulas: [
                        {'name': ctx.l10n.triangleAnglesSum, 'math': '180°'},
                        {'name': ctx.l10n.fullCircleRadians, 'math': '2π radians = 360°'},
                        {'name': ctx.l10n.degreesToRadians, 'math': 'Radians = Degrees × (π / 180°)'},
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildFormulaGroup({
    required String title,
    required List<Map<String, String>> formulas,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          ...formulas.map((f) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      f['name']!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      f['math']!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// عرض الحاسبة العلمية المدمجة
  static void showCalculator(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => const _SatCalculatorDialog(),
    );
  }
}

class _SatCalculatorDialog extends StatefulWidget {
  const _SatCalculatorDialog();

  @override
  State<_SatCalculatorDialog> createState() => _SatCalculatorDialogState();
}

class _SatCalculatorDialogState extends State<_SatCalculatorDialog> {
  String _display = '0';
  String _expression = '';

  void _onKeyPress(String key) {
    setState(() {
      if (key == 'C') {
        _display = '0';
        _expression = '';
      } else if (key == '⌫') {
        if (_display.length > 1) {
          _display = _display.substring(0, _display.length - 1);
        } else {
          _display = '0';
        }
      } else if (key == '=') {
        _calculateResult();
      } else if (key == '√') {
        try {
          final val = double.parse(_display);
          if (val >= 0) {
            _display = math.sqrt(val).toStringAsFixed(4);
            _cleanDecimalDisplay();
          } else {
            _display = 'Error';
          }
        } catch (_) {
          _display = 'Error';
        }
      } else if (key == 'x²') {
        try {
          final val = double.parse(_display);
          _display = (val * val).toStringAsFixed(4);
          _cleanDecimalDisplay();
        } catch (_) {
          _display = 'Error';
        }
      } else {
        if (_display == '0' || _display == 'Error') {
          _display = key;
        } else {
          _display += key;
        }
      }
    });
  }

  void _cleanDecimalDisplay() {
    if (_display.contains('.')) {
      _display = _display.replaceAll(RegExp(r'0*$'), '');
      if (_display.endsWith('.')) {
        _display = _display.substring(0, _display.length - 1);
      }
    }
  }

  void _calculateResult() {
    // Basic safe arithmetic evaluator
    try {
      String exp = _display.replaceAll('×', '*').replaceAll('÷', '/');
      // Simple parser for standard expressions
      final result = _evaluateSimpleExpression(exp);
      _expression = _display;
      _display = result.toStringAsFixed(4);
      _cleanDecimalDisplay();
    } catch (_) {
      _display = 'Error';
    }
  }

  double _evaluateSimpleExpression(String expr) {
    // Simple basic math evaluator
    if (expr.contains('+')) {
      final parts = expr.split('+');
      return parts.map((p) => double.tryParse(p.trim()) ?? 0.0).reduce((a, b) => a + b);
    } else if (expr.contains('-') && !expr.startsWith('-')) {
      final parts = expr.split('-');
      return parts.map((p) => double.tryParse(p.trim()) ?? 0.0).reduce((a, b) => a - b);
    } else if (expr.contains('*')) {
      final parts = expr.split('*');
      return parts.map((p) => double.tryParse(p.trim()) ?? 1.0).reduce((a, b) => a * b);
    } else if (expr.contains('/')) {
      final parts = expr.split('/');
      final first = double.tryParse(parts[0].trim()) ?? 0.0;
      final second = double.tryParse(parts[1].trim()) ?? 1.0;
      return second != 0 ? first / second : double.nan;
    }
    return double.tryParse(expr) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final keys = [
      ['C', '⌫', '√', 'x²'],
      ['7', '8', '9', '÷'],
      ['4', '5', '6', '×'],
      ['1', '2', '3', '-'],
      ['0', '.', '=', '+'],
    ];

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Bar
            Row(
              children: [
                const Icon(Icons.calculate_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    context.l10n.satCalculatorTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),

            // Display Screen
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_expression.isNotEmpty)
                    Text(
                      _expression,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  Text(
                    _display,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Keypad
            ...keys.map((row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: row.map((key) {
                    final isOp = ['÷', '×', '-', '+', '='].contains(key);
                    final isSpecial = ['C', '⌫', '√', 'x²'].contains(key);

                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: InkWell(
                          onTap: () => _onKeyPress(key),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: isOp
                                  ? AppColors.primary
                                  : isSpecial
                                      ? AppColors.surfaceVariant
                                      : AppColors.surface,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isOp ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                key,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isOp ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
