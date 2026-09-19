import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/utils/youtube_url_parser.dart';

void main() {
  group('YouTubeUrlParser Unit Tests', () {
    const validId = 'dQw4w9WgXcQ';

    test('extracts ID from standard watch URL', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://www.youtube.com/watch?v=$validId'),
        equals(validId),
      );
      expect(
        YouTubeUrlParser.extractVideoId('http://youtube.com/watch?v=$validId&feature=shared'),
        equals(validId),
      );
    });

    test('extracts ID from youtu.be short URL', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://youtu.be/$validId'),
        equals(validId),
      );
      expect(
        YouTubeUrlParser.extractVideoId('https://youtu.be/$validId?t=120'),
        equals(validId),
      );
    });

    test('extracts ID from embed URL', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://www.youtube.com/embed/$validId'),
        equals(validId),
      );
    });

    test('extracts ID from live stream URL', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://www.youtube.com/live/$validId?feature=share'),
        equals(validId),
      );
    });

    test('extracts ID from mobile URL', () {
      expect(
        YouTubeUrlParser.extractVideoId('https://m.youtube.com/watch?v=$validId'),
        equals(validId),
      );
    });

    test('extracts ID from direct 11-char ID', () {
      expect(
        YouTubeUrlParser.extractVideoId(validId),
        equals(validId),
      );
    });

    test('returns null for invalid URLs or empty strings', () {
      expect(YouTubeUrlParser.extractVideoId(''), isNull);
      expect(YouTubeUrlParser.extractVideoId(null), isNull);
      expect(YouTubeUrlParser.extractVideoId('https://vimeo.com/12345678'), isNull);
      expect(YouTubeUrlParser.extractVideoId('not a url'), isNull);
      expect(YouTubeUrlParser.extractVideoId('https://google.com'), isNull);
    });

    test('generates expected thumbnail and embed URLs', () {
      expect(
        YouTubeUrlParser.getThumbnailUrl(validId),
        equals('https://img.youtube.com/vi/$validId/hqdefault.jpg'),
      );
      expect(
        YouTubeUrlParser.getEmbedUrl(validId),
        contains('youtube-nocookie.com/embed/$validId'),
      );
      expect(
        YouTubeUrlParser.getEmbedUrl(validId, startSeconds: 45),
        contains('&start=45'),
      );
    });
  });
}
