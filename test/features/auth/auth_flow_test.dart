import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/theme/tenant_theme_cubit.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/domain/repositories/auth_repository.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_state.dart';
import 'package:edu_saas/core/network/supabase_service.dart';
import 'package:edu_saas/features/auth/presentation/pages/student_pending_page.dart';
import 'package:edu_saas/features/auth/presentation/pages/login_page.dart';
import 'package:edu_saas/features/auth/presentation/pages/register_student_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAuthRepository implements AuthRepository {
  UserEntity? currentUser;
  bool throwTenantSuspended = false;
  bool throwInvalidCredentials = false;

  @override
  Future<Result<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (throwTenantSuspended) {
      return const FailureResult(
        AuthFailure('TENANT_SUSPENDED', code: 'TENANT_SUSPENDED'),
      );
    }
    if (throwInvalidCredentials) {
      return const FailureResult(AuthFailure('Invalid login credentials'));
    }
    final user =
        currentUser ??
        const UserEntity(
          id: 'test-user-id',
          tenantId: '11111111-1111-1111-1111-111111111111',
          role: UserRole.student,
          fullName: 'Test Student',
          email: 'student@example.com',
          status: UserStatus.active,
        );
    return Success(user);
  }

  @override
  Future<Result<UserEntity>> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? parentPhone,
    required String tenantId,
  }) async {
    final user = UserEntity(
      id: 'new-student-id',
      tenantId: tenantId,
      role: UserRole.student,
      fullName: fullName,
      email: email,
      phone: phone,
      parentPhone: parentPhone,
      status: UserStatus.pending,
    );
    return Success(user);
  }

  @override
  Future<Result<UserEntity?>> getCurrentUser() async {
    return Success(currentUser);
  }

  @override
  Future<Result<void>> signOut() async {
    currentUser = null;
    return const Success(null);
  }

  @override
  Future<Result<void>> resetPasswordForEmail(String email) async {
    return const Success(null);
  }
}

void main() {
  late FakeAuthRepository fakeRepo;
  late AuthCubit authCubit;

  setUp(() {
    fakeRepo = FakeAuthRepository();
    authCubit = AuthCubit(repository: fakeRepo);
  });

  tearDown(() {
    authCubit.close();
  });

  group('AuthCubit State Transitions', () {
    test('initial state is AuthInitial', () {
      expect(authCubit.state, const AuthInitial());
    });

    test(
      'checkAuthStatus emits AuthUnauthenticated when no user is logged in',
      () async {
        fakeRepo.currentUser = null;
        await authCubit.checkAuthStatus();
        expect(authCubit.state, const AuthUnauthenticated());
      },
    );

    test(
      'login with valid student credentials emits AuthAuthenticated',
      () async {
        fakeRepo.currentUser = const UserEntity(
          id: 'student-id',
          tenantId: '11111111-1111-1111-1111-111111111111',
          role: UserRole.student,
          fullName: 'Omar',
          email: 'student@al-nour.edu',
          status: UserStatus.active,
        );

        await authCubit.login(
          email: 'student@al-nour.edu',
          password: 'Password123!',
        );
        expect(authCubit.state, isA<AuthAuthenticated>());
        final state = authCubit.state as AuthAuthenticated;
        expect(state.user.role, UserRole.student);
      },
    );

    test('login when tenant is suspended emits AuthTenantSuspended', () async {
      fakeRepo.throwTenantSuspended = true;
      await authCubit.login(
        email: 'user@suspended.edu',
        password: 'Password123!',
      );
      expect(authCubit.state, const AuthTenantSuspended());
    });

    test('registerStudent emits AuthPendingApproval', () async {
      await authCubit.registerStudent(
        email: 'new@student.com',
        password: 'Password123!',
        fullName: 'New Student (SAT)',
        phone: '+201000000000',
        tenantId: '11111111-1111-1111-1111-111111111111',
      );

      expect(authCubit.state, isA<AuthPendingApproval>());
      final state = authCubit.state as AuthPendingApproval;
      expect(state.user.status, UserStatus.pending);
    });
  });

  group('LoginPage Widget Tests', () {
    Widget createWidgetUnderTest() {
      final themeCubit = TenantThemeCubit();
      return MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<TenantThemeCubit>.value(value: themeCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: const LoginPage(),
        ),
      );
    }

    testWidgets('renders email, password fields and login button', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.byType(AppButton), findsOneWidget);
    });

    testWidgets(
      'shows validation error when fields are empty on login submit',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final appButton = find.byType(AppButton);
        await tester.ensureVisible(appButton);
        await tester.tap(appButton);
        await tester.pumpAndSettle();

        expect(find.text('يرجى إدخال بريد إلكتروني صحيح'), findsOneWidget);
      },
    );
  });

  group('RegisterStudentPage Tests', () {
    Widget createWidgetUnderTest() {
      final themeCubit = TenantThemeCubit();
      return MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<TenantThemeCubit>.value(value: themeCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: const RegisterStudentPage(),
        ),
      );
    }

    testWidgets('renders all registration input fields and submit button', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(RegisterStudentPage), findsOneWidget);
      expect(find.text('تسجيل طالب جديد'), findsOneWidget);
      expect(find.text('إنشاء الحساب وبدء التعلم ←'), findsOneWidget);
    });

    testWidgets('validates required fields on submit with empty inputs', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final submitBtn = find.text('إنشاء الحساب وبدء التعلم ←');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال اسم الطالب'), findsOneWidget);
    });
  });

  group('StudentPendingPage Widget & Security Tests', () {
    Widget createWidgetUnderTest() {
      final themeCubit = TenantThemeCubit();
      return MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<TenantThemeCubit>.value(value: themeCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: const StudentPendingPage(studentName: 'أحمد علي'),
        ),
      );
    }

    testWidgets('renders waiting icon, title, and both action buttons', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(find.text('الحساب قيد المراجعة والاعتماد'), findsOneWidget);
      expect(find.text('التحقق من حالة الحساب'), findsOneWidget);
      expect(find.text('العودة لتسجيل الدخول'), findsOneWidget);
    });

    testWidgets(
      'tapping check status button calls checkAuthStatus and displays pending feedback',
      (tester) async {
        fakeRepo.currentUser = const UserEntity(
          id: 'new-student-id',
          tenantId: '11111111-1111-1111-1111-111111111111',
          role: UserRole.student,
          fullName: 'أحمد علي',
          email: 'ahmed@example.com',
          status: UserStatus.pending,
        );

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        final checkStatusBtn = find.text('التحقق من حالة الحساب');
        await tester.ensureVisible(checkStatusBtn);
        await tester.tap(checkStatusBtn);
        await tester.pumpAndSettle();

        expect(
          find.text('حسابك لا يزال قيد مراجعة واعتماد المعلم، يرجى التحقق لاحقاً.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('tapping back to login calls logout and clears session', (
      tester,
    ) async {
      SupabaseService.currentRole = 'student';
      SupabaseService.currentStatus = 'pending';

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final backToLoginBtn = find.text('العودة لتسجيل الدخول');
      await tester.ensureVisible(backToLoginBtn);
      await tester.tap(backToLoginBtn);
      await tester.pumpAndSettle();

      expect(SupabaseService.currentUserRole, isNull);
      expect(SupabaseService.currentUserStatus, isNull);
      expect(authCubit.state, const AuthUnauthenticated());
    });
  });
}

