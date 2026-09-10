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

  // ---------- Bunny Stream Config ----------
  static String get bunnyLibraryId {
    if (dotenv.isInitialized) {
      final val = dotenv.env['BUNNY_LIBRARY_ID'];
      if (val != null && val.isNotEmpty) return val;
    }
    return const String.fromEnvironment(
      'BUNNY_LIBRARY_ID',
      defaultValue: '747497',
    );
  }

  static String get bunnyApiKey {
    if (dotenv.isInitialized) {
      final val = dotenv.env['BUNNY_API_KEY'];
      if (val != null && val.isNotEmpty) return val;
    }
    return const String.fromEnvironment(
      'BUNNY_API_KEY',
      defaultValue: 'dc757e9a-1045-44f3-8130f6c98385-9a77-48cf',
    );
  }

  static String get bunnyCdnHostname {
    if (dotenv.isInitialized) {
      final val = dotenv.env['BUNNY_CDN_HOSTNAME'];
      if (val != null && val.isNotEmpty) return val;
    }
    return const String.fromEnvironment(
      'BUNNY_CDN_HOSTNAME',
      defaultValue: 'vz-04d07c5c-73c.b-cdn.net',
    );
  }

  static String get bunnyTokenKey {
    if (dotenv.isInitialized) {
      final val = dotenv.env['BUNNY_TOKEN_KEY'];
      if (val != null && val.isNotEmpty) return val;
    }
    return const String.fromEnvironment(
      'BUNNY_TOKEN_KEY',
      defaultValue: 'd472d690-df72-45d1-8233-a5a9a8ccd155',
    );
  }
}
