import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/widgets/app_state_switcher.dart';

void main() {
  group('AppStateSwitcher Widget Tests', () {
    testWidgets('renders active child immediately', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppStateSwitcher(
              child: Text('Loading State', key: ValueKey('loading')),
            ),
          ),
        ),
      );

      expect(find.text('Loading State'), findsOneWidget);
    });

    testWidgets('smoothly transitions to new state when key changes', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppStateSwitcher(
              child: Text('Initial State', key: ValueKey('state_1')),
            ),
          ),
        ),
      );

      expect(find.text('Initial State'), findsOneWidget);

      // Change to new state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppStateSwitcher(
              child: Text('Loaded Content', key: ValueKey('state_2')),
            ),
          ),
        ),
      );

      // Mid-transition pump (both children in tree)
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Loaded Content'), findsOneWidget);

      // Finish transition
      await tester.pumpAndSettle();
      expect(find.text('Loaded Content'), findsOneWidget);
      expect(find.text('Initial State'), findsNothing);
    });
  });
}
