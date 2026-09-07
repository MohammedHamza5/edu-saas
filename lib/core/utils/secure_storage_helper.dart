import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Enterprise Hardware-backed Secure Storage Wrapper
/// Conforms to OWASP MASVS for credential protection.
class SecureStorageHelper {
  SecureStorageHelper._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static Future<void> write({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  static Future<String?> read({required String key}) async {
    return await _storage.read(key: key);
  }

  static Future<void> delete({required String key}) async {
    await _storage.delete(key: key);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
