import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_saas/core/network/supabase_service.dart';
import 'package:edu_saas/core/router/app_router.dart';

void main() {
  setUp(() {
    SupabaseService.debugIsAuthenticated = null;
    SupabaseService.currentRole = null;
    SupabaseService.currentStatus = null;
  });

  tearDown(() {
    SupabaseService.debugIsAuthenticated = null;
    SupabaseService.currentRole = null;
    SupabaseService.currentStatus = null;
  });

  group('AppRouter Pending Student & Account Status Security Redirect Tests', () {
    Widget buildRouterHarness({required String initialLocation}) {
      final testRouter = GoRouter(
        initialLocation: initialLocation,
        redirect: AppRouter.redirectLogic,
        routes: [
          GoRoute(
            path: AppRoutes.splash,
            builder: (ctx, state) => const Scaffold(body: Text('Splash Page')),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (ctx, state) => const Scaffold(body: Text('Login Page')),
          ),
          GoRoute(
            path: AppRoutes.studentPending,
            builder: (ctx, state) => const Scaffold(body: Text('Pending Page')),
          ),
          GoRoute(
            path: AppRoutes.studentDashboard,
            builder: (ctx, state) => const Scaffold(body: Text('Student Dashboard')),
          ),
          GoRoute(
            path: AppRoutes.studentAssignments,
            builder: (ctx, state) => const Scaffold(body: Text('Student Assignments')),
          ),
          GoRoute(
            path: AppRoutes.teacherDashboard,
            builder: (ctx, state) => const Scaffold(body: Text('Teacher Dashboard')),
          ),
        ],
      );

      return MaterialApp.router(
        routerConfig: testRouter,
      );
    }

    testWidgets('unauthenticated user attempting to access /student is redirected to /login', (tester) async {
      SupabaseService.debugIsAuthenticated = false;

      await tester.pumpWidget(buildRouterHarness(initialLocation: AppRoutes.studentDashboard));
      await tester.pumpAndSettle();

      expect(find.text('Login Page'), findsOneWidget);
      expect(find.text('Student Dashboard'), findsNothing);
    });

    testWidgets('unauthenticated user attempting to access /student-pending is redirected to /login', (tester) async {
      SupabaseService.debugIsAuthenticated = false;

      await tester.pumpWidget(buildRouterHarness(initialLocation: AppRoutes.studentPending));
      await tester.pumpAndSettle();

      expect(find.text('Login Page'), findsOneWidget);
    });

    testWidgets('authenticated pending student trying to access /student is strictly locked out and redirected to /student-pending', (tester) async {
      SupabaseService.debugIsAuthenticated = true;
      SupabaseService.currentRole = 'student';
      SupabaseService.currentStatus = 'pending';

      await tester.pumpWidget(buildRouterHarness(initialLocation: AppRoutes.studentDashboard));
      await tester.pumpAndSettle();

      expect(find.text('Pending Page'), findsOneWidget);
      expect(find.text('Student Dashboard'), findsNothing);
    });

    testWidgets('authenticated pending student trying to access deep subroute /student/assignments is locked out and redirected to /student-pending', (tester) async {
      SupabaseService.debugIsAuthenticated = true;
      SupabaseService.currentRole = 'student';
      SupabaseService.currentStatus = 'pending';

      await tester.pumpWidget(buildRouterHarness(initialLocation: AppRoutes.studentAssignments));
      await tester.pumpAndSettle();

      expect(find.text('Pending Page'), findsOneWidget);
      expect(find.text('Student Assignments'), findsNothing);
    });

    testWidgets('authenticated pending student accessing /login is prevented from bypassing and kept at /student-pending', (tester) async {
      SupabaseService.debugIsAuthenticated = true;
      SupabaseService.currentRole = 'student';
      SupabaseService.currentStatus = 'pending';

      await tester.pumpWidget(buildRouterHarness(initialLocation: AppRoutes.login));
      await tester.pumpAndSettle();

      expect(find.text('Pending Page'), findsOneWidget);
      expect(find.text('Login Page'), findsNothing);
      expect(find.text('Student Dashboard'), findsNothing);
    });

    testWidgets('authenticated active student is allowed to enter /student', (tester) async {
      SupabaseService.debugIsAuthenticated = true;
      SupabaseService.currentRole = 'student';
      SupabaseService.currentStatus = 'active';

      await tester.pumpWidget(buildRouterHarness(initialLocation: AppRoutes.studentDashboard));
      await tester.pumpAndSettle();

      expect(find.text('Student Dashboard'), findsOneWidget);
    });

    testWidgets('authenticated active student hitting /student-pending is redirected forward to /student', (tester) async {
      SupabaseService.debugIsAuthenticated = true;
      SupabaseService.currentRole = 'student';
      SupabaseService.currentStatus = 'active';

      await tester.pumpWidget(buildRouterHarness(initialLocation: AppRoutes.studentPending));
      await tester.pumpAndSettle();

      expect(find.text('Student Dashboard'), findsOneWidget);
      expect(find.text('Pending Page'), findsNothing);
    });

    testWidgets('authenticated suspended student is locked out and redirected to /login', (tester) async {
      SupabaseService.debugIsAuthenticated = true;
      SupabaseService.currentRole = 'student';
      SupabaseService.currentStatus = 'suspended';

      await tester.pumpWidget(buildRouterHarness(initialLocation: AppRoutes.studentDashboard));
      await tester.pumpAndSettle();

      expect(find.text('Login Page'), findsOneWidget);
      expect(find.text('Student Dashboard'), findsNothing);
    });
  });
}
