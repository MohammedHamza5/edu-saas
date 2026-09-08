import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/domain/repositories/auth_repository.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_state.dart';
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
      return const FailureResult(AuthFailure('TENANT_SUSPENDED', code: 'TENANT_SUSPENDED'));
    }
    if (throwInvalidCredentials) {
      return const FailureResult(AuthFailure('Invalid login credentials'));
    }
    final user = currentUser ??
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
    required String tenantId,
  }) async {
    final user = UserEntity(
      id: 'new-student-id',
      tenantId: tenantId,
      role: UserRole.student,
      fullName: fullName,
      email: email,
      phone: phone,
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

    test('checkAuthStatus emits AuthUnauthenticated when no user is logged in', () async {
      fakeRepo.currentUser = null;
      await authCubit.checkAuthStatus();
      expect(authCubit.state, const AuthUnauthenticated());
    });

    test('login with valid student credentials emits AuthAuthenticated', () async {
      fakeRepo.currentUser = const UserEntity(
        id: 'student-id',
        tenantId: '11111111-1111-1111-1111-111111111111',
        role: UserRole.student,
        fullName: 'Omar',
        email: 'student@al-nour.edu',
        status: UserStatus.active,
      );

      await authCubit.login(email: 'student@al-nour.edu', password: 'Password123!');
      expect(authCubit.state, isA<AuthAuthenticated>());
      final state = authCubit.state as AuthAuthenticated;
      expect(state.user.role, UserRole.student);
    });

    test('login when tenant is suspended emits AuthTenantSuspended', () async {
      fakeRepo.throwTenantSuspended = true;
      await authCubit.login(email: 'user@suspended.edu', password: 'Password123!');
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
      return MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: const LoginPage(),
        ),
      );
    }

    testWidgets('renders email, password fields and login button', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('دخول'), findsOneWidget);
    });

    testWidgets('shows validation error when fields are empty on login submit', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.text('دخول'));
      await tester.pumpAndSettle();

      expect(find.text('يرجى إدخال بريد إلكتروني صحيح'), findsOneWidget);
    });
  });

  group('RegisterStudentPage American System Tracks Tests', () {
    Widget createWidgetUnderTest() {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('ar'),
        home: BlocProvider<AuthCubit>.value(
          value: authCubit,
          child: const RegisterStudentPage(),
        ),
      );
    }

    testWidgets('renders all American System track choice chips', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('SAT'), findsOneWidget);
      expect(find.text('EST'), findsOneWidget);
      expect(find.text('ACT'), findsOneWidget);
      expect(find.text('Basics'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
      expect(find.text('مخصص'), findsOneWidget);
    });

    testWidgets('tapping مخصص displays custom track input field', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Initially custom track field is not present
      expect(find.text('المسار أو المجموعة المخصصة'), findsNothing);

      // Scroll and Tap on 'مخصص' choice chip
      final customChip = find.text('مخصص');
      await tester.ensureVisible(customChip);
      await tester.tap(customChip);
      await tester.pumpAndSettle();

      // Custom track field is now visible
      expect(find.text('المسار أو المجموعة المخصصة'), findsOneWidget);
    });
  });
}
