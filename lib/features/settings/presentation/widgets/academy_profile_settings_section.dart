import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'settings_section_card.dart';

/// Section for configuring the Academy and Platform Profile settings
/// (Brand name, subject, tagline, phone, and support email).
class AcademyProfileSettingsSection extends StatelessWidget {
  final TextEditingController academyNameController;
  final TextEditingController subjectController;
  final TextEditingController taglineController;
  final TextEditingController supportPhoneController;
  final TextEditingController supportEmailController;
  final bool isSaving;
  final VoidCallback onSave;

  const AcademyProfileSettingsSection({
    super.key,
    required this.academyNameController,
    required this.subjectController,
    required this.taglineController,
    required this.supportPhoneController,
    required this.supportEmailController,
    required this.isSaving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return SettingsSectionCard(
      title: l10n.settingsAcademySection,
      icon: Icons.school_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: l10n.settingsAcademyNameLabel,
            controller: academyNameController,
            prefixIcon: const Icon(Icons.business_rounded, size: 20),
          ),
          const SizedBox(height: AppSpacing.s16),
          AppTextField(
            label: l10n.settingsSubjectLabel,
            controller: subjectController,
            prefixIcon: const Icon(Icons.menu_book_rounded, size: 20),
          ),
          const SizedBox(height: AppSpacing.s16),
          AppTextField(
            label: l10n.settingsTaglineLabel,
            controller: taglineController,
            prefixIcon: const Icon(Icons.stars_rounded, size: 20),
          ),
          const SizedBox(height: AppSpacing.s16),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: l10n.settingsSupportPhoneLabel,
                  controller: supportPhoneController,
                  prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: AppTextField(
                  label: l10n.settingsSupportEmailLabel,
                  controller: supportEmailController,
                  prefixIcon: const Icon(Icons.email_rounded, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton(
              text: isAr ? 'حفظ التعديلات' : 'Save Changes',
              icon: Icons.check_circle_outline_rounded,
              isLoading: isSaving,
              onPressed: onSave,
            ),
          ),
        ],
      ),
    );
  }
}
