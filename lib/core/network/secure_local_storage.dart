import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/secure_storage_helper.dart';

/// Secure LocalStorage adapter for Supabase Flutter.
/// Ensures session tokens are persisted inside hardware-backed keystore/keychain
/// via FlutterSecureStorage (AES-256) rather than plain unencrypted SharedPreferences.
/// Complies with OWASP MASVS and Enterprise guidelines in GEMINI.md.
class SecureLocalStorage extends LocalStorage {
  const SecureLocalStorage();

  static const String _sessionKey = 'supabase_auth_session_token';

  @override
  Future<void> initialize() async {
    // Storage initialization handled by hardware wrapper
  }

  @override
  Future<String?> accessToken() async {
    return await SecureStorageHelper.read(key: _sessionKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    final token = await accessToken();
    return token != null && token.isNotEmpty;
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await SecureStorageHelper.write(
      key: _sessionKey,
      value: persistSessionString,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    await SecureStorageHelper.delete(key: _sessionKey);
  }
}
