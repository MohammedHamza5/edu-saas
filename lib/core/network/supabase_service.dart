// ignore_for_file: deprecated_member_use
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';
import '../utils/secure_storage_helper.dart';
import 'secure_local_storage.dart';

/// Central Supabase service wrapper
/// Enforces PKCE auth flow, sound client access, and proactive session preservation.
class SupabaseService {
  SupabaseService._();

  static const String _roleStorageKey = 'cached_user_role';
  static const String _statusStorageKey = 'cached_user_status';

  static Timer? _sessionRefreshTimer;
  static _AppLifecycleSessionObserver? _lifecycleObserver;

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
    AppLogger.d(
      'SupabaseService',
      'Config',
      data: {
        'url': AppConfig.supabaseUrl,
        'anonKeyPrefix': AppConfig.supabaseAnonKey.isNotEmpty
            ? '${AppConfig.supabaseAnonKey.substring(0, 10)}...'
            : 'MISSING',
      },
    );

    // Restore cached role and status from hardware secure storage immediately
    try {
      _cachedRole = await SecureStorageHelper.read(key: _roleStorageKey);
    } catch (_) {}
    try {
      _cachedStatus = await SecureStorageHelper.read(key: _statusStorageKey);
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

    // Proactive background session keeper: keeps teacher and student sessions alive
    // so the platform never expires while the user is actively working.
    _startSessionKeeper();

    // Attach lifecycle observer to immediately refresh expired sessions when tab restores
    if (_lifecycleObserver == null) {
      _lifecycleObserver = _AppLifecycleSessionObserver();
      WidgetsBinding.instance.addObserver(_lifecycleObserver!);
    }

    // Listen to auth state changes and log them
    Supabase.instance.client.auth.onAuthStateChange.listen(
      (data) {
        final event = data.event;
        final session = data.session;
        AppLogger.i(
          'SupabaseService',
          'Auth state changed: ${event.name}',
          data: {
            'userId': session?.user.id ?? 'null',
            'email': session?.user.email ?? 'null',
            'expiresAt': session?.expiresAt != null
                ? DateTime.fromMillisecondsSinceEpoch(
                    session!.expiresAt! * 1000,
                  ).toIso8601String()
                : 'null',
          },
        );
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

  /// Proactively refreshes the session if it is expired or will expire within 10 minutes.
  /// Guarantees that active working sessions (e.g. creating exams) never encounter 403 RLS errors.
  static Future<void> ensureFreshSession() async {
    if (!isInitialized) return;
    final session = client.auth.currentSession;
    if (session == null) return;

    final expiresAt = session.expiresAt;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // If expired or expiring within 600 seconds (10 minutes)
    if (expiresAt == null || (expiresAt - now) < 600) {
      try {
        AppLogger.i('SupabaseService', '🔄 Proactively refreshing auth session token...');
        await client.auth.refreshSession();
        AppLogger.s('SupabaseService', '✅ Auth session token successfully refreshed');
      } catch (e) {
        AppLogger.w('SupabaseService', '⚠️ Could not refresh session: $e');
      }
    }
  }

  static void _startSessionKeeper() {
    _sessionRefreshTimer?.cancel();
    // Check every 5 minutes while app is running
    _sessionRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await ensureFreshSession();
    });
  }

  static User? get currentUser =>
      isInitialized ? client.auth.currentUser : null;
  /// Visible for testing only: override isAuthenticated in unit tests
  static bool? debugIsAuthenticated;

  static bool get isAuthenticated =>
      debugIsAuthenticated ?? (currentUser != null);
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

  static String? _cachedStatus;
  static set currentStatus(String? status) {
    _cachedStatus = status;
    if (status != null) {
      SecureStorageHelper.write(key: _statusStorageKey, value: status);
    } else {
      SecureStorageHelper.delete(key: _statusStorageKey);
    }
  }

  static String? get cachedRole => _cachedRole;
  static String? get currentUserRole =>
      _cachedRole ?? (currentUser?.userMetadata?['role'] as String?);
  static String? get cachedStatus => _cachedStatus;
  static String? get currentUserStatus =>
      _cachedStatus ?? (currentUser?.userMetadata?['status'] as String?);
  static String? get currentTenantId =>
      (currentUser?.userMetadata?['tenant_id'] as String?) ??
      (currentUser?.appMetadata['tenant_id'] as String?);
}

/// Watches app lifecycle state and proactively refreshes auth sessions
/// when user switches back to the tab from background/sleep.
class _AppLifecycleSessionObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SupabaseService.ensureFreshSession();
    }
  }
}

