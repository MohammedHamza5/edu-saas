import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import 'package:edu_saas/features/groups/domain/entities/group_member_entity.dart';
import 'package:edu_saas/features/groups/domain/repositories/groups_repository.dart';
import 'package:edu_saas/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:edu_saas/features/videos/domain/entities/library_video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_entity.dart';
import 'package:edu_saas/features/videos/domain/entities/video_folder_entity.dart';
import 'package:edu_saas/features/videos/domain/repositories/video_bank_repository.dart';
import 'package:edu_saas/features/videos/presentation/cubit/video_bank_cubit.dart';
import 'package:edu_saas/features/content/presentation/pages/teacher_video_bank_page.dart';

class _FakeVideoBankRepository implements VideoBankRepository {
  final List<VideoFolderEntity> folders;
  final List<LibraryVideoEntity> videos;

  _FakeVideoBankRepository({this.folders = const [], this.videos = const []});

  @override
  Future<Result<List<VideoFolderEntity>>> getFolders({String? parentId}) async =>
      Success(folders);

  @override
  Future<Result<List<VideoFolderEntity>>> getAllFolders() async =>
      Success(folders);

  @override
  Future<Result<VideoFolderEntity>> createFolder({
    required String name,
    String? parentId,
  }) async => Success(
    VideoFolderEntity(
      id: 'f-new',
      tenantId: 'tenant-1',
      name: name,
      parentId: parentId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  @override
  Future<Result<VideoFolderEntity>> updateFolder({
    required String id,
    required String name,
  }) async => Success(
    VideoFolderEntity(
      id: id,
      tenantId: 'tenant-1',
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  @override
  Future<Result<void>> deleteFolder(String id) async => const Success(null);

  @override
  Future<Result<List<LibraryVideoEntity>>> getVideos({
    String? folderId,
    String? search,
  }) async => Success(videos);

  @override
  Future<Result<LibraryVideoEntity>> getVideoById(String id) async =>
      Success(videos.firstWhere((v) => v.id == id));

  @override
  Future<Result<LibraryVideoEntity>> uploadVideo({
    required String title,
    String? description,
    String? folderId,
    required List<int> videoBytes,
    void Function(int sentBytes, int totalBytes)? onProgress,
  }) async => Success(
    LibraryVideoEntity(
      id: 'v-new',
      tenantId: 'tenant-1',
      title: title,
      provider: 'bunny',
      status: VideoStatus.ready,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );

  @override
  Future<Result<LibraryVideoEntity>> syncVideoStatus(
    String libraryVideoId,
  ) async => Success(videos.firstWhere((v) => v.id == libraryVideoId));

  @override
  Future<Result<void>> deleteVideo(String id) async => const Success(null);

  @override
  Future<Result<LibraryVideoEntity>> moveVideo({
    required String id,
    String? targetFolderId,
  }) async => Success(videos.firstWhere((v) => v.id == id));

  @override
  Future<Result<LibraryVideoEntity>> updateVideo({
    required String id,
    required String title,
    String? description,
  }) async => Success(videos.firstWhere((v) => v.id == id));

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
  void cancelActiveUpload() {}

  @override
  Future<Result<Map<String, dynamic>>> assignFolderAsChapter({
    required String folderId,
    required String groupId,
    String? chapterTitle,
  }) async => const Success({'chapter_id': 'chap-1', 'lessons_count': 1});
}

class _FakeGroupsRepository implements GroupsRepository {
  @override
  Future<Result<List<GroupEntity>>> getGroups() async => const Success([]);

  @override
  Future<Result<GroupEntity>> createGroup({
    required String name,
    required String level,
    String? description,
    required String previousContentAccess,
  }) async => throw UnimplementedError();

  @override
  Future<Result<GroupEntity>> updateGroup({
    required String id,
    String? name,
    String? level,
    String? description,
    String? previousContentAccess,
    String? status,
    bool? enforceSequentialLearning,
    int? defaultPassingScore,
  }) async => throw UnimplementedError();

  @override
  Future<Result<List<GroupMemberEntity>>> getGroupMembers(
    String groupId,
  ) async => const Success([]);

  @override
  Future<Result<GroupMemberEntity>> addMemberToGroup({
    required String groupId,
    required String studentId,
  }) async => throw UnimplementedError();

  @override
  Future<Result<void>> removeMemberFromGroup({
    required String groupId,
    required String studentId,
  }) async => const Success(null);

  @override
  Future<Result<void>> deleteGroup(String groupId) async => const Success(null);
}

void main() {
  Widget createTestWidget({
    required VideoBankCubit videoBankCubit,
    required GroupsCubit groupsCubit,
  }) {
    return MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar'), Locale('en')],
      home: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: videoBankCubit),
          BlocProvider.value(value: groupsCubit),
        ],
        child: const TeacherVideoBankPage(),
      ),
    );
  }

  testWidgets('TeacherVideoBankPage builds and renders correctly without RenderFlex/RenderSliver errors', (
    tester,
  ) async {
    final mockVideoRepo = _FakeVideoBankRepository(
      folders: [
        VideoFolderEntity(
          id: 'f-1',
          tenantId: 'tenant-1',
          name: 'Algebra Videos',
          videoCount: 2,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
      videos: [
        LibraryVideoEntity(
          id: 'v-1',
          tenantId: 'tenant-1',
          title: 'Quadratic Equations Intro',
          provider: 'bunny',
          status: VideoStatus.ready,
          duration: 1200,
          assignedLecturesCount: 1,
          assignedGroupNames: ['SAT Group A'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ],
    );

    final mockGroupsRepo = _FakeGroupsRepository();

    final videoBankCubit = VideoBankCubit(repository: mockVideoRepo);
    final groupsCubit = GroupsCubit(repository: mockGroupsRepo);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestWidget(
        videoBankCubit: videoBankCubit,
        groupsCubit: groupsCubit,
      ),
    );

    // Initial pump (triggers initState loadFolder & loadGroups)
    await tester.pump();
    // Complete asynchronous future resolution
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TeacherVideoBankPage), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);
    expect(find.text('Algebra Videos'), findsOneWidget);
    expect(find.text('Quadratic Equations Intro'), findsOneWidget);

    await videoBankCubit.close();
    await groupsCubit.close();
  });

  testWidgets('TeacherVideoBankPage renders empty state and mobile layout cleanly', (
    tester,
  ) async {
    final mockVideoRepo = _FakeVideoBankRepository(
      folders: const [],
      videos: const [],
    );
    final mockGroupsRepo = _FakeGroupsRepository();

    final videoBankCubit = VideoBankCubit(repository: mockVideoRepo);
    final groupsCubit = GroupsCubit(repository: mockGroupsRepo);

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      createTestWidget(
        videoBankCubit: videoBankCubit,
        groupsCubit: groupsCubit,
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(TeacherVideoBankPage), findsOneWidget);
    expect(find.byType(CustomScrollView), findsOneWidget);

    await videoBankCubit.close();
    await groupsCubit.close();
  });
}
