import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/features/videos/domain/entities/library_video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_folder_entity.dart';
import 'package:edu_saas/features/videos/domain/repositories/video_bank_repository.dart';
import 'package:edu_saas/features/videos/presentation/cubit/video_bank_cubit.dart';
import 'package:edu_saas/features/videos/presentation/cubit/video_bank_state.dart';
import 'package:edu_saas/features/videos/presentation/widgets/global_video_upload_floating_banner.dart';

class _FakeVideoBankRepoForBanner implements VideoBankRepository {
  bool cancelCalled = false;

  @override
  Future<Result<List<VideoFolderEntity>>> getFolders({String? parentId}) async =>
      const Success([]);

  @override
  Future<Result<List<VideoFolderEntity>>> getAllFolders() async =>
      const Success([]);

  @override
  Future<Result<VideoFolderEntity>> createFolder({
    required String name,
    String? parentId,
  }) async => throw UnimplementedError();

  @override
  Future<Result<VideoFolderEntity>> updateFolder({
    required String id,
    required String name,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> deleteFolder(String id) async => const Success(null);

  @override
  Future<Result<List<LibraryVideoEntity>>> getVideos({
    String? folderId,
    String? search,
  }) async => const Success([]);

  @override
  Future<Result<LibraryVideoEntity>> getVideoById(String id) async =>
      throw UnimplementedError();

  @override
  Future<Result<LibraryVideoEntity>> uploadVideo({
    required String title,
    String? description,
    String? folderId,
    required List<int> videoBytes,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async => throw UnimplementedError();

  @override
  Future<Result<LibraryVideoEntity>> syncVideoStatus(String libraryVideoId) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> deleteVideo(String id) async => const Success(null);

  @override
  Future<Result<LibraryVideoEntity>> moveVideo({
    required String id,
    String? targetFolderId,
  }) async => throw UnimplementedError();

  @override
  Future<Result<LibraryVideoEntity>> updateVideo({
    required String id,
    required String title,
    String? description,
  }) async => throw UnimplementedError();

  @override
  Future<Result<String>> getPlaybackUrl(String libraryVideoId) async =>
      const Success('https://video.bunnycdn.com/play');

  @override
  Future<Result<void>> linkToLectureContent({
    required String libraryVideoId,
    required String contentId,
    required String title,
  }) async => const Success(null);

  @override
  void cancelActiveUpload() {
    cancelCalled = true;
  }
}

Widget createTestBannerWidget({required VideoBankCubit cubit}) {
  return MaterialApp(
    locale: const Locale('ar'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ar'), Locale('en')],
    home: Scaffold(
      body: BlocProvider<VideoBankCubit>.value(
        value: cubit,
        child: const Stack(
          children: [
            Center(child: Text('Main Content')),
            GlobalVideoUploadFloatingBanner(),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('GlobalVideoUploadFloatingBanner is hidden when not uploading', (tester) async {
    final repo = _FakeVideoBankRepoForBanner();
    final cubit = VideoBankCubit(repository: repo);

    await tester.pumpWidget(createTestBannerWidget(cubit: cubit));
    await tester.pumpAndSettle();

    expect(find.byType(GlobalVideoUploadFloatingBanner), findsOneWidget);
    // Cancel button and progress bar should not be visible
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await cubit.close();
  });

  testWidgets('GlobalVideoUploadFloatingBanner shows progress and collapses/expands smoothly', (tester) async {
    final repo = _FakeVideoBankRepoForBanner();
    final cubit = VideoBankCubit(repository: repo);

    await tester.pumpWidget(createTestBannerWidget(cubit: cubit));
    await tester.pumpAndSettle();

    // Emit loaded state with active upload
    cubit.emit(const VideoBankLoaded(
      folders: [],
      videos: [],
      uploadProgress: 0.45,
      uploadingTitle: 'SAT_Math_Lesson_1.mp4',
    ));
    await tester.pumpAndSettle();

    // Verify expanded view elements are visible
    expect(find.text('SAT_Math_Lesson_1.mp4'), findsOneWidget);
    expect(find.textContaining('45%'), findsOneWidget);
    expect(find.byIcon(Icons.cancel_outlined), findsOneWidget); // Cancel button
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget); // Minimize button

    // Tap minimize to collapse into pill
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pumpAndSettle();

    // Expanded card header with cancel icon is now hidden, compact pill is shown
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

    // Tap pill to re-expand
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pumpAndSettle();

    // Expanded card restored
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);
    expect(find.textContaining('45%'), findsOneWidget);

    await cubit.close();
  });
}
