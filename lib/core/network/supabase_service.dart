// ignore_for_file: deprecated_member_use
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';
import '../utils/secure_storage_helper.dart';
import 'secure_local_storage.dart';

/// Central Supabase service wrapper
/// Enforces PKCE auth flow and sound client access
class SupabaseService {
  SupabaseService._();

  static const String _roleStorageKey = 'cached_user_role';

  static bool get isInitialized {
    try {
      Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    AppLogger.i('SupabaseService', 'Initializing Supabase...');
    AppLogger.d('SupabaseService', 'Config', data: {
      'url': AppConfig.supabaseUrl,
      'anonKeyPrefix': AppConfig.supabaseAnonKey.isNotEmpty
          ? '${AppConfig.supabaseAnonKey.substring(0, 10)}...'
          : 'MISSING',
    });

    // Restore cached role from hardware secure storage immediately
    try {
      _cachedRole = await SecureStorageHelper.read(key: _roleStorageKey);
    } catch (_) {}

    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        localStorage: SecureLocalStorage(),
      ),
    );

    AppLogger.s('SupabaseService', 'Supabase client ready');

    // Listen to auth state changes and log them
    Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        final session = data.session;
        AppLogger.i('SupabaseService', 'Auth state changed: ${event.name}', data: {
          'userId': session?.user.id ?? 'null',
          'email': session?.user.email ?? 'null',
          'expiresAt': session?.expiresAt != null
              ? DateTime.fromMillisecondsSinceEpoch(session!.expiresAt! * 1000).toIso8601String()
              : 'null',
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        AppLogger.e(
          'SupabaseService',
          'Auth state stream error',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  static User? get currentUser => isInitialized ? client.auth.currentUser : null;
  static bool get isAuthenticated => currentUser != null;
  static String? get currentUserId => currentUser?.id;
  static String? _cachedRole;
  static set currentRole(String? role) {
    _cachedRole = role;
    if (role != null) {
      SecureStorageHelper.write(key: _roleStorageKey, value: role);
    } else {
      SecureStorageHelper.delete(key: _roleStorageKey);
    }
  }
  static String? get cachedRole => _cachedRole;
  static String? get currentUserRole =>
      _cachedRole ?? (currentUser?.userMetadata?['role'] as String?);
  static String? get currentTenantId =>
      (currentUser?.userMetadata?['tenant_id'] as String?) ??
      (currentUser?.appMetadata['tenant_id'] as String?);
}
