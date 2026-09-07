// ignore_for_file: deprecated_member_use
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';

/// Central Supabase service wrapper
/// Enforces PKCE auth flow and sound client access
class SupabaseService {
  SupabaseService._();

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

  static User? get currentUser => client.auth.currentUser;
  static bool get isAuthenticated => currentUser != null;
  static String? get currentUserId => currentUser?.id;
}
