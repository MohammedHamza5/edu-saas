import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/widgets/responsive_container.dart';
import 'package:edu_saas/features/students/domain/entities/student_360_entity.dart';
import 'package:edu_saas/features/students/domain/entities/student_entity.dart';
import 'package:edu_saas/features/students/domain/repositories/students_repository.dart';
import 'package:edu_saas/features/students/presentation/cubit/students_cubit.dart';
import 'package:edu_saas/features/students/presentation/pages/student_360_page.dart';
import 'package:edu_saas/features/students/presentation/pages/students_list_page.dart';

class _FakeStudentsRepository implements StudentsRepository {
  final List<StudentEntity> students;
  final Student360Entity student360;

  _FakeStudentsRepository({
    required this.students,
    required this.student360,
  });

  @override
  Future<Result<List<StudentEntity>>> getStudents({
    String? status,
    String? searchQuery,
    int page = 0,
    int pageSize = 25,
  }) async {
    return Success(students);
  }

  @override
  Future<Result<List<StudentEntity>>> getPendingStudents() async {
    return Success(students.where((s) => s.isPending).toList());
  }

  @override
  Future<Result<StudentEntity>> changeStudentStatus({
    required String studentId,
    required String action,
  }) async {
    final s = students.firstWhere((e) => e.id == studentId);
    return Success(s);
  }

  @override
  Future<Result<Student360Entity>> getStudent360(String studentId) async {
    return Success(student360);
  }

  @override
  Future<Result<StudentEntity>> getStudent(String studentId) async {
    final s = students.firstWhere((e) => e.id == studentId);
    return Success(s);
  }

  @override
  Future<Result<void>> assignStudentToGroup({
    required String studentId,
    required String groupId,
    required bool add,
  }) async {
    return const Success(null);
  }

  @override
  Future<Result<List<StudentGroupInfo>>> getAvailableGroupsForStudent(
    String studentId,
  ) async {
    return const Success([]);
  }
}

void main() {
  final mockStudent = StudentEntity(
    id: 's-101',
    tenantId: 't-101',
    fullName: 'أحمد إبراهيم محمد الشريف',
    email: 'ahmed.sherif@example.com',
    phone: '+201012345678',
    status: 'active',
    createdAt: DateTime.now(),
  );

  final mockStudent360 = Student360Entity(
    studentId: 's-101',
    attendancePercentage: 92.5,
    assignmentsSubmitted: 18,
    assignmentsReviewed: 16,
    examAverage: 88.0,
    videoCompletionPercentage: 75.0,
    groups: [
      StudentGroupInfo(
        groupId: 'g-1',
        groupName: 'SAT Math Level 1 Advanced',
        groupLevel: 'SAT',
        joinedAt: DateTime.now(),
      ),
    ],
  );

  Widget createWidgetUnderTest(Widget child, _FakeStudentsRepository repo) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: BlocProvider<StudentsCubit>(
        create: (_) => StudentsCubit(repository: repo),
        child: child,
      ),
    );
  }

  group('StudentsListPage Multi-Device Responsive Tests', () {
    const testSizes = [
      Size(320, 640),   // Extra small mobile
      Size(390, 844),   // Standard mobile
      Size(768, 1024),  // Tablet portrait
      Size(1440, 900),  // Desktop
      Size(1920, 1080), // Full HD / 4K
    ];

    for (final size in testSizes) {
      testWidgets('Renders cleanly on screen size (${size.width.toInt()}x${size.height.toInt()}) with zero overflow', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeStudentsRepository(
          students: [mockStudent],
          student360: mockStudent360,
        );

        await tester.pumpWidget(createWidgetUnderTest(const StudentsListPage(), repo));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ResponsiveContainer), findsOneWidget);
        expect(find.text('إدارة الطلاب'), findsOneWidget);
        expect(find.text('أحمد إبراهيم محمد الشريف'), findsOneWidget);
      });
    }
  });

  group('Student360Page Multi-Device Responsive Tests', () {
    const testSizes = [
      Size(320, 640),   // Extra small mobile
      Size(390, 844),   // Standard mobile
      Size(768, 1024),  // Tablet portrait
      Size(1440, 900),  // Desktop
      Size(1920, 1080), // Full HD / 4K
    ];

    for (final size in testSizes) {
      testWidgets('Renders Student360 cleanly on screen size (${size.width.toInt()}x${size.height.toInt()}) with zero overflow', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeStudentsRepository(
          students: [mockStudent],
          student360: mockStudent360,
        );

        await tester.pumpWidget(
          createWidgetUnderTest(
            Student360Page(
              studentId: mockStudent.id,
              initialStudent: mockStudent,
            ),
            repo,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ResponsiveContainer), findsOneWidget);
        expect(find.text('نسبة الحضور'), findsOneWidget);
        expect(find.text('متوسط الامتحانات'), findsOneWidget);
      });
    }
  });
}
