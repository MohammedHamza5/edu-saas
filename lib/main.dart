import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/di/injection_container.dart';
import 'core/localization/generated/app_localizations.dart';
import 'core/network/supabase_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/groups/presentation/cubit/groups_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // Graceful fallback if .env is missing or in test environment
  }

  try {
    await SupabaseService.initialize();
  } catch (_) {
    // Safe initialization fallback for offline or unit tests
  }

  // Initialize Pure Dependency Injection Container
  await InjectionContainer.init();

  runApp(const EduSaaSApp());
}

class EduSaaSApp extends StatelessWidget {
  const EduSaaSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) => InjectionContainer.createAuthCubit()..checkAuthStatus(),
        ),
        BlocProvider<GroupsCubit>(
          create: (_) => InjectionContainer.createGroupsCubit(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Edu SaaS',
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
