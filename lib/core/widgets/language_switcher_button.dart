import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../localization/locale_cubit.dart';
import '../theme/app_spacing.dart';

/// Interactive button to toggle or select the active app language (EN / AR).
class LanguageSwitcherButton extends StatelessWidget {
  final bool compact;

  const LanguageSwitcherButton({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    LocaleCubit? cubit;
    try {
      cubit = context.watch<LocaleCubit>();
    } catch (_) {}

    final locale = cubit?.state ?? Localizations.maybeLocaleOf(context) ?? const Locale('ar');
    final isEn = locale.languageCode == 'en';

    if (compact) {
      return IconButton(
        tooltip: isEn ? 'Switch to العربية' : 'Switch to English',
        icon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          ),
          child: Text(
            isEn ? 'AR' : 'EN',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ),
        onPressed: cubit != null ? () => cubit!.toggleLocale() : null,
      );
    }

    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
      ),
      icon: const Icon(Icons.language_rounded, size: 18),
      label: Text(
        isEn ? 'العربية' : 'English',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      onPressed: cubit != null ? () => cubit!.toggleLocale() : null,
    );
  }
}
