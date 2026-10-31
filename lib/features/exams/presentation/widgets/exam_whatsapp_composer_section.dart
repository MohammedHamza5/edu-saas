import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ExamWhatsAppComposerSection extends StatelessWidget {
  final List<String> presetNotes;
  final String? selectedPreset;
  final TextEditingController customNoteController;
  final String messageText;
  final ValueChanged<String?> onPresetSelected;
  final VoidCallback onCustomNoteChanged;
  final VoidCallback onCopied;

  const ExamWhatsAppComposerSection({
    super.key,
    required this.presetNotes,
    required this.selectedPreset,
    required this.customNoteController,
    required this.messageText,
    required this.onPresetSelected,
    required this.onCustomNoteChanged,
    required this.onCopied,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Quick Feedback Presets ─────────────────────────────
        Row(
          children: [
            const Icon(
              Icons.bolt_rounded,
              size: 16,
              color: Color(0xFFF59E0B),
            ),
            const SizedBox(width: 4),
            Text(
              l10n.quickTeacherPresetsTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: presetNotes.map((preset) {
            final isSelected = selectedPreset == preset &&
                customNoteController.text.trim().isEmpty;
            return ChoiceChip(
              label: Text(
                preset,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textPrimary,
                ),
              ),
              selected: isSelected,
              selectedColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.border,
                ),
              ),
              onSelected: (selected) {
                onPresetSelected(selected ? preset : null);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.s12),

        // ── Custom Note Field ──────────────────────────────────
        TextField(
          controller: customNoteController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: l10n.customTeacherNoteHint,
            contentPadding: const EdgeInsets.all(AppSpacing.s12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
          onChanged: (_) => onCustomNoteChanged(),
        ),
        const SizedBox(height: AppSpacing.s16),

        // ── Live WhatsApp Preview Box ──────────────────────────
        Row(
          children: [
            const Icon(
              Icons.visibility_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              l10n.liveWhatsAppPreviewTitle,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              tooltip: l10n.copyMessageAction,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: messageText));
                onCopied();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.messageCopiedToast),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4), // Gentle WhatsApp tint
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: const Color(0xFF22C55E).withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            messageText,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xFF14532D),
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
