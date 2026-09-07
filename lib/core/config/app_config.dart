import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static const String appName = 'Edu SaaS';

  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://vfjialpvgorpslqjdqwq.supabase.co',
      );

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'placeholder-anon-key',
      );
}
