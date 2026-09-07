// ignore_for_file: deprecated_member_use
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Central Supabase service wrapper
/// Enforces PKCE auth flow and sound client access
class SupabaseService {
  SupabaseService._();

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
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  static User? get currentUser => isInitialized ? client.auth.currentUser : null;
  static bool get isAuthenticated => currentUser != null;
  static String? get currentUserId => currentUser?.id;
}
