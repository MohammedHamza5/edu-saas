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
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZmamlhbHB2Z29ycHNscWpkcXdxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg3MjI3ODQsImV4cCI6MjEwNDI5ODc4NH0.PIJ1KgTGHZBDudhNLhXU4CYYq1cf0cc4XhMSfFGauKY',
    );
  }



  static String get defaultVideoProvider {
    if (dotenv.isInitialized) {
      final val = dotenv.env['DEFAULT_VIDEO_PROVIDER'];
      if (val != null && val.isNotEmpty) return val;
    }
    return const String.fromEnvironment(
      'DEFAULT_VIDEO_PROVIDER',
      defaultValue: 'youtube',
    );
  }

  /// Whether YouTube provider is available (provider is 'youtube' or 'both').
  static bool get isYouTubeEnabled =>
      defaultVideoProvider == 'youtube' || defaultVideoProvider == 'both';

  /// Whether Bunny Stream provider is available (provider is 'bunny' or 'both').
  static bool get isBunnyEnabled =>
      defaultVideoProvider == 'bunny' || defaultVideoProvider == 'both';

  /// Whether both providers are shown for teacher selection.
  static bool get showBothProviders => defaultVideoProvider == 'both';
}
