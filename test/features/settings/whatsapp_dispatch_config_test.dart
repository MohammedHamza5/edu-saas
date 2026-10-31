import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/settings/domain/entities/whatsapp_dispatch_config_entity.dart';

void main() {
  group('WhatsAppDispatchConfigEntity Tests', () {
    test('Default configuration has valid templates and targets', () {
      const config = WhatsAppDispatchConfigEntity.defaultConfiguration;

      expect(config.recipientTarget, WhatsAppRecipientTarget.parentOnly);
      expect(config.dispatchTiming, WhatsAppDispatchTiming.instant);
      expect(config.headerTemplate.contains('{student_name}'), isTrue);
      expect(config.bodyTemplate.contains('{score}'), isTrue);
      expect(config.footerTemplate.contains('{teacher_name}'), isTrue);
    });

    test('renderLivePreview correctly substitutes tierExcellent for score >= 90%', () {
      const config = WhatsAppDispatchConfigEntity.defaultConfiguration;

      final rendered = config.renderLivePreview(
        studentName: 'عمر أحمد',
        examTitle: 'الجبر المتقدم',
        score: 48,
        maxScore: 50,
        percentage: 96.0,
        groupName: 'SAT Group A',
        teacherName: 'د. أنطونيوس',
      );

      expect(rendered.contains('عمر أحمد'), isTrue);
      expect(rendered.contains('الجبر المتقدم'), isTrue);
      expect(rendered.contains('48 من 50'), isTrue);
      expect(rendered.contains('96.0%'), isTrue);
      expect(rendered.contains(config.tierExcellentText), isTrue);
    });

    test('renderLivePreview correctly substitutes tierGood for score between 75% and 89%', () {
      const config = WhatsAppDispatchConfigEntity.defaultConfiguration;

      final rendered = config.renderLivePreview(
        studentName: 'سارة محمد',
        examTitle: 'الهندسة الفراغية',
        score: 40,
        maxScore: 50,
        percentage: 80.0,
        groupName: 'SAT Group B',
        teacherName: 'د. أنطونيوس',
      );

      expect(rendered.contains('سارة محمد'), isTrue);
      expect(rendered.contains(config.tierGoodText), isTrue);
    });

    test('renderLivePreview correctly substitutes tierPass for score between 60% and 74%', () {
      const config = WhatsAppDispatchConfigEntity.defaultConfiguration;

      final rendered = config.renderLivePreview(
        studentName: 'أحمد علي',
        examTitle: 'التفاضل والتكامل',
        score: 35,
        maxScore: 50,
        percentage: 70.0,
        groupName: 'SAT Group C',
        teacherName: 'د. أنطونيوس',
      );

      expect(rendered.contains('أحمد علي'), isTrue);
      expect(rendered.contains(config.tierPassText), isTrue);
    });

    test('renderLivePreview correctly substitutes tierNeedsImprovement for score < 60%', () {
      const config = WhatsAppDispatchConfigEntity.defaultConfiguration;

      final rendered = config.renderLivePreview(
        studentName: 'يوسف حسن',
        examTitle: 'ميكانيكا',
        score: 20,
        maxScore: 50,
        percentage: 40.0,
        groupName: 'SAT Group D',
        teacherName: 'د. أنطونيوس',
      );

      expect(rendered.contains('يوسف حسن'), isTrue);
      expect(rendered.contains(config.tierNeedsImprovementText), isTrue);
    });

    test('Recipient target and dispatch timing enum mappings', () {
      expect(WhatsAppRecipientTarget.fromDbValue('parent_only'), WhatsAppRecipientTarget.parentOnly);
      expect(WhatsAppRecipientTarget.fromDbValue('student_only'), WhatsAppRecipientTarget.studentOnly);
      expect(WhatsAppRecipientTarget.fromDbValue('both'), WhatsAppRecipientTarget.both);
      expect(WhatsAppRecipientTarget.parentOnly.toDbValue(), 'parent_only');

      expect(WhatsAppDispatchTiming.fromDbValue('instant'), WhatsAppDispatchTiming.instant);
      expect(WhatsAppDispatchTiming.fromDbValue('exam_end'), WhatsAppDispatchTiming.examEnd);
      expect(WhatsAppDispatchTiming.instant.toDbValue(), 'instant');
    });
  });
}
