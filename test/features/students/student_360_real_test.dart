import 'package:flutter_test/flutter_test.dart';
import 'package:edu_saas/features/students/data/models/student_model.dart';

void main() {
  group('Student360Model Unit Tests', () {
    const studentId = 'student-uuid-123';

    test('parses full get_student_360 RPC JSON correctly', () {
      final sampleJson = <String, dynamic>{
        'groups': [
          {
            'group_id': 'grp-1',
            'joined_at': '2026-09-01T10:00:00Z',
            'groups': {'name': 'SAT Math Basics', 'level': 'Grade 11'},
          },
        ],
        'last_activity_at': '2026-09-09T18:30:00Z',
        'attendance_total': 10,
        'attendance_present': 9,
        'submissions_total': 5,
        'submissions_reviewed': 4,
        'exam_avg_percentage': 88.5,
        'video_avg_percentage': 92.0,
        'today_active_seconds': 3600,
        'today_idle_seconds': 300,
        'first_seen_today': '2026-09-09T09:00:00Z',
        'last_seen_today': '2026-09-09T10:05:00Z',
        'total_active_seconds_7d': 25200,
        'total_idle_seconds_7d': 1800,
        'recent_activities': [
          {
            'id': 'act-1',
            'event_type': 'video_completed',
            'created_at': '2026-09-09T09:45:00Z',
            'content_id': 'cnt-1',
            'content_title': 'Quadratic Equations Lesson',
            'group_name': 'SAT Math Basics',
            'metadata': {'percentage': 100},
          },
        ],
        'video_insights': [
          {
            'video_id': 'vid-1',
            'video_title': 'Quadratic Equations Lesson',
            'duration_seconds': 1200,
            'progress_seconds': 1200,
            'actual_watch_seconds': 1180,
            'percentage': 100.0,
            'completed': true,
            'is_skipped': false,
            'last_watched_at': '2026-09-09T09:45:00Z',
          },
        ],
      };

      final model = Student360Model.fromJson(sampleJson, studentId);

      expect(model.studentId, equals(studentId));
      expect(model.groups.length, equals(1));
      expect(model.groups.first.groupName, equals('SAT Math Basics'));
      expect(model.groups.first.groupLevel, equals('Grade 11'));
      expect(model.attendancePercentage, equals(90.0));
      expect(model.assignmentsSubmitted, equals(5));
      expect(model.assignmentsReviewed, equals(4));
      expect(model.examAverage, equals(88.5));
      expect(model.videoCompletionPercentage, equals(92.0));
      expect(model.todayActiveSeconds, equals(3600));
      expect(model.todayIdleSeconds, equals(300));
      expect(model.totalActiveSeconds7d, equals(25200));
      expect(model.totalIdleSeconds7d, equals(1800));
      expect(model.firstSeenToday, isNotNull);
      expect(model.lastSeenToday, isNotNull);
      expect(model.recentActivities.length, equals(1));
      expect(model.recentActivities.first.eventType, equals('video_completed'));
      expect(model.videoInsights.length, equals(1));
      expect(model.videoInsights.first.completed, isTrue);
      expect(model.videoInsights.first.isSkipped, isFalse);
    });

    test('handles empty and null JSON gracefully with default values', () {
      final emptyJson = <String, dynamic>{};
      final model = Student360Model.fromJson(emptyJson, studentId);

      expect(model.studentId, equals(studentId));
      expect(model.groups, isEmpty);
      expect(model.attendancePercentage, equals(0.0));
      expect(model.assignmentsSubmitted, equals(0));
      expect(model.assignmentsReviewed, equals(0));
      expect(model.examAverage, equals(0.0));
      expect(model.videoCompletionPercentage, equals(0.0));
      expect(model.todayActiveSeconds, equals(0));
      expect(model.todayIdleSeconds, equals(0));
      expect(model.totalActiveSeconds7d, equals(0));
      expect(model.totalIdleSeconds7d, equals(0));
      expect(model.firstSeenToday, isNull);
      expect(model.lastSeenToday, isNull);
      expect(model.recentActivities, isEmpty);
      expect(model.videoInsights, isEmpty);
    });
  });
}
