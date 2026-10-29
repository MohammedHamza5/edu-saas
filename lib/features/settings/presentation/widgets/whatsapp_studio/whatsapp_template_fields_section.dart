import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import 'whatsapp_template_tags_bar.dart';

class WhatsAppTemplateFieldsSection extends StatelessWidget {
  final TextEditingController headerController;
  final TextEditingController bodyController;
  final TextEditingController footerController;
  final VoidCallback onChanged;
  final void Function(String tag) onTagSelected;

  const WhatsAppTemplateFieldsSection({
    super.key,
    required this.headerController,
    required this.bodyController,
    required this.footerController,
    required this.onChanged,
    required this.onTagSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tags Helper Bar
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.smart_button_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        l10n.whatsappStudioTagsLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),
                WhatsAppTemplateTagsBar(
                  onTagSelected: onTagSelected,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s16),

          // 1. Header Field
          _buildFieldCard(
            label: l10n.whatsappStudioHeaderLabel,
            controller: headerController,
            maxLines: 3,
            hint: 'أهلاً بحضرتك يا فندم 🌸\nحبينا نطمن حضرتك على نتيجة اختبار نجلك الطالب/ *{student_name}* ({group_name}):',
            icon: Icons.title_rounded,
          ),
          const SizedBox(height: AppSpacing.s16),

          // 2. Body Field
          _buildFieldCard(
            label: l10n.whatsappStudioBodyLabel,
            controller: bodyController,
            maxLines: 4,
            hint: '📝 *الاختبار:* {exam_title}\n🎯 *الدرجة:* {score} من {max_score} ({percentage}%)\n\n{evaluation_text}',
            icon: Icons.notes_rounded,
          ),
          const SizedBox(height: AppSpacing.s16),

          // 3. Footer Field
          _buildFieldCard(
            label: l10n.whatsappStudioFooterLabel,
            controller: footerController,
            maxLines: 3,
            hint: 'نسأل الله له دوام التوفيق والتميز، ومع حضرتك في أي وقت لأي استفسار 🌸\n*{teacher_name}*',
            icon: Icons.edit_note_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildFieldCard({
    required String label,
    required TextEditingController controller,
    required int maxLines,
    required String hint,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.textPrimary),
              const SizedBox(width: AppSpacing.s8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            onChanged: (_) => onChanged(),
            style: const TextStyle(fontSize: 13, height: 1.4),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.s12),
              filled: true,
              fillColor: AppColors.surfaceVariant.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
