import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'settings_section_card.dart';

/// Section for configuring the Platform Language Preference
/// (Arabic RTL vs English LTR).
class LanguageSettingsSection extends StatelessWidget {
  const LanguageSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final currentLocale = Localizations.localeOf(context);

    return SettingsSectionCard(
      title: l10n.settingsLanguageSection,
      icon: Icons.translate_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsLanguageDesc,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Expanded(
                child: _buildLanguageOptionCard(
                  context,
                  langCode: 'ar',
                  langName: l10n.settingsLangArabic,
                  subtitle: 'العربية (من اليمين لليسار)',
                  isSelected: currentLocale.languageCode == 'ar',
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: _buildLanguageOptionCard(
                  context,
                  langCode: 'en',
                  langName: l10n.settingsLangEnglish,
                  subtitle: 'English (Left-to-Right)',
                  isSelected: currentLocale.languageCode == 'en',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageOptionCard(
    BuildContext context, {
    required String langCode,
    required String langName,
    required String subtitle,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        context.read<LocaleCubit>().setLocale(Locale(langCode));
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderDark,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    langName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
