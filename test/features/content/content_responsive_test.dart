import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/content/domain/entities/content_entity.dart';
import 'package:edu_saas/features/content/domain/entities/file_attachment_entity.dart';
import 'package:edu_saas/features/content/domain/repositories/content_repository.dart';
import 'package:edu_saas/features/content/presentation/cubit/content_cubit.dart';
import 'package:edu_saas/features/content/presentation/cubit/course_progress_cubit.dart';
import 'package:edu_saas/features/content/domain/entities/lesson_assignment_entity.dart';
import 'package:edu_saas/features/content/presentation/pages/student_content_feed_page.dart';
import 'package:edu_saas/features/content/presentation/pages/teacher_content_library_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/features/content/presentation/widgets/content_item_card.dart';
import 'package:edu_saas/features/content/presentation/widgets/material_viewer_sheet.dart';

class _FakeContentRepository implements ContentRepository {
  final List<ContentEntity> items;

  _FakeContentRepository({required this.items});

  @override
  Future<Result<List<ContentEntity>>> getGroupContent({
    required String groupId,
    int page = 1,
    int pageSize = 20,
    ContentStatus? statusFilter,
  }) async {
    var list = items.where((i) => i.groupId == groupId).toList();
    if (statusFilter != null) {
      list = list.where((i) => i.status == statusFilter).toList();
    }
    return Success(list);
  }

  @override
  Future<Result<List<LessonAssignmentEntity>>> getGroupCourseProgress({
    required String groupId,
    String? studentId,
  }) async {
    final list = items
        .where((i) => i.groupId == groupId)
        .map((i) => LessonAssignmentEntity(
              contentGroupId: 'cg-${i.id}',
              contentId: i.id,
              groupId: i.groupId ?? '',
              title: i.title,
              description: i.description,
              type: i.type,
              sortOrder: i.sortOrder,
              access: LessonAccess.unlocked,
              progress: LessonProgress.notStarted,
            ))
        .toList();
    return Success(list);
  }

