import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/features/content/data/models/content_model.dart';
import 'package:edu_saas/features/content/data/models/file_attachment_model.dart';
import 'package:edu_saas/features/content/domain/entities/content_entity.dart';
import 'package:edu_saas/features/content/domain/entities/file_attachment_entity.dart';
import 'package:edu_saas/features/content/domain/repositories/content_repository.dart';
import 'package:edu_saas/features/content/presentation/cubit/content_cubit.dart';
import 'package:edu_saas/features/content/presentation/cubit/content_state.dart';
import 'package:edu_saas/features/content/presentation/pages/student_content_feed_page.dart';
import 'package:edu_saas/features/content/presentation/pages/teacher_content_library_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/features/content/presentation/widgets/content_item_card.dart';
import 'package:edu_saas/features/content/presentation/widgets/material_viewer_sheet.dart';

class _FakeContentRepository implements ContentRepository {
  List<ContentEntity> items;
  bool shouldFail;
  final String? signedUrlResult;

  _FakeContentRepository({
    this.items = const [],
    this.shouldFail = false,
  }) : signedUrlResult = 'https://storage.example.com/signed/test.pdf';

  @override
  Future<Result<List<ContentEntity>>> getGroupContent({
    required String groupId,
    ContentStatus? statusFilter,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Connection error'));
    }
    var list = items.where((i) => i.groupId == groupId).toList();
    if (statusFilter != null) {
      list = list.where((i) => i.status == statusFilter).toList();
    }
    return Success(list);
  }

  @override
  Future<Result<ContentEntity>> createContent({
    required String groupId,
    required String title,
    String? description,
    required ContentType type,
    required ContentStatus status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to create content'));
    }
    final newEntity = ContentEntity(
      id: 'c-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: 't-1',
      groupId: groupId,
      title: title,
      description: description,
      type: type,
      status: status,
      sortOrder: sortOrder ?? items.length,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      file: fileName != null
          ? FileAttachmentEntity(
              id: 'f-1',
              tenantId: 't-1',
              contentId: 'c-new',
              storagePath: storagePath ?? '',
              fileName: fileName,
              mimeType: mimeType ?? 'application/pdf',
              fileSize: fileSize ?? 1024,
              createdAt: DateTime.now(),
            )
          : null,
    );
    items = [...items, newEntity];
    return Success(newEntity);
  }

  @override
  Future<Result<ContentEntity>> updateContent({
    required String contentId,
    String? title,
    String? description,
    ContentType? type,
    ContentStatus? status,
    int? sortOrder,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to update content'));
    }
    final index = items.indexWhere((i) => i.id == contentId);
    if (index == -1) {
      return const FailureResult(ServerFailure('Content not found'));
    }
    final old = items[index];
    final updated = old.copyWith(
      title: title,
      description: description,
      type: type,
      status: status,
      sortOrder: sortOrder,
    );
    items[index] = updated;
    return Success(updated);
  }

  @override
  Future<Result<void>> updateContentStatus({
    required String contentId,
    required ContentStatus status,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Status update error'));
    }
    final index = items.indexWhere((i) => i.id == contentId);
    if (index != -1) {
      items[index] = items[index].copyWith(status: status);
    }
    return const Success(null);
  }

  @override
  Future<Result<void>> reorderContentItems({
    required List<String> contentIdsInOrder,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Reorder error'));
    }
    final map = {for (var i in items) i.id: i};
    final reordered = <ContentEntity>[];
    for (int i = 0; i < contentIdsInOrder.length; i++) {
      final id = contentIdsInOrder[i];
      if (map.containsKey(id)) {
        reordered.add(map[id]!.copyWith(sortOrder: i));
      }
    }
    items = reordered;
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteContent(String contentId) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Delete error'));
    }
    items = items.where((i) => i.id != contentId).toList();
    return const Success(null);
  }

  @override
  Future<Result<String>> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Signed URL generation failed'));
    }
    return Success(signedUrlResult ?? 'https://storage.example.com/url');
  }
}

