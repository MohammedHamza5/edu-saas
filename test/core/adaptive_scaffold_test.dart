import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/widgets/adaptive_scaffold.dart';

void main() {
  final testDestinations = [
    const AdaptiveDestination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      label: 'الرئيسية',
    ),
    const AdaptiveDestination(
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups_rounded,
      label: 'المجموعات',
    ),
    const AdaptiveDestination(
      icon: Icons.school_outlined,
      selectedIcon: Icons.school_rounded,
      label: 'الطلاب',
    ),
  ];

  Widget buildTestWidget({
    required Size screenSize,
    int currentIndex = 0,
    ValueChanged<int>? onNavigationIndexChanged,
  }) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: screenSize),
        child: AdaptiveScaffold(
          currentIndex: currentIndex,
          destinations: testDestinations,
          onNavigationIndexChanged: onNavigationIndexChanged,
          sidebarHeader: const Text('Edu SaaS Platform'),
          sidebarFooter: const Text('Logout'),
          body: const Center(child: Text('Body Content')),
        ),
      ),
    );
  }

  group('AdaptiveScaffold Responsive Layout Tests', () {
    testWidgets('Renders NavigationBar on compact mobile (<600dp)', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(390, 844)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Body Content'), findsOneWidget);
    });

    testWidgets('Renders NavigationRail on medium tablet (600-839dp)', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(768, 1024)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.text('Body Content'), findsOneWidget);
    });

    testWidgets('Renders Permanent Sidebar on desktop (>=840dp)', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestWidget(screenSize: const Size(1440, 900)));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(NavigationRail), findsNothing);
      expect(find.text('Edu SaaS Platform'), findsOneWidget);
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('المجموعات'), findsOneWidget);
      expect(find.text('الطلاب'), findsOneWidget);
      expect(find.text('Logout'), findsOneWidget);
      expect(find.text('Body Content'), findsOneWidget);
    });

    testWidgets('Callback fires when clicking destination on desktop', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? selectedIndex;
      await tester.pumpWidget(
        buildTestWidget(
          screenSize: const Size(1200, 800),
          onNavigationIndexChanged: (idx) => selectedIndex = idx,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('المجموعات'));
      await tester.pump();

      expect(selectedIndex, 1);
    });

    testWidgets('Renders Categorized Sections with section headers on Desktop', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int? selectedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: AdaptiveScaffold(
              currentIndex: 0,
              onNavigationIndexChanged: (idx) => selectedIndex = idx,
              sections: const [
                AdaptiveSidebarSection(
                  title: 'القسم الأول',
                  destinations: [
                    AdaptiveDestination(icon: Icons.home, label: 'العنصر الأول'),
                  ],
                ),
                AdaptiveSidebarSection(
                  title: 'القسم الثاني',
                  destinations: [
                    AdaptiveDestination(icon: Icons.school, label: 'العنصر الثاني'),
                  ],
                ),
              ],
              body: const Text('Categorized Body'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('القسم الأول'), findsOneWidget);
      expect(find.text('العنصر الأول'), findsOneWidget);
      expect(find.text('القسم الثاني'), findsOneWidget);
      expect(find.text('العنصر الثاني'), findsOneWidget);

      await tester.tap(find.text('العنصر الثاني'));
      await tester.pump();
      expect(selectedIndex, 1);
    });
  });
}

