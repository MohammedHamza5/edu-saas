import 'package:edu_saas/core/errors/failures.dart';
import 'package:edu_saas/core/errors/result.dart';
import 'package:edu_saas/core/localization/generated/app_localizations.dart';
import 'package:edu_saas/core/theme/app_theme.dart';
import 'package:edu_saas/core/theme/tenant_theme_cubit.dart';
import 'package:edu_saas/features/auth/domain/entities/user_entity.dart';
import 'package:edu_saas/features/auth/domain/repositories/auth_repository.dart';
import 'package:edu_saas/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:edu_saas/features/auth/presentation/pages/login_page.dart';
import 'package:edu_saas/core/localization/locale_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class MockAuthRepository implements AuthRepository {
  @override
  Future<Result<UserEntity>> signInWithEmail({required String email, required String password}) async {
    return const FailureResult(AuthFailure('test'));
  }
  @override
  Future<Result<UserEntity>> signUpStudent({required String email, required String password, required String fullName, required String phone, String? parentPhone, required String tenantId}) async {
    return const FailureResult(AuthFailure('test'));
  }
  @override
  Future<Result<UserEntity?>> getCurrentUser() async => const Success(null);
  @override
  Future<Result<void>> signOut() async => const Success(null);
  @override
  Future<Result<void>> resetPasswordForEmail(String email) async => const Success(null);
}

void main() {
  testWidgets('LoginPage renders on desktop (1440x900) without crashing', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authCubit = AuthCubit(repository: MockAuthRepository());
    final themeCubit = TenantThemeCubit();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<TenantThemeCubit>.value(value: themeCubit),
          BlocProvider<LocaleCubit>(create: (_) => LocaleCubit()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: const LoginPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('دخول'), findsOneWidget);
  });
}
