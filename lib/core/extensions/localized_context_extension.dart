import 'package:flutter/widgets.dart';
import '../localization/generated/app_localizations.dart';

/// Extension providing easy, type-safe access to [AppLocalizations].
extension LocalizedContext on BuildContext {
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(const Locale('ar'));
}
