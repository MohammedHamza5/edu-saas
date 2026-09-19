import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/core/config/app_config.dart';
import 'package:edu_saas/core/widgets/forensic_watermark_overlay.dart';
import 'package:edu_saas/features/exams/data/models/question_option_model.dart';

void main() {
  group('Material Security & Forensic Hardening Tests', () {
    test('AppConfig master secrets default to empty to prevent binary leakage', () {
      expect(AppConfig.bunnyApiKey, isEmpty);
      expect(AppConfig.bunnyTokenKey, isEmpty);
    });

    test('QuestionOptionModel safely handles stripped is_correct for student protection', () {
      final safeStudentJson = {
        'id': 'opt-123',
        'question_id': 'q-456',
        'option_text': '2x + 5 = 15',
        'sort_order': 1,
      };

      final model = QuestionOptionModel.fromJson(safeStudentJson);
      expect(model.id, equals('opt-123'));
      expect(model.optionText, equals('2x + 5 = 15'));
      expect(model.isCorrect, isNull);
    });

    testWidgets('ForensicWatermarkOverlay wraps child with IgnorePointer and renders student watermark', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForensicWatermarkOverlay(
              studentName: 'Ali Hassan',
              studentPhone: '+201012345678',
              studentId: 'std-789',
              child: SizedBox(
                width: 300,
                height: 200,
                child: Text('Protected Video Content'),
              ),
            ),
          ),
        ),
      );

      // Verify the child is present
      expect(find.text('Protected Video Content'), findsOneWidget);

      // Verify watermark text is rendered
      expect(find.textContaining('Ali Hassan'), findsWidgets);
      expect(find.textContaining('+201012345678'), findsWidgets);
      expect(find.textContaining('std-789'), findsWidgets);

      // Verify that IgnorePointer is active so user interactions reach the video player
      final ignorePointer = tester.widgetList<IgnorePointer>(find.byType(IgnorePointer));
      expect(ignorePointer.any((ip) => ip.ignoring == true), isTrue);
    });

    testWidgets('ForensicWatermarkOverlay when disabled returns child directly without watermark', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ForensicWatermarkOverlay(
              enabled: false,
              studentName: 'Ali Hassan',
              studentPhone: '+201012345678',
              child: Text('Unprotected Content'),
            ),
          ),
        ),
      );

      expect(find.text('Unprotected Content'), findsOneWidget);
      expect(find.textContaining('Ali Hassan'), findsNothing);
    });
  });
}
