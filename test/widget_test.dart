import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/localization/locale_cubit.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/theme/tenant_theme_cubit.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/domain/repositories/auth_repository.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/dashboard/presentation/pages/splash_page.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _MockAuthRepo implements AuthRepository {
  @override
  Future<Result<UserEntity?>> getCurrentUser() async => const Success(null);
  @override
  Future<Result<UserEntity>> signInWithEmail({required String email, required String password}) async =>
      const Success(UserEntity(
        id: 'u1',
        email: 'test@example.com',
        fullName: 'Test Student',
        role: UserRole.student,
        tenantId: 'd3b07384-d113-460b-8d14-04666f77ecfa',
        status: UserStatus.active,
      ));
  @override
  Future<Result<UserEntity>> signUpStudent({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    String? parentPhone,
    required String tenantId,
  }) async =>
      const Success(UserEntity(
        id: 'u1',
        email: 'test@example.com',
        fullName: 'Test Student',
        role: UserRole.student,
        tenantId: 'd3b07384-d113-460b-8d14-04666f77ecfa',
        status: UserStatus.pending,
      ));
  @override
  Future<Result<void>> signOut() async => const Success(null);
  @override
  Future<Result<void>> resetPasswordForEmail(String email) async => const Success(null);
}

void main() {
  testWidgets('App boots and renders splash page with Dr. Antounios branding cleanly', (WidgetTester tester) async {
    final authCubit = AuthCubit(repository: _MockAuthRepo());
    final themeCubit = TenantThemeCubit();
    final localeCubit = LocaleCubit();

    final testRouter = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const Scaffold(body: Text('Login Screen')),
        ),
        GoRoute(
          path: '/student',
          builder: (context, state) => const Scaffold(body: Text('Student Screen')),
        ),
        GoRoute(
          path: '/teacher',
          builder: (context, state) => const Scaffold(body: Text('Teacher Screen')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<TenantThemeCubit>.value(value: themeCubit),
          BlocProvider<LocaleCubit>.value(value: localeCubit),
        ],
        child: MaterialApp.router(
          routerConfig: testRouter,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar'), Locale('en')],
          locale: const Locale('ar'),
          theme: AppTheme.fromBranding(themeCubit.state),
        ),
      ),
    );

    expect(find.byType(SplashPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}