  @override
  Future<Result<void>> manualUnlockLesson({
    required String studentId,
    required String groupId,
    required String contentId,
    String? reason,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<ContentEntity>> createContent({
    String? groupId,
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
    String? associatedExamId,
    String? prerequisiteExamId,
  }) async {
    final entity = ContentEntity(
      id: 'c-new',
      tenantId: 't-1',
      groupId: groupId,
      title: title,
      description: description,
      type: type,
      status: status,
      sortOrder: sortOrder ?? 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      associatedExamId: associatedExamId,
      prerequisiteExamId: prerequisiteExamId,
    );
    return Success(entity);
  }

  @override
  Future<Result<ContentEntity>> updateContent({
    required String contentId,
    String? title,
    String? description,
    ContentType? type,
    ContentStatus? status,
    int? sortOrder,
    String? fileName,
    String? storagePath,
    String? mimeType,
    int? fileSize,
    List<int>? fileBytes,
    String? associatedExamId,
    String? prerequisiteExamId,
  }) async {
    final item = items.firstWhere((i) => i.id == contentId);
    return Success(item);
  }

  @override
  Future<Result<void>> updateContentStatus({
    required String contentId,
    required ContentStatus status,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> reorderContentItems({
    required List<String> contentIdsInOrder,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteContent(String contentId) async {
    return const Success(null);
  }

  @override
  Future<Result<String>> getSignedFileUrl({
    required String storagePath,
    int expiresInSeconds = 3600,
  }) async {
    return const Success('https://storage.supabase.co/signed/file.pdf');
  }

  @override
  Future<Result<List<ContentEntity>>> getCentralVideoBank({
    int page = 0,
    int pageSize = 100,
  }) async {
    return Success(items);
  }

  @override
  Future<Result<void>> assignContentToGroups({
    required String contentId,
    required List<String> groupIds,
    List<Map<String, dynamic>>? groupConfigs,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<void>> linkLessonExam({
    required String contentId,
    required String examId,
  }) async {
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

  final sampleItems = [
    ContentEntity(
      id: 'c-1',
      tenantId: 't-1',
      groupId: 'grp-sat-1',
      title: 'مذكرة قوانين التفاضل والتكامل الشاملة (Calculus Sheet)',
      description: 'تشمل جميع مشتقات الدوال المثلثية والقواعد الأساسية مع 50 مسألة محلولة بالتفصيل.',
      type: ContentType.video,
      status: ContentStatus.published,
      sortOrder: 0,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      publishedAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now(),
      file: FileAttachmentEntity(
        id: 'f-1',
        tenantId: 't-1',
        contentId: 'c-1',
        storagePath: 'groups/grp-sat-1/content/calculus.pdf',
        fileName: 'Calculus_Summary_2026.pdf',
        mimeType: 'application/pdf',
        fileSize: 1024 * 1024 * 2, // 2MB
        createdAt: DateTime.now(),
      ),
    ),
    ContentEntity(
      id: 'c-2',
      tenantId: 't-1',
      groupId: 'grp-sat-1',
      title: 'مسودة واجب الجبر والمحددات',
      description: 'تمارين خاصة بطلاب المستوى المتقدم قيد المراجعة.',
      type: ContentType.assignment,
      status: ContentStatus.draft,
      sortOrder: 1,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  Widget createTestWidget({
    required Widget child,
    required _FakeContentRepository repo,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<ContentCubit>(
            create: (_) => ContentCubit(repository: repo),
          ),
          BlocProvider<CourseProgressCubit>(
            create: (_) => CourseProgressCubit(repository: repo),
          ),
        ],
        child: child,
      ),
    );
  }

  group('TeacherContentLibraryPage Multi-Device Responsive Tests', () {
    for (final entry in deviceSizes.entries) {
      testWidgets('Renders cleanly on screen size (${entry.key}) with zero overflow',
          (tester) async {
        final repo = _FakeContentRepository(items: sampleItems);

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(
            repo: repo,
            child: const TeacherContentLibraryPage(
              groupId: 'grp-sat-1',
              groupName: 'SAT Math Advanced',
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check Content items
        expect(find.text(sampleItems[0].title), findsOneWidget);
        expect(find.text('إضافة درس'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('StudentContentFeedPage Multi-Device Responsive Tests', () {
    for (final entry in deviceSizes.entries) {
      testWidgets('Renders cleanly on screen size (${entry.key}) with zero overflow',
          (tester) async {
        final repo = _FakeContentRepository(items: sampleItems);

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          createTestWidget(
            repo: repo,
            child: const StudentContentFeedPage(
              groupId: 'grp-sat-1',
              groupName: 'SAT Math Advanced',
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text(sampleItems[0].title), findsWidgets);
        expect(find.textContaining('SAT Math Advanced'), findsWidgets);

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('ContentItemCard Narrow Width Overflow Tests', () {
    testWidgets('Renders on ultra-narrow width (288px) without overflow', (tester) async {
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
            body: Center(
              child: SizedBox(
                width: 288,
                child: ContentItemCard(
                  content: sampleItems[0],
                  isTeacher: true,
                  index: 0,
                  onEdit: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text(sampleItems[0].title), findsOneWidget);
      expect(find.text('منشور'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('MaterialViewerSheet Multi-Device Responsive Tests', () {
    for (final entry in deviceSizes.entries) {
      testWidgets('Renders cleanly on screen size (${entry.key}) with zero overflow',
          (tester) async {
        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('ar'),
            home: Scaffold(
              body: MaterialViewerSheet(
                content: sampleItems[0],
                onGetSignedUrl: (path) async =>
                    'https://storage.supabase.co/signed/$path',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text(sampleItems[0].title), findsOneWidget);
        expect(find.text(sampleItems[0].file!.fileName), findsOneWidget);
        expect(find.text('تنزيل / فتح الملف'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
