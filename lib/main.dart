import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/di/injection_container.dart';
import 'core/localization/generated/app_localizations.dart';
import 'core/localization/locale_cubit.dart';
import 'core/network/supabase_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/tenant_branding.dart';
import 'core/theme/tenant_theme_cubit.dart';
import 'core/utils/app_bloc_observer.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/ui_error_tracker.dart';
import 'core/utils/url_strategy.dart';
import 'core/widgets/app_ui_error_widget.dart';
import 'core/widgets/global_activity_listener.dart';
import 'features/auth/presentation/cubit/auth_cubit.dart';
import 'features/groups/presentation/cubit/groups_cubit.dart';
import 'features/notifications/presentation/cubit/notifications_cubit.dart';
import 'features/students/presentation/cubit/students_cubit.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'features/videos/presentation/cubit/video_bank_cubit.dart';

Future<void> main() async {
  // ── 0. Enable HTML5 Clean Path URLs before engine binding initializes ────────
  configureUrlStrategy();

  // ── 1. Flutter engine binding ────────────────────────────────────────────────
  WidgetsFlutterBinding.ensureInitialized();

  // ── 2. Load .env ─────────────────────────────────────────────────────────────
  try {
    await dotenv.load(fileName: '.env');
  } catch (e, st) {
    AppLogger.w('Main', '.env not found — using fallback config', data: e);
    if (kDebugMode) AppLogger.d('Main', 'dotenv error detail', data: st);
  }

  final sentryDsn = dotenv.get(
    'SENTRY_DSN',
    fallback:
        'https://5ecbd6c0805a91b31f1709e1c68f4e2a@o4512255132434432.ingest.de.sentry.io/4512255144886352',
  );

  await SentryFlutter.init(
    (options) {
      options.dsn = sentryDsn;
      options.tracesSampleRate = 1.0;
      options.environment = kReleaseMode ? 'production' : 'development';
      options.sendDefaultPii = false;
    },
    appRunner: () async {
      AppLogger.separator('🚀 EduSaaS App Startup');
      AppLogger.i(
        'Main',
        'Flutter binding initialized, Sentry active & Clean Path URLs enabled',
      );

      // ── 3. Register global BlocObserver (Debug Only) ────────────────────────
      if (kDebugMode) {
        Bloc.observer = const AppBlocObserver();
        AppLogger.i('Main', 'BlocObserver registered');
      }

      // ── 4. Precision UI Error Tracking & Custom In-App Error Builder ──────────
      FlutterError.onError = (FlutterErrorDetails details) {
        if (kDebugMode) {
          UiErrorTracker.track(details);
          FlutterError.presentError(details);
        }
        Sentry.captureException(
          details.exception,
          stackTrace: details.stack,
        );
      };

      // Custom in-app error card replacing the blank red/grey crash screen
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return AppUiErrorWidget(details: details);
      };
      AppLogger.i(
        'Main',
        'Precision UI Error Tracker & ErrorWidget.builder active',
      );

      // ── 5. Initialize Supabase ────────────────────────────────────────────────
      try {
        await SupabaseService.initialize();
        AppLogger.s('Main', 'Supabase initialized successfully');
        AppLogger.d(
          'Main',
          'Supabase client ready',
          data: {
            'isAuthenticated': SupabaseService.isAuthenticated,
            'currentUserId':
                SupabaseService.currentUserId ?? 'null (no session)',
          },
        );
      } catch (e, st) {
        AppLogger.e(
          'Main',
          'Supabase initialization FAILED',
          error: e,
          stackTrace: st,
        );
        await Sentry.captureException(e, stackTrace: st);
      }

      // ── 6. Initialize Dependency Injection ───────────────────────────────────
      try {
        await InjectionContainer.init();
        AppLogger.s(
          'Main',
          'DI container initialized — all repositories ready',
        );
      } catch (e, st) {
        AppLogger.e(
          'Main',
          'DI container initialization FAILED',
          error: e,
          stackTrace: st,
        );
        await Sentry.captureException(e, stackTrace: st);
      }

      AppLogger.separator('🎬 Running App');
      runApp(const EduSaaSApp());
    },
  );
}

class EduSaaSApp extends StatelessWidget {
  const EduSaaSApp({super.key});

  @override
  Widget build(BuildContext context) {
    AppLogger.d('EduSaaSApp', 'Building root widget tree');
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(
          create: (_) {
            AppLogger.d('DI', 'Creating AuthCubit and checking auth status');
            return InjectionContainer.createAuthCubit()..checkAuthStatus();
          },
        ),
        BlocProvider<GroupsCubit>(
          create: (_) {
            AppLogger.d('DI', 'Creating GroupsCubit');
            return InjectionContainer.createGroupsCubit();
          },
        ),
        BlocProvider<NotificationsCubit>(
          create: (_) {
            AppLogger.d('DI', 'Creating NotificationsCubit');
            return InjectionContainer.createNotificationsCubit();
          },
        ),
        BlocProvider<StudentsCubit>(
          create: (_) {
            AppLogger.d('DI', 'Creating StudentsCubit (root)');
            return InjectionContainer.createStudentsCubit();
          },
        ),
        BlocProvider<VideoBankCubit>(
          create: (_) {
            AppLogger.d('DI', 'Creating VideoBankCubit (root)');
            return InjectionContainer.createVideoBankCubit();
          },
        ),
        BlocProvider<TenantThemeCubit>(
          create: (_) {
            AppLogger.d('DI', 'Creating TenantThemeCubit');
            return InjectionContainer.createTenantThemeCubit();
          },
        ),
        BlocProvider<LocaleCubit>(
          create: (_) {
            AppLogger.d('DI', 'Creating LocaleCubit');
            return InjectionContainer.createLocaleCubit();
          },
        ),
      ],
      child: const _AppRootView(),
    );
  }
}

class _AppRootView extends StatelessWidget {
  const _AppRootView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TenantThemeCubit, TenantBranding>(
      builder: (context, branding) {
        return BlocBuilder<LocaleCubit, Locale>(
          builder: (context, activeLocale) {
            return MaterialApp.router(
              title: activeLocale.languageCode == 'ar'
                  ? '${branding.brandName} | SAT • EST • ACT'
                  : '${branding.brandNameEn ?? branding.brandName} | American Curriculum SAT • EST • ACT',
              theme: AppTheme.fromBranding(branding),
              routerConfig: AppRouter.router,
              debugShowCheckedModeBanner: false,
              locale: activeLocale,
              builder: (context, child) =>
                  GlobalActivityListener(child: child ?? const SizedBox()),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            );
          },
        );
      },
    );
  }
}
