import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/onboarding/domain/entities/provision_tenant_params.dart';
import 'package:edu_saas/features/onboarding/domain/entities/tenant_entity.dart';
import 'package:edu_saas/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:edu_saas/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:edu_saas/features/onboarding/presentation/cubit/onboarding_state.dart';
import 'package:edu_saas/features/onboarding/presentation/pages/platform_onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  List<TenantEntity> mockTenants = [];
  bool shouldFail = false;

  @override
  Future<Result<OnboardingResult>> provisionTenant(
      ProvisionTenantParams params) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('فشل إنشاء المستأجر والمعلم'));
    }

    final tenant = TenantEntity(
      id: 'tenant-${DateTime.now().millisecondsSinceEpoch}',
      name: params.tenantName,
      email: params.tenantEmail,
      phone: params.tenantPhone,
      logoUrl: params.logoUrl,
      status: 'active',
      createdAt: DateTime.now(),
    );

    mockTenants.add(tenant);

    final teacher = UserEntity(
      id: 'teacher-${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenant.id,
      role: UserRole.teacher,
      status: UserStatus.active,
      fullName: params.teacherFullName,
      email: params.teacherEmail,
      phone: params.teacherPhone,
    );

    return Success(OnboardingResult(tenant: tenant, teacher: teacher));
  }

  @override
  Future<Result<TenantEntity?>> getTenantById(String tenantId) async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Database error'));
    }
    final tenant = mockTenants.where((t) => t.id == tenantId).firstOrNull;
    return Success(tenant);
  }

  @override
  Future<Result<List<TenantEntity>>> listTenants() async {
    if (shouldFail) {
      return const FailureResult(ServerFailure('Failed to list tenants'));
    }
    return Success(List.from(mockTenants));
  }
}

void main() {
  late FakeOnboardingRepository fakeRepo;
  late OnboardingCubit cubit;

  setUp(() {
    fakeRepo = FakeOnboardingRepository();
    cubit = OnboardingCubit(repository: fakeRepo);
  });

  tearDown(() {
    cubit.close();
  });

  group('OnboardingCubit Unit Tests', () {
    test('initial state is OnboardingInitial', () {
      expect(cubit.state, const OnboardingInitial());
    });

    test('provisionTenant emits Loading then Success on success', () async {
      const params = ProvisionTenantParams(
        tenantName: 'Elite Math Academy',
        tenantEmail: 'info@elitemath.edu',
        teacherFullName: 'Dr. Ahmed Menshawy',
        teacherEmail: 'ahmed@elitemath.edu',
        teacherPassword: 'password123',
      );

      final expected = [
        isA<OnboardingLoading>(),
        isA<OnboardingSuccess>()
            .having((s) => s.result.tenant.name, 'name', 'Elite Math Academy')
            .having((s) => s.result.teacher.fullName, 'fullName', 'Dr. Ahmed Menshawy')
            .having((s) => s.result.teacher.role, 'role', UserRole.teacher)
            .having((s) => s.result.teacher.status, 'status', UserStatus.active),
      ];

      final expectation = expectLater(cubit.stream, emitsInOrder(expected));
      final success = await cubit.provisionTenant(params);
      await expectation;

      expect(success, isTrue);
    });

    test('provisionTenant emits Loading then Error on failure', () async {
      fakeRepo.shouldFail = true;

      const params = ProvisionTenantParams(
        tenantName: 'Elite Math Academy',
        teacherFullName: 'Dr. Ahmed Menshawy',
        teacherEmail: 'ahmed@elitemath.edu',
        teacherPassword: 'password123',
      );

      final expected = [
        isA<OnboardingLoading>(),
        isA<OnboardingError>().having(
            (s) => s.message, 'message', 'فشل إنشاء المستأجر والمعلم'),
      ];

      final expectation = expectLater(cubit.stream, emitsInOrder(expected));
      final success = await cubit.provisionTenant(params);
      await expectation;

      expect(success, isFalse);
    });

    test('loadTenants emits Loading then TenantsListLoaded', () async {
      fakeRepo.mockTenants = [
        const TenantEntity(
          id: 'tenant-1',
          name: 'First Academy',
        ),
      ];

      final expected = [
        isA<OnboardingLoading>(),
        isA<TenantsListLoaded>()
            .having((s) => s.tenants.length, 'length', 1)
            .having((s) => s.tenants.first.name, 'name', 'First Academy'),
      ];

      final expectation = expectLater(cubit.stream, emitsInOrder(expected));
      await cubit.loadTenants();
      await expectation;
    });

    test('reset emits OnboardingInitial', () {
      cubit.reset();
      expect(cubit.state, const OnboardingInitial());
    });
  });

  group('PlatformOnboardingPage Widget Tests', () {
    Widget createWidgetUnderTest(OnboardingCubit onboardingCubit) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: BlocProvider<OnboardingCubit>.value(
          value: onboardingCubit,
          child: const PlatformOnboardingPage(),
        ),
      );
    }

    testWidgets('renders all form fields and submit button', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(cubit));
      await tester.pumpAndSettle();

      expect(find.text('تهيئة مركز تعليمي جديد'), findsOneWidget);
      expect(find.text('بيانات المركز التعليمي (Tenant)'), findsOneWidget);
      expect(find.text('بيانات حساب المعلم الأول'), findsOneWidget);
      expect(find.text('اسم المركز أو الأكاديمية *'), findsOneWidget);
      expect(find.text('الاسم الكامل للمعلم *'), findsOneWidget);
      expect(find.text('البريد الإلكتروني لتسجيل الدخول *'), findsOneWidget);
      expect(find.text('كلمة المرور *'), findsOneWidget);
      expect(find.text('إنشاء وتهيئة المركز التعليمي'), findsOneWidget);
    });

    testWidgets('shows validation errors when submitting empty form',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(cubit));
      await tester.pumpAndSettle();

      // Tap submit without typing
      final submitBtn = find.text('إنشاء وتهيئة المركز التعليمي');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال اسم المركز التعليمي'), findsOneWidget);
      expect(find.text('يرجى إدخال اسم المعلم'), findsOneWidget);
      expect(find.text('يرجى إدخال بريد إلكتروني صحيح'), findsOneWidget);
    });

    testWidgets('shows success card when provisioning succeeds',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest(cubit));
      await tester.pumpAndSettle();

      // Trigger success state directly
      const mockResult = OnboardingResult(
        tenant: TenantEntity(
          id: 'tenant-12345',
          name: 'Al-Farouk Math Center',
        ),
        teacher: UserEntity(
          id: 'teacher-12345',
          tenantId: 'tenant-12345',
          role: UserRole.teacher,
          status: UserStatus.active,
          fullName: 'Mr. Farouk',
          email: 'farouk@math.edu',
        ),
      );

      cubit.emit(const OnboardingSuccess(mockResult));
      await tester.pumpAndSettle();

      expect(find.text('تمت تهيئة المركز وحساب المعلم بنجاح!'), findsOneWidget);
      expect(find.text('Al-Farouk Math Center'), findsOneWidget);
      expect(find.text('tenant-12345'), findsOneWidget);
      expect(find.text('Mr. Farouk'), findsOneWidget);
      expect(find.text('farouk@math.edu'), findsOneWidget);
      expect(find.text('الانتقال لتسجيل الدخول كمعلم'), findsOneWidget);
    });
  });
}
