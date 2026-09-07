import 'package:edu_saas/core/constants/app_constants.dart';
import 'package:edu_saas/core/di/injection_container.dart';
import 'package:edu_saas/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await InjectionContainer.init();
  });

  testWidgets('App boots and renders splash page cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(const EduSaaSApp());
    expect(find.byType(EduSaaSApp), findsOneWidget);

    // Pump past splash delay to complete timer cleanly
    await tester.pump(AppConstants.splashDelay);
    await tester.pumpAndSettle();
  });
}
