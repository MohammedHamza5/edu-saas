import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/features/videos/domain/entities/video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_progress_entity.dart';
import 'package:edu_saas/features/videos/domain/repositories/videos_repository.dart';
import 'package:edu_saas/features/videos/presentation/cubit/videos_cubit.dart';
import 'package:edu_saas/features/videos/presentation/cubit/videos_state.dart';
import 'package:edu_saas/features/videos/presentation/widgets/video_card.dart';

class MockVideosRepository implements VideosRepository {
  List<VideoEntity> videosResponse = [];
  VideoEntity? singleVideoResponse;
  String playbackUrlResponse = 'https://vz-04d07c5c-73c.b-cdn.net/test-guid/playlist.m3u8?token=mocktoken&expires=9999999999';
  VideoProgressEntity? progressResponse;
  Failure? failureToThrow;

  @override
  Future<Result<List<VideoEntity>>> getVideosForGroup(String groupId) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    return Result.success(videosResponse);
  }

  @override
  Future<Result<VideoEntity>> getVideoById(String videoId) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    return Result.success(singleVideoResponse ?? VideoEntity(
      id: videoId,
      contentId: 'content-1',
      title: 'درس الجبر والهندسة',
      providerVideoId: 'test-guid',
      duration: 1200,
      status: VideoStatus.ready,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<Result<String>> getPlaybackUrl(String videoId) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    return Result.success(playbackUrlResponse);
  }

  @override
  Future<Result<VideoProgressEntity?>> getVideoProgress({
    required String videoId,
    required String studentId,
  }) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    return Result.success(progressResponse);
  }

  @override
  Future<Result<VideoProgressEntity>> updateVideoProgress({
    required String videoId,
    required String studentId,
    required int progressSeconds,
    required int durationSeconds,
    int actualWatchSeconds = 0,
    bool isSkipped = false,
  }) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    final percentage = durationSeconds > 0 ? (progressSeconds / durationSeconds * 100) : 0.0;
    return Result.success(VideoProgressEntity(
      videoId: videoId,
      studentId: studentId,
      progressSeconds: progressSeconds,
      durationSeconds: durationSeconds,
      percentage: percentage,
      completed: percentage >= 90.0,
      lastWatchedAt: DateTime.now(),
    ));
  }

  @override
  Future<Result<VideoEntity>> createAndUploadVideo({
    required String contentId,
    required String title,
    required List<int> videoBytes,
    required String fileName,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    onProgress?.call(100, 100);
    return Result.success(VideoEntity(
      id: 'vid-new-1',
      contentId: contentId,
      title: title,
      providerVideoId: 'guid-new',
      status: VideoStatus.processing,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<Result<void>> deleteVideo(String videoId) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    return const Result.success(null);
  }
}

void main() {
  group('VideoEntity & VideoProgressEntity Unit Tests', () {
    test('formattedDuration handles zero, minutes, and hours', () {
      final v1 = VideoEntity(
        id: '1',
        contentId: 'c1',
        duration: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(v1.formattedDuration, equals('00:00'));

      final v2 = VideoEntity(
        id: '2',
        contentId: 'c2',
        duration: 125, // 2m 5s
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(v2.formattedDuration, equals('02:05'));

      final v3 = VideoEntity(
        id: '3',
        contentId: 'c3',
        duration: 3665, // 1h 1m 5s
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(v3.formattedDuration, equals('01:01:05'));
    });

    test('VideoStatus parses accurately from strings', () {
      expect(VideoStatus.fromString('ready'), equals(VideoStatus.ready));
      expect(VideoStatus.fromString('processing'), equals(VideoStatus.processing));
      expect(VideoStatus.fromString('uploading'), equals(VideoStatus.uploading));
      expect(VideoStatus.fromString('failed'), equals(VideoStatus.failed));
      expect(VideoStatus.fromString('deleted'), equals(VideoStatus.deleted));
      expect(VideoStatus.fromString('unknown'), equals(VideoStatus.uploading));

      expect(VideoStatus.ready.isReady, isTrue);
      expect(VideoStatus.processing.isProcessing, isTrue);
      expect(VideoStatus.failed.isFailed, isTrue);
    });

    test('VideoProgressEntity factory creates zero state and copyWith works', () {
      final initial = VideoProgressEntity.initial(videoId: 'v1', studentId: 's1');
      expect(initial.progressSeconds, equals(0));
      expect(initial.percentage, equals(0.0));
      expect(initial.completed, isFalse);

      final updated = initial.copyWith(
        progressSeconds: 950,
        durationSeconds: 1000,
        percentage: 95.0,
        completed: true,
      );
      expect(updated.progressSeconds, equals(950));
      expect(updated.completed, isTrue);
    });
  });

  group('VideosCubit Unit Tests', () {
    late MockVideosRepository mockRepo;
    late VideosCubit cubit;

    setUp(() {
      mockRepo = MockVideosRepository();
      cubit = VideosCubit(repository: mockRepo);
    });

    tearDown(() {
      cubit.close();
    });

    test('initial state is VideosInitial', () {
      expect(cubit.state, equals(const VideosInitial()));
    });

    test('loadVideosForGroup emits Loaded on success', () async {
      final sampleVideos = [
        VideoEntity(
          id: 'v1',
          contentId: 'c1',
          title: 'شرح حساب المثلثات',
          duration: 1800,
          status: VideoStatus.ready,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
      mockRepo.videosResponse = sampleVideos;

      await cubit.loadVideosForGroup('grp-1');

      expect(cubit.state, isA<VideosLoaded>());
      final loaded = cubit.state as VideosLoaded;
      expect(loaded.videos.length, equals(1));
      expect(loaded.videos.first.title, equals('شرح حساب المثلثات'));
    });

    test('loadVideosForGroup emits Error on failure', () async {
      mockRepo.failureToThrow = const ServerFailure('خطأ في الاتصال بالخادم');

      await cubit.loadVideosForGroup('grp-1');

      expect(cubit.state, isA<VideosError>());
      final error = cubit.state as VideosError;
      expect(error.message, equals('خطأ في الاتصال بالخادم'));
    });

    test('loadVideoPlayback loads video, signed URL, and student progress for resume', () async {
      mockRepo.progressResponse = VideoProgressEntity(
        videoId: 'vid-1',
        studentId: 'std-1',
        progressSeconds: 320,
        durationSeconds: 1200,
        percentage: 26.6,
        completed: false,
        lastWatchedAt: DateTime.now(),
      );

      await cubit.loadVideoPlayback(videoId: 'vid-1', studentId: 'std-1');

      expect(cubit.state, isA<VideosLoaded>());
      final state = cubit.state as VideosLoaded;
      expect(state.currentVideo?.id, equals('vid-1'));
      expect(state.playbackUrl, contains('vz-04d07c5c-73c.b-cdn.net'));
      expect(state.playbackUrl, contains('token='));
      expect(state.progress?.progressSeconds, equals(320));
    });

    test('uploadVideo emits uploading progress and success states', () async {
      await cubit.uploadVideo(
        contentId: 'c-1',
        title: 'درس جديد',
        videoBytes: [1, 2, 3, 4],
        fileName: 'lesson.mp4',
      );

      expect(cubit.state, isA<VideoUploadSuccess>());
      final success = cubit.state as VideoUploadSuccess;
      expect(success.video.title, equals('درس جديد'));
    });
  });

  group('VideoCard Widget Tests', () {
    testWidgets('renders video title, duration, and status properly', (tester) async {
      final video = VideoEntity(
        id: 'v1',
        contentId: 'c1',
        title: 'درس الإحصاء والاحتمالات',
        duration: 900,
        status: VideoStatus.ready,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: video,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('درس الإحصاء والاحتمالات'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
      expect(find.text('Bunny Stream HLS'), findsOneWidget);

      await tester.tap(find.byType(VideoCard), warnIfMissed: false);
      expect(tapped, isTrue);
    });

    testWidgets('shows completed badge when progress is completed', (tester) async {
      final video = VideoEntity(
        id: 'v1',
        contentId: 'c1',
        title: 'درس الهندسة التحليلية',
        duration: 600,
        status: VideoStatus.ready,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final progress = VideoProgressEntity(
        videoId: 'v1',
        studentId: 's1',
        progressSeconds: 580,
        durationSeconds: 600,
        percentage: 96.6,
        completed: true,
        lastWatchedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoCard(
              video: video,
              progress: progress,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('مكتمل'), findsOneWidget);
      expect(find.text('تم مشاهدة 96%'), findsOneWidget);
    });
  });
}
