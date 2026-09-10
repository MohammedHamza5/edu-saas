import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/app_logger.dart';

/// Cubit managing application Locale.
/// Defaults to English ('en') as requested.
/// Persists the selected language preference across app restarts.
class LocaleCubit extends Cubit<Locale> {
  static const String _storageKey = 'selected_app_locale';
  final FlutterSecureStorage _storage;

  LocaleCubit({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage(),
        super(const Locale('en')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final savedCode = await _storage.read(key: _storageKey);
      if (savedCode != null && (savedCode == 'ar' || savedCode == 'en')) {
        emit(Locale(savedCode));
        AppLogger.i('LocaleCubit', 'Loaded saved locale: $savedCode');
      } else {
        AppLogger.i('LocaleCubit', 'No saved locale found. Defaulting to: en');
      }
    } catch (e) {
      AppLogger.w('LocaleCubit', 'Failed to read locale from storage', data: e);
    }
  }

  Future<void> setLocale(Locale newLocale) async {
    if (newLocale.languageCode != 'en' && newLocale.languageCode != 'ar') return;
    if (state == newLocale) return;

    emit(newLocale);
    try {
      await _storage.write(key: _storageKey, value: newLocale.languageCode);
      AppLogger.i('LocaleCubit', 'Saved locale changed to: ${newLocale.languageCode}');
    } catch (e) {
      AppLogger.w('LocaleCubit', 'Failed to save locale to storage', data: e);
    }
  }

  Future<void> toggleLocale() async {
    final nextLocale = state.languageCode == 'en' ? const Locale('ar') : const Locale('en');
    await setLocale(nextLocale);
  }

  bool get isArabic => state.languageCode == 'ar';
  bool get isEnglish => state.languageCode == 'en';
}
