/// Utility class to parse and validate YouTube video and live stream URLs.
///
/// Supports all standard formats:
/// - https://www.youtube.com/watch?v=VIDEO_ID
/// - https://youtu.be/VIDEO_ID
/// - https://www.youtube.com/embed/VIDEO_ID
/// - https://www.youtube.com/live/VIDEO_ID
/// - https://m.youtube.com/watch?v=VIDEO_ID
/// - Direct 11-character Video ID
class YouTubeUrlParser {
  YouTubeUrlParser._();

  static final RegExp _regExp = RegExp(
    r'(?:https?:\/\/)?(?:www\.|m\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?|live)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    caseSensitive: false,
  );

  /// Extracts the 11-character YouTube video identifier from a given URL or raw ID.
  ///
  /// Returns `null` if the string cannot be parsed into a valid YouTube video ID.
  static String? extractVideoId(String? input) {
    if (input == null) return null;
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    // Check if the input is directly an 11-character YouTube ID
    if (trimmed.length == 11 && RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(trimmed)) {
      return trimmed;
    }

    final match = _regExp.firstMatch(trimmed);
    return match?.group(1);
  }

  /// Validates whether the given string is a valid YouTube URL or video ID.
  static bool isValid(String? input) => extractVideoId(input) != null;

  /// Returns the high-resolution thumbnail URL for the YouTube video.
  static String getThumbnailUrl(String videoId) {
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  /// Returns the privacy-enhanced embed URL for the YouTube video.
  static String getEmbedUrl(String videoId, {int? startSeconds}) {
    final startParam = (startSeconds != null && startSeconds > 0) ? '&start=$startSeconds' : '';
    return 'https://www.youtube-nocookie.com/embed/$videoId?enablejsapi=1&rel=0&modestbranding=1&iv_load_policy=3&controls=1&playsinline=1$startParam';
  }
}
