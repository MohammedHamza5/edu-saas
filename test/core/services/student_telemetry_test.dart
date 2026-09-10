import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/students/domain/entities/student_360_entity.dart';
import 'package:edu_saas/core/utils/whatsapp_report_generator.dart';

void main() {
  group('Student360Entity Telemetry & Engagement Tests', () {
    test('Calculates active and idle minutes correctly from seconds', () {
      const entity = Student360Entity(
        studentId: 'student-123',
        todayActiveSeconds: 3600, // 60 minutes
        todayIdleSeconds: 1200, // 20 minutes
        totalActiveSeconds7d: 14400, // 240 minutes
        totalIdleSeconds7d: 3600, // 60 minutes
      );

      expect(entity.todayActiveMinutes, 60);
      expect(entity.todayIdleMinutes, 20);
      expect(entity.totalSessionMinutesToday, 80);
      expect(entity.totalActiveMinutes7d, 240);
      expect(entity.totalIdleMinutes7d, 60);
    });

    test('Classifies engagement quality accurately based on active ratio', () {
      // 1. High Engagement (Active Ratio >= 65%)
      const activeStudent = Student360Entity(
        studentId: 's1',
        todayActiveSeconds: 7000,
        todayIdleSeconds: 3000, // 70% active
      );
      expect(activeStudent.todayActiveRatio, closeTo(0.70, 0.01));
      expect(activeStudent.engagementQuality, EngagementQuality.active);

      // 2. Moderate Engagement (35% <= Active Ratio < 65%)
      const moderateStudent = Student360Entity(
        studentId: 's2',
        todayActiveSeconds: 5000,
        todayIdleSeconds: 5000, // 50% active
      );
      expect(moderateStudent.todayActiveRatio, closeTo(0.50, 0.01));
      expect(moderateStudent.engagementQuality, EngagementQuality.moderate);

      // 3. Ghost Presence / Idle Session (Active Ratio < 35%)
      const ghostStudent = Student360Entity(
        studentId: 's3',
        todayActiveSeconds: 1200,
        todayIdleSeconds: 8800, // 12% active
      );
      expect(ghostStudent.todayActiveRatio, closeTo(0.12, 0.01));
      expect(ghostStudent.engagementQuality, EngagementQuality.ghostPresence);

      // 4. No Data (0 seconds today)
      const absentStudent = Student360Entity(
        studentId: 's4',
        todayActiveSeconds: 0,
        todayIdleSeconds: 0,
      );
      expect(absentStudent.todayActiveRatio, 0.0);
      expect(absentStudent.engagementQuality, EngagementQuality.noData);
    });

    test('Detects suspicious video watching behavior (Seek cheating / Fast-forward)', () {
      final now = DateTime.now();

      // Normal honest watching: 600s duration, 550s actual watch, 90% watched
      final honestVideo = StudentVideoInsight(
        videoId: 'v1',
        videoTitle: 'SAT Quadratics Deep Dive',
        durationSeconds: 600,
        progressSeconds: 540,
        actualWatchSeconds: 540,
        percentage: 90.0,
        completed: true,
        isSkipped: false,
        lastWatchedAt: now,
      );
      expect(honestVideo.isSuspicious, isFalse);
      expect(honestVideo.actualWatchMinutes, 9);
      expect(honestVideo.durationMinutes, 10);

      // Suspicious: Flagged as isSkipped by forward scrub detector
      final skippedVideo = StudentVideoInsight(
        videoId: 'v2',
        videoTitle: 'SAT Coordinate Geometry',
        durationSeconds: 1200,
        progressSeconds: 1200,
        actualWatchSeconds: 60, // Watched only 1 minute then jumped to end!
        percentage: 100.0,
        completed: true,
        isSkipped: true,
        lastWatchedAt: now,
      );
      expect(skippedVideo.isSuspicious, isTrue);

      // Suspicious: Reached 85% progress but actual watch time is < 50% of duration
      final lowListenVideo = StudentVideoInsight(
        videoId: 'v3',
        videoTitle: 'ACT Trigonometry Shortcuts',
        durationSeconds: 1000,
        progressSeconds: 850,
        actualWatchSeconds: 300, // Only 300s of 1000s duration (<50%)
        percentage: 85.0,
        completed: true,
        isSkipped: false,
        lastWatchedAt: now,
      );
      expect(lowListenVideo.isSuspicious, isTrue);
    });
  });

  group('WhatsAppReportGenerator Engagement Integration Tests', () {
    test('Includes active study minutes and engagement quality in the generated report', () {
      final report = WhatsAppReportGenerator.generateStudentWeeklyReport(
        studentName: 'عمر خالد',
        groupName: 'مجموعة تدريب SAT Advanced',
        attendanceRate: 1.0,
        videoWatchRate: 0.90,
        activeStudyMinutes: 75,
        engagementQualityText: 'حضور وتفاعل نشط وممتاز',
        teacherNotes: 'مستوى متميز وحل سريع للمسائل.',
      );

      expect(report, contains('عمر خالد'));
      expect(report, contains('مجموعة تدريب SAT Advanced'));
      expect(report, contains('⏱️ وقت التفاعل والمذاكرة النشط: 75 دقيقة (حضور وتفاعل نشط وممتاز)'));
      expect(report, contains('🎥 نسبة مشاهدة المحاضرات المسجلة: 90%'));
      expect(report, contains('د. أنطونيوس أشرف'));
    });

    test('Omits engagement line if active study minutes are zero or null', () {
      final report = WhatsAppReportGenerator.generateStudentWeeklyReport(
        studentName: 'سارة أحمد',
        activeStudyMinutes: 0,
      );

      expect(report, isNot(contains('وقت التفاعل والمذاكرة النشط')));
    });
  });
}
