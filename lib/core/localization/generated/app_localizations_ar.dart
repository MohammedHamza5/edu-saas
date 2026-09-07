// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'منصة التعليم الذكية';

  @override
  String get loading => 'جارٍ التحميل...';

  @override
  String get errorOccurred => 'حدث خطأ غير متوقع';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get emptyData => 'لا توجد بيانات حالياً';

  @override
  String get loginTitle => 'تسجيل الدخول';

  @override
  String get emailLabel => 'البريد الإلكتروني';

  @override
  String get passwordLabel => 'كلمة المرور';

  @override
  String get loginButton => 'دخول';

  @override
  String get tenantSuspendedMessage =>
      'تم تعليق هذا الحساب المؤسسي. يرجى التواصل مع الإدارة.';

  @override
  String get roleTeacher => 'معلم';

  @override
  String get roleStudent => 'طالب';

  @override
  String get roleParent => 'ولي أمر';
}
