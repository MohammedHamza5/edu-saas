import 'package:edu_saas/core/utils/whatsapp_report_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WhatsAppReportGenerator Unit Tests', () {
    test('cleanPhoneNumber handles Egyptian standard numbers', () {
      expect(
        WhatsAppReportGenerator.cleanPhoneNumber('01012345678'),
        equals('201012345678'),
      );
      expect(
        WhatsAppReportGenerator.cleanPhoneNumber('01198765432'),
        equals('201198765432'),
      );
    });

    test('cleanPhoneNumber handles Arabic-Indic digits', () {
      expect(
        WhatsAppReportGenerator.cleanPhoneNumber('٠١٠١٢٣٤٥٦٧٨'),
        equals('201012345678'),
      );
    });

    test('cleanPhoneNumber cleans dashes, spaces, and international prefixes', () {
      expect(
        WhatsAppReportGenerator.cleanPhoneNumber('+20 101 234 5678'),
        equals('201012345678'),
      );
    });

    test('generateAbsenceNotice formats notice correctly', () {
      final notice = WhatsAppReportGenerator.generateAbsenceNotice(
        studentName: 'أحمد محمود',
        groupName: 'SAT Basics',
        sessionDate: '2026/10/05',
        teacherName: 'د. أنطونيوس أشرف',
      );

      expect(notice, contains('أحمد محمود'));
      expect(notice, contains('SAT Basics'));
      expect(notice, contains('2026/10/05'));
      expect(notice, contains('تغيب عن حضور حصة اليوم'));
    });

    test('generateExamResultReport formats score and percentage correctly', () {
      final report = WhatsAppReportGenerator.generateExamResultReport(
        studentName: 'مريم علي',
        examTitle: 'Algebra Mock 1',
        score: 75.0,
        maxScore: 80.0,
        percentage: 93.75,
        teacherNotes: 'أداء ممتاز في مسائل الجبر.',
        teacherName: 'د. أنطونيوس أشرف',
      );

      expect(report, contains('مريم علي'));
      expect(report, contains('Algebra Mock 1'));
      expect(report, contains('75.0'));
      expect(report, contains('80.0'));
      expect(report, contains('93.8%'));
      expect(report, contains('ممتاز جداً 🌟'));
      expect(report, contains('أداء ممتاز في مسائل الجبر.'));
    });

    test('generateStudentWeeklyReport formats comprehensive report accurately', () {
      final report = WhatsAppReportGenerator.generateStudentWeeklyReport(
        studentName: 'كريم سامح',
        groupName: 'EST Math 1',
        attendanceRate: 0.95,
        videoWatchRate: 0.88,
        completedAssignments: 5,
        totalAssignments: 6,
        mockExamScore: 92,
        targetScore: 100,
        activeStudyMinutes: 120,
        engagementQualityText: 'تفاعل ممتاز',
      );

      expect(report, contains('كريم سامح'));
      expect(report, contains('EST Math 1'));
      expect(report, contains('95%'));
      expect(report, contains('88%'));
      expect(report, contains('5 من أصل 6'));
      expect(report, contains('92 / 100'));
      expect(report, contains('120 دقيقة'));
    });
  });
}
