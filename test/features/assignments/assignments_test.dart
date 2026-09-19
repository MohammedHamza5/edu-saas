import 'dart:async';
import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/utils/cache_manager.dart';
import 'package:edu_saas/features/assignments/data/models/assignment_model.dart';
import 'package:edu_saas/features/assignments/data/models/assignment_submission_model.dart';
import 'package:edu_saas/features/assignments/domain/entities/assignment_entity.dart';
import 'package:edu_saas/features/assignments/domain/repositories/assignments_repository.dart';
import 'package:edu_saas/features/assignments/presentation/cubit/assignments_cubit.dart';
import 'package:edu_saas/features/assignments/presentation/cubit/assignments_state.dart';
import 'package:edu_saas/features/assignments/presentation/pages/grade_submission_page.dart';
import 'package:edu_saas/features/assignments/presentation/pages/student_assignments_page.dart';
import 'package:edu_saas/features/assignments/presentation/pages/teacher_assignments_page.dart';
import 'package:edu_saas/features/assignments/presentation/widgets/assignment_card.dart';
import 'package:edu_saas/features/assignments/presentation/widgets/submission_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAssignmentsRepository implements AssignmentsRepository {
  List<AssignmentEntity> mockAssignments = [];
  List<AssignmentSubmissionEntity> mockSubmissions = [];
  AssignmentSubmissionEntity? mockMySubmission;
  bool shouldFail = false;
  String failureMessage = 'Server error occurred';

  @override
  Future<Result<List<AssignmentEntity>>> getGroupAssignments(
    String groupId, {
    int page = 0,
    int pageSize = 15,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return Success(mockAssignments);
  }

  @override
  Future<Result<List<AssignmentEntity>>> getStudentAssignments({
    int page = 0,
    int pageSize = 15,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return Success(mockAssignments);
  }

  @override
  Future<Result<AssignmentEntity>> getAssignmentDetails(
    String assignmentId,
  ) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final item = mockAssignments.firstWhere(
      (a) => a.id == assignmentId,
      orElse: () => mockAssignments.first,
    );
    return Success(item);
  }

  @override
  Future<Result<List<AssignmentSubmissionEntity>>> getSubmissions(
    String assignmentId,
  ) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return Success(mockSubmissions);
  }

  @override
  Future<Result<AssignmentSubmissionEntity?>> getMySubmission(
    String assignmentId,
  ) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return Success(mockMySubmission);
  }

  @override
  Future<Result<AssignmentEntity>> createAssignment({
    required String groupId,
    required String title,
    String? instructions,
    DateTime? dueAt,
    bool allowLateSubmission = false,
    int maxScore = 100,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final newAssignment = AssignmentEntity(
      id: 'new-assignment-${DateTime.now().millisecondsSinceEpoch}',
      contentId: 'content-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: 'tenant-1',
      groupId: groupId,
      title: title,
      instructions: instructions,
      dueAt: dueAt,
      allowLateSubmission: allowLateSubmission,
      maxScore: maxScore,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    mockAssignments.add(newAssignment);
    return Success(newAssignment);
  }

  @override
  Future<Result<AssignmentSubmissionEntity>> submitAssignment({
    required String assignmentId,
    required List<({String fileName, List<int> bytes, String mimeType})> files,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final submission = AssignmentSubmissionEntity(
      id: 'sub-new-1',
      assignmentId: assignmentId,
      studentId: 'student-current',
      studentName: 'أحمد محمود',
      attemptNumber: 1,
      submittedAt: DateTime.now(),
      status: SubmissionStatus.submitted,
      files: files
          .map(
            (f) => SubmissionFileEntity(
              id: 'file-${f.fileName}',
              submissionId: 'sub-new-1',
              storagePath: 'path/${f.fileName}',
              fileName: f.fileName,
              mimeType: f.mimeType,
              fileSize: f.bytes.length,
              createdAt: DateTime.now(),
            ),
          )
          .toList(),
    );
    mockMySubmission = submission;
    return Success(submission);
  }

  @override
  Future<Result<AssignmentSubmissionEntity>> gradeSubmission({
    required String submissionId,
    required int score,
    String? feedback,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    final index = mockSubmissions.indexWhere((s) => s.id == submissionId);
    final target = index != -1
        ? mockSubmissions[index]
        : AssignmentSubmissionEntity(
            id: submissionId,
            assignmentId: 'assign-1',
            studentId: 'student-1',
            studentName: 'محمد أحمد',
            submittedAt: DateTime.now(),
          );

    final updated = target.copyWith(
      score: score,
      teacherFeedback: feedback,
      status: SubmissionStatus.reviewed,
      reviewedAt: DateTime.now(),
    );

    if (index != -1) {
      mockSubmissions[index] = updated;
    }
    return Success(updated);
  }

  @override
  Future<Result<String>> getSubmissionFileSignedUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    if (shouldFail) return FailureResult(ServerFailure(failureMessage));
    return Success('https://signed.supabase.co/files/$storagePath?token=abc');
  }
}

Widget createTestApp({required Widget child}) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('ar')],
    locale: const Locale('ar'),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Assignment Entities & Models Tests', () {
    test('SubmissionStatus enum properties and fromString', () {
      expect(
        SubmissionStatus.fromString('submitted'),
        SubmissionStatus.submitted,
      );
      expect(
        SubmissionStatus.fromString('reviewed'),
        SubmissionStatus.reviewed,
      );
      expect(SubmissionStatus.fromString('late'), SubmissionStatus.late);
      expect(
        SubmissionStatus.fromString('UNKNOWN'),
        SubmissionStatus.submitted,
      );

      expect(SubmissionStatus.submitted.labelAr, 'بانتظار التصحيح');
      expect(SubmissionStatus.reviewed.labelAr, 'تم التصحيح والتقييم');
      expect(SubmissionStatus.late.labelAr, 'تسليم متأخر');
    });

    test('SubmissionFileEntity formattedSize calculation', () {
      final small = SubmissionFileEntity(
        id: 'f1',
        submissionId: 's1',
        storagePath: 'p1',
        fileName: 'doc.txt',
        mimeType: 'text/plain',
        fileSize: 500,
        createdAt: DateTime.now(),
      );
      expect(small.formattedSize, '500 B');

      final medium = SubmissionFileEntity(
        id: 'f2',
        submissionId: 's1',
        storagePath: 'p2',
        fileName: 'sheet.pdf',
        mimeType: 'application/pdf',
        fileSize: 1024 * 150,
        createdAt: DateTime.now(),
      );
      expect(medium.formattedSize, '150.0 KB');
      expect(medium.isPdf, true);

      final large = SubmissionFileEntity(
        id: 'f3',
        submissionId: 's1',
        storagePath: 'p3',
        fileName: 'photo.png',
        mimeType: 'image/png',
        fileSize: 1024 * 1024 * 3,
        createdAt: DateTime.now(),
      );
      expect(large.formattedSize, '3.0 MB');
      expect(large.isImage, true);
    });

    test('AssignmentSubmissionModel.fromJson & toJson', () {
      final json = {
        'id': 'sub-123',
        'assignment_id': 'assign-456',
        'student_id': 'user-789',
        'attempt_number': 2,
        'submitted_at': '2026-09-08T12:00:00.000Z',
        'status': 'reviewed',
        'score': 95,
        'teacher_feedback': 'ممتاز جداً',
        'users': {'full_name': 'عمر خالد', 'email': 'omar@example.com'},
        'submission_files': [
          {
            'id': 'file-1',
            'submission_id': 'sub-123',
            'storage_path': 'storage/path/file.pdf',
            'file_name': 'solution.pdf',
            'mime_type': 'application/pdf',
            'file_size': 2048,
            'created_at': '2026-09-08T12:01:00.000Z',
          },
        ],
      };

      final model = AssignmentSubmissionModel.fromJson(json);
      expect(model.id, 'sub-123');
      expect(model.studentName, 'عمر خالد');
      expect(model.studentEmail, 'omar@example.com');
      expect(model.score, 95);
      expect(model.scorePercentage(100), 95.0);
      expect(model.status, SubmissionStatus.reviewed);
      expect(model.files.length, 1);
      expect(model.files.first.fileName, 'solution.pdf');

      final exported = model.toJson();
      expect(exported['id'], 'sub-123');
      expect(exported['score'], 95);
      expect(exported['teacher_feedback'], 'ممتاز جداً');
    });

    test('AssignmentModel.fromJson joins content & submissions metadata', () {
      final json = {
        'id': 'assign-1',
        'content_id': 'c-1',
        'tenant_id': 't-1',
        'instructions': 'حل الأسئلة من 1 إلى 5',
        'due_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'allow_late_submission': true,
        'max_score': 50,
        'created_at': '2026-09-08T10:00:00.000Z',
        'updated_at': '2026-09-08T10:00:00.000Z',
        'submissions_count': 12,
        'reviewed_count': 8,
        'content': {
          'id': 'c-1',
          'title': 'واجب التفاضل والتكامل',
          'group_id': 'group-math-1',
          'groups': {'name': 'SAT Math Advanced'},
        },
      };

      final model = AssignmentModel.fromJson(json);
      expect(model.id, 'assign-1');
      expect(model.title, 'واجب التفاضل والتكامل');
      expect(model.groupId, 'group-math-1');
      expect(model.groupName, 'SAT Math Advanced');
      expect(model.submissionsCount, 12);
      expect(model.reviewedCount, 8);
      expect(model.allowLateSubmission, true);
      expect(model.maxScore, 50);
      expect(model.isOverdue, false);
    });
  });

  group('AssignmentsCubit Unit Tests', () {
    late FakeAssignmentsRepository fakeRepo;
    late AssignmentsCubit cubit;

    setUp(() {
      AppCache.assignments.clear();
      fakeRepo = FakeAssignmentsRepository();
      cubit = AssignmentsCubit(repository: fakeRepo);
    });

    tearDown(() {
      cubit.close();
      AppCache.assignments.clear();
    });

    test(
      'loadGroupAssignments succeeds and emits TeacherAssignmentsLoaded',
      () async {
        fakeRepo.mockAssignments = [
          AssignmentEntity(
            id: 'assign-1',
            contentId: 'content-1',
            tenantId: 'tenant-1',
            groupId: 'group-1',
            title: 'واجب الجبر',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            submissionsCount: 5,
            reviewedCount: 3,
          ),
        ];

        final expectedStates = [
          const AssignmentsLoading(),
          isA<TeacherAssignmentsLoaded>()
              .having((s) => s.groupId, 'groupId', 'group-1')
              .having((s) => s.assignments.length, 'assignments.length', 1),
        ];

        unawaited(expectLater(cubit.stream, emitsInOrder(expectedStates)));
        await cubit.loadGroupAssignments('group-1');
      },
    );

    test(
      'loadGroupAssignments emits AssignmentsError on repository failure',
      () async {
        fakeRepo.shouldFail = true;
        fakeRepo.failureMessage = 'فشل الاتصال بقاعدة البيانات';

        final expectedStates = [
          const AssignmentsLoading(),
          const AssignmentsError('فشل الاتصال بقاعدة البيانات'),
        ];

        unawaited(expectLater(cubit.stream, emitsInOrder(expectedStates)));
        await cubit.loadGroupAssignments('group-1');
      },
    );

    test(
      'loadStudentAssignments emits StudentAssignmentsLoaded when assignments exist',
      () async {
        fakeRepo.mockAssignments = [
          AssignmentEntity(
            id: 'assign-student-1',
            contentId: 'c-1',
            tenantId: 't-1',
            groupId: 'g-1',
            title: 'واجب الهندسة التحليلية',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        final expectedStates = [
          const AssignmentsLoading(),
          isA<StudentAssignmentsLoaded>().having(
            (s) => s.assignments.length,
            'assignments.length',
            1,
          ),
        ];

        unawaited(expectLater(cubit.stream, emitsInOrder(expectedStates)));
        await cubit.loadStudentAssignments();
      },
    );

    test(
      'loadStudentAssignments emits AssignmentsEmpty when no assignments exist',
      () async {
        fakeRepo.mockAssignments = [];

        final expectedStates = [
          const AssignmentsLoading(),
          const AssignmentsEmpty(message: 'لا توجد واجبات مطلوبة حالياً'),
        ];

        unawaited(expectLater(cubit.stream, emitsInOrder(expectedStates)));
        await cubit.loadStudentAssignments();
      },
    );

    test(
      'gradeSubmission updates submission and reviewedCount in state',
      () async {
        final initialAssignment = AssignmentEntity(
          id: 'assign-1',
          contentId: 'c-1',
          tenantId: 't-1',
          groupId: 'g-1',
          title: 'واجب المصفوفات',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          reviewedCount: 0,
        );

        final initialSub = AssignmentSubmissionEntity(
          id: 'sub-1',
          assignmentId: 'assign-1',
          studentId: 'st-1',
          studentName: 'محمود حسن',
          submittedAt: DateTime.now(),
          status: SubmissionStatus.submitted,
        );

        fakeRepo.mockAssignments = [initialAssignment];
        fakeRepo.mockSubmissions = [initialSub];

        await cubit.loadGroupAssignments('g-1');
        await cubit.selectAssignmentForTeacher(initialAssignment);

        final success = await cubit.gradeSubmission(
          submissionId: 'sub-1',
          score: 90,
          feedback: 'عمل ممتاز وإجابات واضحة',
        );

        expect(success, true);
        final currentState = cubit.state;
        expect(currentState, isA<TeacherAssignmentsLoaded>());
        final loaded = currentState as TeacherAssignmentsLoaded;
        expect(loaded.submissions.first.score, 90);
        expect(loaded.submissions.first.status, SubmissionStatus.reviewed);
        expect(loaded.selectedAssignment?.reviewedCount, 1);
      },
    );

    test('submitAssignment uploads files and updates student state', () async {
      final assignment = AssignmentEntity(
        id: 'assign-sub-test',
        contentId: 'c-1',
        tenantId: 't-1',
        groupId: 'g-1',
        title: 'واجب الاحتمالات',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      fakeRepo.mockAssignments = [assignment];
      await cubit.loadStudentAssignments();

      final success = await cubit.submitAssignment(
        assignmentId: 'assign-sub-test',
        files: [
          (
            fileName: 'solution.pdf',
            bytes: [1, 2, 3],
            mimeType: 'application/pdf',
          ),
        ],
      );

      expect(success, true);
      final state = cubit.state as StudentAssignmentsLoaded;
      expect(state.assignments.first.mySubmission, isNotNull);
      expect(state.submitSuccess, true);
    });
  });

  group('Assignment Presentation Widget Tests', () {
    setUp(() {
      AppCache.assignments.clear();
    });

    testWidgets('AssignmentCard displays title, group, score, and badges', (
      tester,
    ) async {
      final assignment = AssignmentEntity(
        id: 'a1',
        contentId: 'c1',
        tenantId: 't1',
        groupId: 'g1',
        groupName: 'SAT Math Elite',
        title: 'تمارين الدوال المثلثية',
        instructions: 'يرجى حل المسائل 1 حتى 10 في ورقة خارجية ورفعها',
        maxScore: 100,
        submissionsCount: 10,
        reviewedCount: 7,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createTestApp(
          child: Scaffold(
            body: AssignmentCard(
              assignment: assignment,
              isTeacher: true,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('تمارين الدوال المثلثية'), findsOneWidget);
      expect(find.text('المجموعة: SAT Math Elite'), findsOneWidget);
      expect(find.text('100 درجة'), findsOneWidget);
      expect(find.text('التسليمات: 10 | تم التصحيح: 7'), findsOneWidget);
    });

    testWidgets(
      'SubmissionTile displays student name, status, and files count',
      (tester) async {
        final submission = AssignmentSubmissionEntity(
          id: 's1',
          assignmentId: 'a1',
          studentId: 'st1',
          studentName: 'يوسف شريف',
          attemptNumber: 2,
          submittedAt: DateTime(2026, 9, 8, 15, 30),
          status: SubmissionStatus.reviewed,
          score: 95,
          files: [
            SubmissionFileEntity(
              id: 'f1',
              submissionId: 's1',
              storagePath: 'p1',
              fileName: 'answers.pdf',
              mimeType: 'application/pdf',
              fileSize: 1024 * 50,
              createdAt: DateTime.now(),
            ),
          ],
        );

        await tester.pumpWidget(
          createTestApp(
            child: Scaffold(
              body: SubmissionTile(
                submission: submission,
                maxScore: 100,
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('يوسف شريف'), findsOneWidget);
        expect(find.text('محاولة 2'), findsOneWidget);
        expect(find.text('تم التصحيح والتقييم'), findsOneWidget);
        expect(find.text('95/100'), findsOneWidget);
        expect(find.text('1 ملفات مرفقة'), findsOneWidget);
      },
    );

    testWidgets(
      'GradeSubmissionPage renders student details and grading form',
      (tester) async {
        final fakeRepo = FakeAssignmentsRepository();
        final cubit = AssignmentsCubit(repository: fakeRepo);

        final assignment = AssignmentEntity(
          id: 'a1',
          contentId: 'c1',
          tenantId: 't1',
          groupId: 'g1',
          title: 'اختبار نصف الفصل',
          maxScore: 100,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        final submission = AssignmentSubmissionEntity(
          id: 'sub-grade-1',
          assignmentId: 'a1',
          studentId: 'st1',
          studentName: 'كريم محمود',
          studentEmail: 'karim@example.com',
          attemptNumber: 1,
          submittedAt: DateTime(2026, 9, 8, 14, 0),
          status: SubmissionStatus.submitted,
        );

        await tester.pumpWidget(
          createTestApp(
            child: BlocProvider.value(
              value: cubit,
              child: GradeSubmissionPage(
                assignment: assignment,
                submission: submission,
              ),
            ),
          ),
        );

        expect(find.text('تقييم تسليم الطالب'), findsOneWidget);
        expect(find.text('كريم محمود'), findsOneWidget);
        expect(find.text('karim@example.com'), findsOneWidget);
        expect(find.text('بانتظار التصحيح'), findsOneWidget);
        expect(find.text('الدرجة المستحقة (من 100)'), findsOneWidget);
        expect(find.text('حفظ التقييم وإشعار الطالب'), findsOneWidget);
      },
    );

    testWidgets(
      'StudentAssignmentsPage renders empty state when no assignments',
      (tester) async {
        final fakeRepo = FakeAssignmentsRepository();
        fakeRepo.mockAssignments = [];
        final cubit = AssignmentsCubit(repository: fakeRepo);

        await tester.pumpWidget(
          createTestApp(
            child: BlocProvider.value(
              value: cubit,
              child: const StudentAssignmentsPage(),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('واجباتي المدرسية'), findsOneWidget);
        expect(find.text('لا توجد واجبات مطلوبة حالياً'), findsOneWidget);
      },
    );

    testWidgets(
      'TeacherAssignmentsPage renders list of assignments and create button',
      (tester) async {
        final fakeRepo = FakeAssignmentsRepository();
        fakeRepo.mockAssignments = [
          AssignmentEntity(
            id: 't-a1',
            contentId: 'c1',
            tenantId: 't1',
            groupId: 'g-target',
            title: 'واجب المصفوفات والمحددات',
            maxScore: 100,
            submissionsCount: 4,
            reviewedCount: 2,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
        final cubit = AssignmentsCubit(repository: fakeRepo);

        await tester.pumpWidget(
          createTestApp(
            child: BlocProvider.value(
              value: cubit,
              child: const TeacherAssignmentsPage(
                groupId: 'g-target',
                groupName: 'SAT Group A',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('واجبات: SAT Group A'), findsOneWidget);
        expect(find.text('واجب المصفوفات والمحددات'), findsOneWidget);
        expect(find.text('إنشاء واجب'), findsOneWidget);
      },
    );

    testWidgets(
      'TeacherAssignmentsPage opens submissions sheet on card tap without error',
      (tester) async {
        final fakeRepo = FakeAssignmentsRepository();
        final assignment = AssignmentEntity(
          id: 't-a1',
          contentId: 'c1',
          tenantId: 't1',
          groupId: 'g-target',
          title: 'واجب المصفوفات والمحددات',
          maxScore: 100,
          submissionsCount: 1,
          reviewedCount: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        fakeRepo.mockAssignments = [assignment];
        fakeRepo.mockSubmissions = [
          AssignmentSubmissionEntity(
            id: 'sub-1',
            assignmentId: 't-a1',
            studentId: 'student-1',
            studentName: 'أحمد محمود',
            attemptNumber: 1,
            submittedAt: DateTime.now(),
            status: SubmissionStatus.submitted,
            score: null,
            files: const [],
          ),
        ];
        final cubit = AssignmentsCubit(repository: fakeRepo);

        await tester.pumpWidget(
          createTestApp(
            child: BlocProvider.value(
              value: cubit,
              child: const TeacherAssignmentsPage(
                groupId: 'g-target',
                groupName: 'SAT Group A',
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('واجب المصفوفات والمحددات'), findsOneWidget);

        // Tap the assignment card
        await tester.tap(find.text('واجب المصفوفات والمحددات'));
        await tester.pumpAndSettle();

        // Verify the submissions sheet opened and displays student name, NOT an error widget
        expect(find.text('أحمد محمود'), findsOneWidget);
        expect(find.text('An error occurred displaying content'), findsNothing);
      },
    );
  });
}
