import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'Edu SaaS';

  static String get supabaseUrl {
    if (dotenv.isInitialized) {
      final val = dotenv.env['SUPABASE_URL'];
      if (val != null && val.isNotEmpty) return val;
    }
    return const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://vfjialpvgorpslqjdqwq.supabase.co',
    );
  }

  static String get supabaseAnonKey {
    if (dotenv.isInitialized) {
      final val = dotenv.env['SUPABASE_ANON_KEY'];
      if (val != null && val.isNotEmpty) return val;
    }
    return const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'placeholder-anon-key',
    );
  }
}
