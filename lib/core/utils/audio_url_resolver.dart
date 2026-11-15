import '../config/app_config.dart';

/// Resolves an audio relative path or full URL to a playable CDN URL.
/// Seamlessly supports both Supabase Storage and Cloudflare R2 without changing database records.
class AudioUrlResolver {
  AudioUrlResolver._();

  static String? resolve(String? audioUrl) {
    if (audioUrl == null || audioUrl.trim().isEmpty) return null;
    final trimmed = audioUrl.trim();

    // Already a full HTTP/HTTPS URL, blob URL, or data URI
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('blob:') ||
        trimmed.startsWith('data:')) {
      return trimmed;
    }

    final provider = AppConfig.audioStorageProvider.toLowerCase();
    final cleanPath = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;

    if (provider == 'r2') {
      final r2Base = AppConfig.r2PublicUrl.trim();
      if (r2Base.isNotEmpty) {
        final base = r2Base.endsWith('/')
            ? r2Base.substring(0, r2Base.length - 1)
            : r2Base;
        return '$base/$cleanPath';
      }
    }

    // Default: Supabase Storage 'exam-audio' bucket
    final supabaseUrl = AppConfig.supabaseUrl.trim();
    final baseUrl = supabaseUrl.endsWith('/')
        ? supabaseUrl.substring(0, supabaseUrl.length - 1)
        : supabaseUrl;

    if (cleanPath.startsWith('exam-audio/')) {
      return '$baseUrl/storage/v1/object/public/$cleanPath';
    }

    return '$baseUrl/storage/v1/object/public/exam-audio/$cleanPath';
  }
}
