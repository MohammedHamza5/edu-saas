import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/features/content/domain/entities/file_attachment_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_progress_entity.dart';
import 'package:edu_saas/features/videos/domain/repositories/videos_repository.dart';
import 'package:edu_saas/features/videos/presentation/cubit/videos_cubit.dart';
import 'package:edu_saas/features/videos/presentation/cubit/videos_state.dart';
import 'package:edu_saas/features/videos/presentation/widgets/video_card.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';

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

  @override
  Future<Result<String>> getSignedFileUrl(String storagePath) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    return Result.success('https://example.com/signed/$storagePath');
  }

  @override
  Future<Result<VideoEntity>> attachMaterialToVideo({
    required String videoId,
    required String contentId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    final attached = FileAttachmentEntity(
      id: 'file-1',
      tenantId: 'tenant-1',
      contentId: contentId,
      fileName: fileName,
      storagePath: 'tenants/tenant-1/content/$contentId/$fileName',
      fileSize: fileBytes.length,
      mimeType: 'application/pdf',
      createdAt: DateTime.now(),
    );
    final base = singleVideoResponse ??
        VideoEntity(
          id: videoId,
          contentId: contentId,
          title: 'درس الجبر والهندسة',
          providerVideoId: 'test-guid',
          duration: 1200,
          status: VideoStatus.ready,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
    return Result.success(base.copyWith(attachedFile: attached));
  }

  @override
  Future<Result<VideoEntity>> linkYouTubeVideo({
    required String contentId,
    required String youtubeUrl,
    String? title,
  }) async {
    if (failureToThrow != null) return Result.failure(failureToThrow!);
    final video = VideoEntity(
      id: 'vid-yt-1',
      contentId: contentId,
      title: title ?? 'درس يوتيوب',
      provider: 'youtube',
      providerVideoId: 'dQw4w9WgXcQ',
      playbackUrl: 'https://www.youtube-nocookie.com/embed/dQw4w9WgXcQ?enablejsapi=1',
      thumbnailUrl: 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      status: VideoStatus.ready,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return Result.success(video);
  }
}

void main() {
  group('VideoEntity & VideoProgressEntity Unit Tests', () {
    test('isYouTube and isBunny getters reflect provider', () {
      final yt = VideoEntity(
        id: '1',
        contentId: 'c1',
        provider: 'youtube',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(yt.isYouTube, isTrue);
      expect(yt.isBunny, isFalse);

      final bunny = VideoEntity(
        id: '2',
        contentId: 'c2',
        provider: 'bunny',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(bunny.isBunny, isTrue);
      expect(bunny.isYouTube, isFalse);
    });
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

    test('loadVideoPlayback with un-uploaded video emits Loaded with null playbackUrl', () async {
      mockRepo.singleVideoResponse = VideoEntity(
        id: 'vid-pending',
        contentId: 'c-pending',
        title: 'درس قيد التجهيز',
        providerVideoId: null,
        duration: 0,
        status: VideoStatus.uploading,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await cubit.loadVideoPlayback(videoId: 'vid-pending', studentId: 'std-1');

      expect(cubit.state, isA<VideosLoaded>());
      final state = cubit.state as VideosLoaded;
      expect(state.currentVideo?.id, equals('vid-pending'));
      expect(state.playbackUrl, isNull);
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

    test('linkYouTubeVideo links unlisted youtube lesson successfully', () async {
      final success = await cubit.linkYouTubeVideo(
        contentId: 'c-yt',
        youtubeUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        title: 'درس يوتيوب SAT',
      );

      expect(success, isTrue);
      expect(cubit.state, isA<VideoUploadSuccess>());
      final state = cubit.state as VideoUploadSuccess;
      expect(state.video.isYouTube, isTrue);
      expect(state.video.providerVideoId, equals('dQw4w9WgXcQ'));
    });
  });

  group('VideoCard Widget Tests', () {
    testWidgets('renders video title, duration, and CDN status properly', (tester) async {
      final video = VideoEntity(
        id: 'v1',
        contentId: 'c1',
        title: 'درس الإحصاء والاحتمالات',
        duration: 900,
        provider: 'bunny',
        status: VideoStatus.ready,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
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
      expect(find.text('Bunny CDN آمن'), findsOneWidget);

      await tester.tap(find.byType(VideoCard), warnIfMissed: false);
      expect(tapped, isTrue);
    });

    testWidgets('renders YouTube badge for youtube video', (tester) async {
      final video = VideoEntity(
        id: 'v-yt',
        contentId: 'c-yt',
        title: 'بث مباشر SAT Math',
        duration: 3600,
        provider: 'youtube',
        status: VideoStatus.ready,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: Scaffold(
            body: VideoCard(
              video: video,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('بث مباشر SAT Math'), findsOneWidget);
      expect(find.text('يوتيوب'), findsOneWidget);
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
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
