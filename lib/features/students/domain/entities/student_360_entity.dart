import 'package:equatable/equatable.dart';

/// Engagement quality classifications based on objective active vs idle ratio
enum EngagementQuality {
  active, // تفاعل نشط وحقيقي (نسبة التفاعل >= 65%)
  moderate, // تفاعل متوسط (بين 35% و 65%)
  ghostPresence, // حضور شكلي / خامل (تصفح خامل أو ترك التطبيق بالخلفية)
  noData, // لم يسجل دخول اليوم
}

/// Student 360° stats entity — aggregated view for Teacher and Parent.
class Student360Entity extends Equatable {
  final String studentId;
  final double attendancePercentage; // 0..100
  final int assignmentsSubmitted;
  final int assignmentsReviewed;
  final double examAverage; // average score 0..100
  final double videoCompletionPercentage; // 0..100
  final DateTime? lastActivityAt;
  final List<StudentGroupInfo> groups;

  // ── Smart Engagement Telemetry ──
  final int todayActiveSeconds;
  final int todayIdleSeconds;
  final int totalActiveSeconds7d;
  final int totalIdleSeconds7d;
  final DateTime? firstSeenToday;
  final DateTime? lastSeenToday;
  final List<StudentActivityItem> recentActivities;
  final List<StudentVideoInsight> videoInsights;

  const Student360Entity({
    required this.studentId,
    this.attendancePercentage = 0,
    this.assignmentsSubmitted = 0,
    this.assignmentsReviewed = 0,
    this.examAverage = 0,
    this.videoCompletionPercentage = 0,
    this.lastActivityAt,
    this.groups = const [],
    this.todayActiveSeconds = 0,
    this.todayIdleSeconds = 0,
    this.totalActiveSeconds7d = 0,
    this.totalIdleSeconds7d = 0,
    this.firstSeenToday,
    this.lastSeenToday,
    this.recentActivities = const [],
    this.videoInsights = const [],
  });

  int get todayActiveMinutes => (todayActiveSeconds / 60).round();
  int get todayIdleMinutes => (todayIdleSeconds / 60).round();
  int get totalSessionMinutesToday => todayActiveMinutes + todayIdleMinutes;

  int get totalActiveMinutes7d => (totalActiveSeconds7d / 60).round();
  int get totalIdleMinutes7d => (totalIdleSeconds7d / 60).round();

  double get todayActiveRatio {
    final total = todayActiveSeconds + todayIdleSeconds;
    if (total == 0) return 0.0;
    return todayActiveSeconds / total;
  }

  EngagementQuality get engagementQuality {
    final total = todayActiveSeconds + todayIdleSeconds;
    if (total == 0) return EngagementQuality.noData;
    if (todayActiveRatio >= 0.65) return EngagementQuality.active;
    if (todayActiveRatio >= 0.35) return EngagementQuality.moderate;
    return EngagementQuality.ghostPresence;
  }

  @override
  List<Object?> get props => [
        studentId,
        attendancePercentage,
        assignmentsSubmitted,
        assignmentsReviewed,
        examAverage,
        videoCompletionPercentage,
        lastActivityAt,
        groups,
        todayActiveSeconds,
        todayIdleSeconds,
        totalActiveSeconds7d,
        totalIdleSeconds7d,
        firstSeenToday,
        lastSeenToday,
        recentActivities,
        videoInsights,
      ];
}

class StudentGroupInfo extends Equatable {
  final String groupId;
  final String groupName;
  final String groupLevel;
  final DateTime joinedAt;

  const StudentGroupInfo({
    required this.groupId,
    required this.groupName,
    required this.groupLevel,
    required this.joinedAt,
  });

  @override
  List<Object?> get props => [groupId, groupName, groupLevel, joinedAt];
}

/// Single item in the student's activity timeline
class StudentActivityItem extends Equatable {
  final String id;
  final String eventType; // login, content_opened, video_started, etc.
  final DateTime createdAt;
  final String? contentId;
  final String? contentTitle;
  final String? groupName;
  final Map<String, dynamic> metadata;

  const StudentActivityItem({
    required this.id,
    required this.eventType,
    required this.createdAt,
    this.contentId,
    this.contentTitle,
    this.groupName,
    this.metadata = const {},
  });

  @override
  List<Object?> get props => [
        id,
        eventType,
        createdAt,
        contentId,
        contentTitle,
        groupName,
        metadata,
      ];
}

/// Detailed video watch telemetry and honesty indicator
class StudentVideoInsight extends Equatable {
  final String videoId;
  final String videoTitle;
  final int durationSeconds;
  final int progressSeconds;
  final int actualWatchSeconds;
  final double percentage;
  final bool completed;
  final bool isSkipped;
  final DateTime lastWatchedAt;

  const StudentVideoInsight({
    required this.videoId,
    required this.videoTitle,
    required this.durationSeconds,
    required this.progressSeconds,
    required this.actualWatchSeconds,
    required this.percentage,
    required this.completed,
    required this.isSkipped,
    required this.lastWatchedAt,
  });

  /// Check if the video watch is suspicious (e.g. skipped or actual watch time is < 50% of duration while marked finished)
  bool get isSuspicious =>
      isSkipped ||
      (percentage >= 80 &&
          durationSeconds > 60 &&
          actualWatchSeconds < (durationSeconds * 0.5));

  int get actualWatchMinutes => (actualWatchSeconds / 60).round();
  int get durationMinutes => (durationSeconds / 60).round();

  @override
  List<Object?> get props => [
        videoId,
        videoTitle,
        durationSeconds,
        progressSeconds,
        actualWatchSeconds,
        percentage,
        completed,
        isSkipped,
        lastWatchedAt,
      ];
}
