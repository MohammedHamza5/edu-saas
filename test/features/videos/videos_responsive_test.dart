import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_state.dart';
import 'package:edu_saas/features/videos/domain/entities/video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_progress_entity.dart';
import 'package:edu_saas/features/videos/domain/repositories/videos_repository.dart';
import 'package:edu_saas/features/videos/presentation/cubit/videos_cubit.dart';
import 'package:edu_saas/features/videos/presentation/pages/video_player_page.dart';
import 'package:edu_saas/features/videos/presentation/widgets/video_card.dart';

class _FakeAuthCubit extends Cubit<AuthState> implements AuthCubit {
  _FakeAuthCubit()
      : super(
          const AuthAuthenticated(
            UserEntity(
              id: 'std-responsive-1',
              tenantId: 'tenant-1',
              email: 'student@al-nour.edu',
              fullName: 'طالب النظام الأمريكي',
              role: UserRole.student,
              status: UserStatus.active,
            ),
          ),
        );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeVideosRepository implements VideosRepository {
  final VideoEntity video;
  final VideoProgressEntity progress;

  _FakeVideosRepository({
    required this.video,
    required this.progress,
  });

  @override
  Future<Result<List<VideoEntity>>> getVideosForGroup(String groupId) async {
    return Success([video]);
  }

  @override
  Future<Result<VideoEntity>> getVideoById(String videoId) async {
    return Success(video);
  }

  @override
  Future<Result<String>> getPlaybackUrl(String videoId) async {
    return const Success(
      'https://vz-04d07c5c-73c.b-cdn.net/sample-guid/playlist.m3u8?token=mocktoken',
    );
  }

  @override
  Future<Result<VideoProgressEntity?>> getVideoProgress({
    required String videoId,
    required String studentId,
  }) async {
    return Success(progress);
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
    return Success(progress);
  }

  @override
  Future<Result<VideoEntity>> createAndUploadVideo({
    required String contentId,
    required String title,
    required List<int> videoBytes,
    required String fileName,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async {
    return Success(video);
  }

  @override
  Future<Result<void>> deleteVideo(String videoId) async {
    return const Success(null);
  }
}

void main() {
  const deviceSizes = <String, Size>{
    '320x640 (Compact Mobile)': Size(320, 640),
    '390x844 (Standard Mobile)': Size(390, 844),
    '768x1024 (Tablet Portrait)': Size(768, 1024),
    '1440x900 (Desktop Laptop)': Size(1440, 900),
    '1920x1080 (Large Desktop)': Size(1920, 1080),
  };

  final sampleVideo = VideoEntity(
    id: 'vid-sat-math-1',
    contentId: 'content-math-1',
    title: 'شرح تفصيلي: حل معادلات الدرجة الثانية والدوال التربيعية (SAT Math)',
    description: 'في هذا الدرس نتناول القانون العام، المميز، ورسم المنحنيات مع أمثلة عملية.',
    providerVideoId: 'guid-12345',
    duration: 1800, // 30 mins
    status: VideoStatus.ready,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleProgress = VideoProgressEntity(
    videoId: 'vid-sat-math-1',
    studentId: 'std-responsive-1',
    progressSeconds: 1200, // 20 mins
    durationSeconds: 1800,
    percentage: 66.6,
    completed: false,
    lastWatchedAt: DateTime.now(),
  );

  Widget createTestWidget({
    required Widget child,
    required _FakeVideosRepository repo,
    required _FakeAuthCubit authCubit,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<VideosCubit>(
            create: (_) => VideosCubit(repository: repo),
          ),
        ],
        child: child,
      ),
    );
  }

  group('VideoPlayerPage Multi-Device Responsive Tests', () {
    for (final entry in deviceSizes.entries) {
      testWidgets('Renders VideoPlayerPage cleanly on screen size (${entry.key}) with zero overflow',
          (tester) async {
        final repo = _FakeVideosRepository(
          video: sampleVideo,
          progress: sampleProgress,
        );
        final authCubit = _FakeAuthCubit();

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(
            repo: repo,
            authCubit: authCubit,
            child: const VideoPlayerPage(videoId: 'vid-sat-math-1'),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify Page Title and CDN Badge rendered
        expect(find.text('مشاهدة الدرس التعليمي'), findsOneWidget);
        expect(find.text('Bunny CDN آمن'), findsOneWidget);

        // 2. Verify Academic Stats and Milestones
        expect(find.text('التقدم الأكاديمي للدرس'), findsOneWidget);
        expect(find.text('نسبة الإنجاز: 66%'), findsOneWidget);
        expect(find.text('محطات الدرس الأكاديمية:'), findsOneWidget);
        expect(find.text('المفاهيم والتأسيس'), findsOneWidget);

        // 3. Verify Desktop-specific shortcuts bar vs Mobile-specific stack
        if (entry.value.width >= 960) {
          expect(find.text('مسافة'), findsOneWidget);
          expect(find.text('تشغيل / إيقاف'), findsOneWidget);
          expect(find.text('F'), findsOneWidget);
        }

        // 4. Zero RenderFlex overflow assertions
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('VideoCard Multi-Device Responsive Tests', () {
    for (final entry in deviceSizes.entries) {
      testWidgets('Renders VideoCard without overflow on (${entry.key})', (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: entry.value.width > 500 ? 400 : entry.value.width - 32,
                  child: VideoCard(
                    video: sampleVideo,
                    progress: sampleProgress,
                    onTap: () {},
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text(sampleVideo.title!), findsOneWidget);
        expect(find.text('30:00'), findsOneWidget);
        expect(find.text('Bunny Stream HLS'), findsOneWidget);
        expect(find.text('تم مشاهدة 66%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
