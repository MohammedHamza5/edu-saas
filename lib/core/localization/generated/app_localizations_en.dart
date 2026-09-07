// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Education Platform';

  @override
  String get loading => 'Loading...';

  @override
  String get errorOccurred => 'An unexpected error occurred';

  @override
  String get retry => 'Retry';

  @override
  String get emptyData => 'No data available';

  @override
  String get loginTitle => 'Sign In';

  @override
  String get emailLabel => 'Email Address';

  @override
  String get passwordLabel => 'Password';

  @override
  String get loginButton => 'Sign In';

  @override
  String get tenantSuspendedMessage =>
      'This institutional account is suspended. Please contact administration.';

  @override
  String get roleTeacher => 'Teacher';

  @override
  String get roleStudent => 'Student';

  @override
  String get roleParent => 'Parent';
}
