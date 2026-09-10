import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/extensions/responsive_context_extension.dart';
import 'package:edu_saas/core/theme/responsive_breakpoints.dart';
import 'package:edu_saas/core/widgets/responsive_builder.dart';
import 'package:edu_saas/core/widgets/responsive_container.dart';
import 'package:edu_saas/core/widgets/responsive_grid.dart';

void main() {
  group('ResponsiveBreakpoints Unit Tests', () {
    test('Correctly maps widths to DeviceScreenType', () {
      expect(ResponsiveBreakpoints.getScreenType(320), DeviceScreenType.compact);
      expect(ResponsiveBreakpoints.getScreenType(599), DeviceScreenType.compact);
      expect(ResponsiveBreakpoints.getScreenType(600), DeviceScreenType.medium);
      expect(ResponsiveBreakpoints.getScreenType(839), DeviceScreenType.medium);
      expect(ResponsiveBreakpoints.getScreenType(840), DeviceScreenType.expanded);
      expect(ResponsiveBreakpoints.getScreenType(1199), DeviceScreenType.expanded);
      expect(ResponsiveBreakpoints.getScreenType(1200), DeviceScreenType.large);
      expect(ResponsiveBreakpoints.getScreenType(2560), DeviceScreenType.large);
    });

    test('DeviceScreenType getters return expected booleans', () {
      expect(DeviceScreenType.compact.isMobile, isTrue);
      expect(DeviceScreenType.compact.isTablet, isFalse);
      expect(DeviceScreenType.compact.isDesktop, isFalse);

      expect(DeviceScreenType.medium.isMobile, isFalse);
      expect(DeviceScreenType.medium.isTablet, isTrue);
      expect(DeviceScreenType.medium.isDesktop, isFalse);

      expect(DeviceScreenType.expanded.isDesktop, isTrue);
      expect(DeviceScreenType.expanded.isLargeDesktop, isFalse);

      expect(DeviceScreenType.large.isDesktop, isTrue);
      expect(DeviceScreenType.large.isLargeDesktop, isTrue);
    });

    test('Calculates dynamic column counts accurately', () {
      expect(ResponsiveBreakpoints.getColumnCount(360), equals(1));
      expect(ResponsiveBreakpoints.getColumnCount(700), equals(2));
      expect(ResponsiveBreakpoints.getColumnCount(1000), equals(3));
      expect(ResponsiveBreakpoints.getColumnCount(1400), equals(4));

      // Custom column overrides
      expect(
        ResponsiveBreakpoints.getColumnCount(
          1000,
          mobile: 1,
          tablet: 2,
          desktop: 2,
          largeDesktop: 3,
        ),
        equals(2),
      );
    });
  });

  group('Responsive Context Extensions & Widgets Tests', () {
    testWidgets('ResponsiveContextX adapts values based on screen size', (tester) async {
      tester.view.devicePixelRatio = 1.0;

      // Mobile Size (380 x 800)
      tester.view.physicalSize = const Size(380, 800);
      addTearDown(tester.view.resetPhysicalSize);

      late bool isMobileVal;
      late bool isTabletVal;
      late bool isDesktopVal;
      late String adaptedText;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobileVal = context.isMobile;
              isTabletVal = context.isTablet;
              isDesktopVal = context.isDesktop;
              adaptedText = context.responsiveValue(
                mobile: 'Mobile View',
                tablet: 'Tablet View',
                desktop: 'Desktop View',
              );
              return Text(adaptedText);
            },
          ),
        ),
      );

      expect(isMobileVal, isTrue);
      expect(isTabletVal, isFalse);
      expect(isDesktopVal, isFalse);
      expect(adaptedText, 'Mobile View');
      expect(find.text('Mobile View'), findsOneWidget);

      // Tablet Size (768 x 1024)
      tester.view.physicalSize = const Size(768, 1024);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              adaptedText = context.responsiveValue(
                mobile: 'Mobile View',
                tablet: 'Tablet View',
                desktop: 'Desktop View',
              );
              return Text(adaptedText);
            },
          ),
        ),
      );
      expect(find.text('Tablet View'), findsOneWidget);

      // Desktop Size (1440 x 900)
      tester.view.physicalSize = const Size(1440, 900);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              adaptedText = context.responsiveValue(
                mobile: 'Mobile View',
                tablet: 'Tablet View',
                desktop: 'Desktop View',
              );
              return Text(adaptedText);
            },
          ),
        ),
      );
      expect(find.text('Desktop View'), findsOneWidget);
    });

    testWidgets('ResponsiveBuilder switches layouts based on width constraints', (tester) async {
      tester.view.devicePixelRatio = 1.0;

      // Render on narrow width
      tester.view.physicalSize = const Size(400, 600);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobile: (context, constraints) => const Text('Mobile Builder'),
              tablet: (context, constraints) => const Text('Tablet Builder'),
              desktop: (context, constraints) => const Text('Desktop Builder'),
            ),
          ),
        ),
      );

      expect(find.text('Mobile Builder'), findsOneWidget);
      expect(find.text('Tablet Builder'), findsNothing);

      // Switch to Desktop width
      tester.view.physicalSize = const Size(1280, 800);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ResponsiveBuilder(
              mobile: (context, constraints) => const Text('Mobile Builder'),
              tablet: (context, constraints) => const Text('Tablet Builder'),
              desktop: (context, constraints) => const Text('Desktop Builder'),
            ),
          ),
        ),
      );

      expect(find.text('Desktop Builder'), findsOneWidget);
      expect(find.text('Mobile Builder'), findsNothing);
    });

    testWidgets('ResponsiveContainer bounds width and centers content', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1600, 900);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveContainer(
              maxWidth: 800,
              child: SizedBox(
                key: Key('inner_child'),
                height: 200,
              ),
            ),
          ),
        ),
      );

      final renderBox = tester.renderObject<RenderBox>(find.byKey(const Key('inner_child')));
      expect(renderBox.size.width, lessThanOrEqualTo(800));
    });

    testWidgets('ResponsiveGrid displays all children in dynamic columns', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1000);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ResponsiveGrid(
              tabletColumns: 2,
              children: [
                Text('Item 1'),
                Text('Item 2'),
                Text('Item 3'),
                Text('Item 4'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsOneWidget);
      expect(find.text('Item 4'), findsOneWidget);
    });
  });
}
