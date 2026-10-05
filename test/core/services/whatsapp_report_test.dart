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

    group('Natural Online WhatsApp Reports (Zero Physical Attendance)', () {
      test('generateNaturalWeeklyReport omits missing homework and exam metrics completely', () {
        // Online scenario: No homework was assigned, no mock exam taken
        final report = WhatsAppReportGenerator.generateNaturalWeeklyReport(
          studentName: 'زياد طارق',
          groupName: 'SAT Advanced',
          videoWatchRate: 1.0,
          totalAssignments: 0,
          completedAssignments: 0,
          mockExamScore: 0,
          activeStudyMinutes: 75,
        );

        // Friendly, warm tone
        expect(report, contains('أهلاً بحضرتك يا فندم 🌸'));
        expect(report, contains('زياد طارق'));
        expect(report, contains('SAT Advanced'));

        // Videos present (100% watched)
        expect(report, contains('🎬 شاف كل فيديوهات ومحاضرات الأسبوع ده بالكامل.'));

        // Active study time formatted in hours
        expect(report, contains('⏱️ وقت مذاكرته وتفاعله على المنصة: حوالي 1.3 ساعة.'));

        // Strictly NO homework or exam lines when missing / zero
        expect(report.contains('📝'), isFalse);
        expect(report.contains('واجب'), isFalse);
        expect(report.contains('تدريبات'), isFalse);
        expect(report.contains('🎯'), isFalse);
        expect(report.contains('سكور'), isFalse);
        expect(report.contains('امتحان'), isFalse);
      });

      test('generateNaturalWeeklyReport formats all active metrics when available', () {
        final report = WhatsAppReportGenerator.generateNaturalWeeklyReport(
          studentName: 'سارة خالد',
          groupName: 'EST 101',
          videoWatchRate: 0.80,
          totalAssignments: 4,
          completedAssignments: 4,
          mockExamScore: 720,
          targetScore: 800,
          activeStudyMinutes: 45,
          teacherNotes: 'حل رائع وتطور ملحوظ في مسائل الهندسة.',
          teacherName: 'د. أنطونيوس أشرف',
        );

        expect(report, contains('أهلاً بحضرتك يا فندم 🌸'));
        expect(report, contains('سارة خالد'));
        expect(report, contains('🎬 شاف 80% من شروحات ومحاضرات الأسبوع ده.'));
        expect(report, contains('⏱️ وقت مذاكرته وتفاعله على المنصة: حوالي 45 دقيقة.'));
        expect(report, contains('📝 سلّم كل واجبات وتدريبات الأسبوع ده في موعدها.'));
        expect(report, contains('🎯 سكور الكويز/الامتحان الأخير: 720 من 800.'));
        expect(report, contains('💡 ملاحظة:\nحل رائع وتطور ملحوظ في مسائل الهندسة.'));
        expect(report, contains('د. أنطونيوس أشرف'));
      });

      test('generateNaturalMonthlyReport omits missing metrics and formats monthly summary', () {
        final report = WhatsAppReportGenerator.generateNaturalMonthlyReport(
          studentName: 'يوسف إبراهيم',
          groupName: 'SAT Math',
          videoWatchRate: 0.95,
          totalAssignments: 8,
          completedAssignments: 6,
          mockExamScore: 710,
          targetScore: 800,
          activeStudyMinutes: 360, // 6 hours
          teacherNotes: 'الاستمرار بنفس العزيمة سيضمن الـ 750+ بإذن الله.',
        );

        expect(report, contains('أهلاً بحضرتك يا فندم 🌸'));
        expect(report, contains('ملخص مجهوده معانا خلال الشهر ده في SAT Math:'));
        expect(report, contains('📚 أتم بنجاح كل محاضرات وكورسات الشهر ده بالكامل.'));
        expect(report, contains('⏱️ إجمالي ساعات مذاكرته وتفاعله على المنصة: حوالي 6 ساعة.'));
        expect(report, contains('📝 إجمالي الواجبات المُسلّمة: 6 من أصل 8 واجب.'));
        expect(report, contains('🎯 متوسط درجاته في امتحانات وتدريبات الشهر: 710 من 800.'));
        expect(report, contains('💡 تقييم وتوصية المدرس للشهر القادم:'));
        expect(report, contains('فخورين بالتزامه وماشيين معاه خطوة بخطوة'));
      });

      test('generateNaturalMonthlyReport omits homework when no homework assigned in the month', () {
        final report = WhatsAppReportGenerator.generateNaturalMonthlyReport(
          studentName: 'نور الدين',
          groupName: 'Algebra Foundations',
          videoWatchRate: 0.60,
          totalAssignments: 0,
          completedAssignments: 0,
          mockExamScore: 0,
        );

        expect(report, contains('نور الدين'));
        expect(report, contains('📚 نسبة إنجازه للمحاضرات والشروحات الشهر ده: 60%.'));
        expect(report.contains('📝'), isFalse);
        expect(report.contains('واجب'), isFalse);
        expect(report.contains('🎯'), isFalse);
      });
    });
  });
}
