import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';

class QuickBubbleSheetResult {
  final int questionCount;
  final int optionsCount;
  final int points;

  const QuickBubbleSheetResult({
    required this.questionCount,
    required this.optionsCount,
    required this.points,
  });
}

class QuickBubbleSheetDialog extends StatefulWidget {
  final int initialPoints;
  final bool hasExistingQuestions;

  const QuickBubbleSheetDialog({
    super.key,
    required this.initialPoints,
    required this.hasExistingQuestions,
  });

  @override
  State<QuickBubbleSheetDialog> createState() => _QuickBubbleSheetDialogState();
}

class _QuickBubbleSheetDialogState extends State<QuickBubbleSheetDialog> {
  late int _questionCount;
  int _optionsCount = 4;
  late int _points;
  late final TextEditingController _countController;
  late final TextEditingController _pointsController;

  @override
  void initState() {
    super.initState();
    _questionCount = 20;
    _points = widget.initialPoints;
    _countController = TextEditingController(text: '20');
    _pointsController = TextEditingController(text: widget.initialPoints.toString());
  }

  @override
  void dispose() {
    _countController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: const Icon(
              Icons.flash_on_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Text(
              context.l10n.quickBubbleSheetGenerator,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.quickBubbleSheetPrompt,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              context.l10n.quickPresets,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s6,
              children: [10, 20, 30, 40, 50].map((preset) {
                final isSelected = _questionCount == preset;
                return ChoiceChip(
                  label: Text('$preset ${context.l10n.numberOfQuestions}'),
                  selected: isSelected,
                  onSelected: (sel) {
                    if (sel) {
                      setState(() {
                        _questionCount = preset;
                        _countController.text = preset.toString();
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.s16),
            AppTextField(
              controller: _countController,
              labelText: context.l10n.numberOfQuestions,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.format_list_numbered_rounded),
              onChanged: (val) {
                final parsed = int.tryParse(val.trim());
                if (parsed != null && parsed > 0 && parsed <= 200) {
                  setState(() => _questionCount = parsed);
                }
              },
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _pointsController,
                    labelText: context.l10n.defaultQuestionPointsLabel,
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.stars_outlined),
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim());
                      if (parsed != null && parsed > 0) {
                        setState(() => _points = parsed);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _optionsCount,
                    decoration: InputDecoration(
                      labelText: context.l10n.numberOfOptionsPerQuestion,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 2, child: Text('2 (A, B)')),
                      DropdownMenuItem(value: 3, child: Text('3 (A, B, C)')),
                      DropdownMenuItem(value: 4, child: Text('4 (A, B, C, D)')),
                      DropdownMenuItem(value: 5, child: Text('5 (A, B, C, D, E)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _optionsCount = val);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            if (widget.hasExistingQuestions)
              Container(
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        context.l10n.overwriteQuestionsWarning,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop(
              QuickBubbleSheetResult(
                questionCount: _questionCount,
                optionsCount: _optionsCount,
                points: _points,
              ),
            );
          },
          icon: const Icon(Icons.flash_on_rounded, size: 18),
          label: Text(context.l10n.generateQuestions),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