void main() {
  final testDate = DateTime(2026, 9, 8, 12, 0, 0);

  final mockFileAttachment = FileAttachmentEntity(
    id: 'f-101',
    tenantId: 't-101',
    contentId: 'c-101',
    storagePath: 'groups/g-1/content/doc.pdf',
    fileName: 'Geometry_Reference.pdf',
    mimeType: 'application/pdf',
    fileSize: 2048 * 1024, // 2MB
    createdAt: testDate,
  );

  final mockContentList = [
    ContentEntity(
      id: 'c-101',
      tenantId: 't-101',
      groupId: 'g-1',
      title: 'مذكرة الهندسة الفراغية',
      description: 'شاملة القوانين وتمارين محلولة',
      type: ContentType.pdf,
      status: ContentStatus.published,
      sortOrder: 0,
      publishedAt: testDate,
      createdAt: testDate,
      updatedAt: testDate,
      file: mockFileAttachment,
    ),
    ContentEntity(
      id: 'c-102',
      tenantId: 't-101',
      groupId: 'g-1',
      title: 'فيديو شرح المتجهات',
      description: 'مراجعة الأساسيات قبل الامتحان',
      type: ContentType.video,
      status: ContentStatus.draft,
      sortOrder: 1,
      createdAt: testDate,
      updatedAt: testDate,
    ),
    ContentEntity(
      id: 'c-103',
      tenantId: 't-101',
      groupId: 'g-1',
      title: 'مخطط الإحداثيات الكارتيزية',
      type: ContentType.image,
      status: ContentStatus.archived,
      sortOrder: 2,
      createdAt: testDate,
      updatedAt: testDate,
    ),
  ];

  Widget buildTestWidget({
    required Widget child,
    required ContentRepository repository,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<ContentCubit>(
        create: (_) => ContentCubit(repository: repository),
        child: child,
      ),
    );
  }

  group('Content Models & Serialization Tests', () {
    test('FileAttachmentModel.fromJson and toJson work correctly', () {
      final json = {
        'id': 'f-1',
        'tenant_id': 't-1',
        'content_id': 'c-1',
        'storage_path': 'path/to/file.pdf',
        'file_name': 'test.pdf',
        'mime_type': 'application/pdf',
        'file_size': 1024000,
        'created_at': '2026-09-08T12:00:00.000Z',
      };

      final model = FileAttachmentModel.fromJson(json);
      expect(model.id, 'f-1');
      expect(model.fileName, 'test.pdf');
      expect(model.formattedFileSize, '1000.0 KB');

      final serialized = model.toJson();
      expect(serialized['storage_path'], 'path/to/file.pdf');
      expect(serialized['file_size'], 1024000);
    });

    test('ContentModel.fromJson handles joined files relation correctly', () {
      final json = {
        'id': 'c-1',
        'tenant_id': 't-1',
        'group_id': 'g-1',
        'title': 'امتحان تجريبي',
        'description': 'وصف الامتحان',
        'type': 'exam',
        'status': 'published',
        'sort_order': 3,
        'published_at': '2026-09-08T12:00:00.000Z',
        'created_at': '2026-09-08T10:00:00.000Z',
        'updated_at': '2026-09-08T11:00:00.000Z',
        'files': [
          {
            'id': 'f-99',
            'tenant_id': 't-1',
            'content_id': 'c-1',
            'storage_path': 'exams/exam.pdf',
            'file_name': 'exam.pdf',
            'mime_type': 'application/pdf',
            'file_size': 512000,
            'created_at': '2026-09-08T10:00:00.000Z',
          }
        ],
      };

      final model = ContentModel.fromJson(json);
      expect(model.id, 'c-1');
      expect(model.type, ContentType.exam);
      expect(model.status, ContentStatus.published);
      expect(model.isPublished, isTrue);
      expect(model.hasAttachment, isTrue);
      expect(model.file?.fileName, 'exam.pdf');
    });
  });

  group('ContentCubit Unit Tests', () {
    setUp(() {
      AppCache.content.clear();
    });

    test('loadGroupContent emits Loading then Loaded with items', () async {
      final repo = _FakeContentRepository(items: List.from(mockContentList));
      final cubit = ContentCubit(repository: repo);

      expect(cubit.state, const ContentInitial());

      final future = cubit.loadGroupContent('g-1');
      expect(cubit.state, isA<ContentLoading>());

      await future;
      expect(cubit.state, isA<ContentLoaded>());
      final loaded = cubit.state as ContentLoaded;
      expect(loaded.items.length, 3);
      expect(loaded.draftCount, 1);
      expect(loaded.publishedCount, 1);
      expect(loaded.archivedCount, 1);
    });

    test('loadGroupContent with isStudent: true filters published items only', () async {
      final repo = _FakeContentRepository(items: List.from(mockContentList));
      final cubit = ContentCubit(repository: repo);

      await cubit.loadGroupContent('g-1', isStudent: true);

      expect(cubit.state, isA<ContentLoaded>());
      final loaded = cubit.state as ContentLoaded;
      expect(loaded.items.length, 1);
      expect(loaded.items.first.title, 'مذكرة الهندسة الفراغية');
    });

    test('reorderItems modifies list order in cubit state', () async {
      final repo = _FakeContentRepository(items: List.from(mockContentList));
      final cubit = ContentCubit(repository: repo);

      await cubit.loadGroupContent('g-1');
      await cubit.reorderItems(0, 2);

      final state = cubit.state as ContentLoaded;
      expect(state.items.first.id, 'c-102');
    });

    test('loadGroupContent emits ContentError when repository fails', () async {
      final repo = _FakeContentRepository(shouldFail: true);
      final cubit = ContentCubit(repository: repo);

      await cubit.loadGroupContent('g-1');

      expect(cubit.state, isA<ContentError>());
      expect((cubit.state as ContentError).message, contains('Connection error'));
    });
  });

  group('Content UI Widget Tests', () {
    testWidgets('TeacherContentLibraryPage renders list of items and filter chips',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _FakeContentRepository(items: List.from(mockContentList));

      await tester.pumpWidget(
        buildTestWidget(
          child: const TeacherContentLibraryPage(
            groupId: 'g-1',
            groupName: 'مجموعة SAT المتقدمة',
          ),
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محتوى: مجموعة SAT المتقدمة'), findsOneWidget);
      expect(find.text('الكل (3)'), findsOneWidget);
      expect(find.text('المنشور (1)'), findsOneWidget);
      expect(find.text('المسودات (1)'), findsOneWidget);
      expect(find.text('المؤرشف (1)'), findsOneWidget);
      expect(find.text('مذكرة الهندسة الفراغية'), findsOneWidget);
      expect(find.text('فيديو شرح المتجهات'), findsOneWidget);
      expect(find.byType(ContentItemCard, skipOffstage: false), findsNWidgets(3));
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('TeacherContentLibraryPage renders empty state when group has no content',
        (tester) async {
      final repo = _FakeContentRepository(items: []);

      await tester.pumpWidget(
        buildTestWidget(
          child: const TeacherContentLibraryPage(groupId: 'g-empty'),
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('لا يوجد محتوى تعليمي في هذا التصنيف حتى الآن'), findsOneWidget);
    });

    testWidgets('StudentContentFeedPage renders published content feed and type chips',
        (tester) async {
      final repo = _FakeContentRepository(items: List.from(mockContentList));

      await tester.pumpWidget(
        buildTestWidget(
          child: const StudentContentFeedPage(
            groupId: 'g-1',
            groupName: 'مجموعة SAT',
          ),
          repository: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('محتوى: مجموعة SAT'), findsOneWidget);
      expect(find.text('الكل (1)'), findsOneWidget);
      expect(find.text('مذكرة الهندسة الفراغية'), findsOneWidget);
      // Student feed must never show draft or archived items
      expect(find.text('فيديو شرح المتجهات'), findsNothing);
      expect(find.text('مخطط الإحداثيات الكارتيزية'), findsNothing);
    });

    testWidgets('MaterialViewerSheet renders file details and download button',
        (tester) async {
      final sampleItem = ContentEntity(
        id: 'c-test-sheet',
        tenantId: 't-1',
        groupId: 'g-1',
        title: 'مذكرة قوانين التفاضل',
        description: 'شرح مفصل للمشتقات وتطبيقاتها الهندسية',
        type: ContentType.pdf,
        status: ContentStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        file: FileAttachmentEntity(
          id: 'f-test',
          tenantId: 't-1',
          contentId: 'c-test-sheet',
          storagePath: 'groups/g-1/content/calculus.pdf',
          fileName: 'Calculus_Summary.pdf',
          mimeType: 'application/pdf',
          fileSize: 1024 * 1024 * 2, // 2MB
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: MaterialViewerSheet(
              content: sampleItem,
              onGetSignedUrl: (path) async =>
                  'https://signed.supabase.co/files/$path?token=abc',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('مذكرة قوانين التفاضل'), findsOneWidget);
      expect(find.text('شرح مفصل للمشتقات وتطبيقاتها الهندسية'), findsOneWidget);
      expect(find.text('Calculus_Summary.pdf'), findsOneWidget);
      expect(find.text('تنزيل / فتح الملف'), findsOneWidget);
      expect(find.text('نسخ الرابط الآمن'), findsOneWidget);
    });

    testWidgets('MaterialViewerSheet shows error when URL generation fails',
        (tester) async {
      final sampleItem = ContentEntity(
        id: 'c-test-fail',
        tenantId: 't-1',
        groupId: 'g-1',
        title: 'مذكرة ملغية',
        type: ContentType.pdf,
        status: ContentStatus.published,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        file: FileAttachmentEntity(
          id: 'f-fail',
          tenantId: 't-1',
          contentId: 'c-test-fail',
          storagePath: 'invalid/path.pdf',
          fileName: 'Invalid.pdf',
          mimeType: 'application/pdf',
          fileSize: 1024,
          createdAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: MaterialViewerSheet(
              content: sampleItem,
              onGetSignedUrl: (path) async => null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('تعذر توليد رابط الوصول الآمن في الوقت الحالي'), findsOneWidget);
    });
  });
}
