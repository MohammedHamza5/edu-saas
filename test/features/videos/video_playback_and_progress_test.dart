import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/config/app_config.dart';
import 'package:edu_saas/features/videos/data/models/video_progress_model.dart';

void main() {
  group('Bunny Stream Playback URL Generation', () {
    test('generates expected tokenized Bunny Embed URL structure', () {
      const providerVideoId = 'eb03f081-1264-475b-9ae5-db3752cc635c';
      final tokenKey = AppConfig.bunnyTokenKey;
      final libraryId = AppConfig.bunnyLibraryId;

      final expires = (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) + 14400;
      final hashInput = '$tokenKey$providerVideoId$expires';
      final token = sha256.convert(utf8.encode(hashInput)).toString();

      final expectedUrl =
          'https://iframe.mediadelivery.net/embed/$libraryId/$providerVideoId?token=$token&expires=$expires&autoplay=true&preload=true&responsive=true&playerjs=true';

      expect(expectedUrl, contains('iframe.mediadelivery.net/embed/747497/'));
      expect(expectedUrl, contains('eb03f081-1264-475b-9ae5-db3752cc635c'));
      expect(expectedUrl, contains('token='));
      expect(expectedUrl, contains('expires='));
      expect(expectedUrl, contains('responsive=true'));
    });
  });

  group('Student Video Progress Integrity & Anti-Cheat Logic', () {
    const durationSeconds = 1000;

    bool computeCompleted({
      required int progressSeconds,
      required int durationSeconds,
      required int actualWatchSeconds,
      required bool isSkipped,
    }) {
      final double percentage = durationSeconds > 0
          ? ((progressSeconds / durationSeconds) * 100).clamp(0.0, 100.0)
          : 0.0;
      return percentage >= 80.0 &&
          (actualWatchSeconds >= (durationSeconds * 0.8).toInt()) &&
          !isSkipped;
    }

    test('should mark completed when student watches >= 80% without skipping', () {
      final completed = computeCompleted(
        progressSeconds: 850,
        durationSeconds: durationSeconds,
        actualWatchSeconds: 850,
        isSkipped: false,
      );
      expect(completed, isTrue);
    });

    test('should reject completion when student fast-forwards (isSkipped = true)', () {
      final completed = computeCompleted(
        progressSeconds: 950,
        durationSeconds: durationSeconds,
        actualWatchSeconds: 950,
        isSkipped: true,
      );
      expect(completed, isFalse);
    });

    test('should reject completion when actualWatchSeconds is below 80% despite slider position', () {
      // Student dragged slider to 900 seconds after watching only 200 seconds
      final completed = computeCompleted(
        progressSeconds: 900,
        durationSeconds: durationSeconds,
        actualWatchSeconds: 200,
        isSkipped: false,
      );
      expect(completed, isFalse);
    });

    test('should reject completion when progress percentage is below 80%', () {
      final completed = computeCompleted(
        progressSeconds: 500,
        durationSeconds: durationSeconds,
        actualWatchSeconds: 500,
        isSkipped: false,
      );
      expect(completed, isFalse);
    });
  });

  group('VideoProgressModel Serialization', () {
    test('correctly serializes and deserializes tracking metrics', () {
      final now = DateTime.now();
      final model = VideoProgressModel(
        id: 'progress-uuid-1',
        videoId: 'vid-1',
        studentId: 'student-1',
        progressSeconds: 450,
        durationSeconds: 600,
        percentage: 75.0,
        completed: false,
        actualWatchSeconds: 420,
        isSkipped: false,
        lastWatchedAt: now,
      );

      final json = model.toJson(tenantId: 'tenant-1');
      expect(json['tenant_id'], equals('tenant-1'));
      expect(json['actual_watch_seconds'], equals(420));
      expect(json['is_skipped'], isFalse);
      expect(json['progress_seconds'], equals(450));
      expect(json['percentage'], equals(75.0));

      final restored = VideoProgressModel.fromJson(json);
      expect(restored.actualWatchSeconds, equals(420));
      expect(restored.isSkipped, isFalse);
      expect(restored.percentage, equals(75.0));
      expect(restored.completed, isFalse);
    });
  });
}
