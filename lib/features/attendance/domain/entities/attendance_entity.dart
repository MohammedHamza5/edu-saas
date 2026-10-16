import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

/// Attendance status enum corresponding to Postgres check constraint:
/// check (status in ('present','absent','late','excused'))
enum AttendanceStatus {
  present,
  absent,
  late,
  excused;

  String localizedLabel(BuildContext context) => switch (this) {
    AttendanceStatus.present => context.l10n.attendanceStatusPresent,
    AttendanceStatus.absent => context.l10n.attendanceStatusAbsent,
    AttendanceStatus.late => context.l10n.attendanceStatusLate,
    AttendanceStatus.excused => context.l10n.attendanceStatusExcused,
  };

  String get labelAr => switch (this) {
    AttendanceStatus.present => 'حاضر',
    AttendanceStatus.absent => 'غائب',
    AttendanceStatus.late => 'متأخر',
    AttendanceStatus.excused => 'معذور',
  };

  String get labelEn => switch (this) {
    AttendanceStatus.present => 'Present',
    AttendanceStatus.absent => 'Absent',
    AttendanceStatus.late => 'Late',
    AttendanceStatus.excused => 'Excused',
  };

  static AttendanceStatus fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'present' => AttendanceStatus.present,
      'absent' => AttendanceStatus.absent,
      'late' => AttendanceStatus.late,
      'excused' => AttendanceStatus.excused,
      _ => AttendanceStatus.present,
    };
  }
}

/// Core domain entity for an attendance record in public.attendance
class AttendanceEntity extends Equatable {
  final String id;
  final String tenantId;
  final String groupId;
  final String studentId;
  final DateTime date;
  final AttendanceStatus status;
  final DateTime markedAt;
  final String? markedBy;
  final String? note;
  final String? studentName;
  final String? groupName;

  const AttendanceEntity({
    required this.id,
    required this.tenantId,
    required this.groupId,
    required this.studentId,
    required this.date,
    required this.status,
    required this.markedAt,
    this.markedBy,
    this.note,
    this.studentName,
    this.groupName,
  });

  @override
  List<Object?> get props => [
    id,
    tenantId,
    groupId,
    studentId,
    date,
    status,
    markedAt,
    markedBy,
    note,
    studentName,
    groupName,
  ];
}

/// Represents a video lecture attached to a group
class LectureItem extends Equatable {
  final String contentId;
  final String? videoId;
  final String title;
  final int? durationSeconds;
  final DateTime? publishedAt;
  final String? provider;
  final String? providerVideoId;
  final int sortOrder;

  const LectureItem({
    required this.contentId,
    this.videoId,
    required this.title,
    this.durationSeconds,
    this.publishedAt,
    this.provider,
    this.providerVideoId,
    this.sortOrder = 0,
  });

  String get formattedDuration {
    if (durationSeconds == null || durationSeconds! <= 0) return '';
    final d = Duration(seconds: durationSeconds!);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
    contentId,
    videoId,
    title,
    durationSeconds,
    publishedAt,
    provider,
    providerVideoId,
    sortOrder,
  ];
}

/// Result container for group attendance including students and available lectures
class GroupAttendanceData extends Equatable {
  final List<StudentAttendanceItem> students;
  final List<LectureItem> lectures;
  final String? selectedLectureContentId;

  const GroupAttendanceData({
    required this.students,
    required this.lectures,
    this.selectedLectureContentId,
  });

  @override
  List<Object?> get props => [students, lectures, selectedLectureContentId];
}

/// Item representing a student row in the teacher's attendance sheet
class StudentAttendanceItem extends Equatable {
  final String studentId;
  final String studentName;
  final String? avatarUrl;
  final String? phone;
  final AttendanceStatus status;
  final String? note;
  final String? existingAttendanceId;

  // Real Video Lecture Watch Tracking Fields
  final double watchProgressPercent;
  final int watchSeconds;
  final int totalDurationSeconds;
  final bool isCompleted;
  final DateTime? lastWatchedAt;
  final bool isSkipped;
  final int totalLecturesCount;
  final int completedLecturesCount;
  final int startedLecturesCount;
  final String? currentLectureTitle;

  const StudentAttendanceItem({
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    this.phone,
    required this.status,
    this.note,
    this.existingAttendanceId,
    this.watchProgressPercent = 0.0,
    this.watchSeconds = 0,
    this.totalDurationSeconds = 0,
    this.isCompleted = false,
    this.lastWatchedAt,
    this.isSkipped = false,
    this.totalLecturesCount = 0,
    this.completedLecturesCount = 0,
    this.startedLecturesCount = 0,
    this.currentLectureTitle,
  });

  String get formattedWatchDuration {
    if (totalDurationSeconds <= 0 && watchSeconds <= 0) return '';
    String formatSec(int sec) {
      final d = Duration(seconds: sec);
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      final s = d.inSeconds.remainder(60);
      if (h > 0) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    if (totalDurationSeconds > 0) {
      return '${formatSec(watchSeconds)} / ${formatSec(totalDurationSeconds)}';
    }
    return formatSec(watchSeconds);
  }

  bool get hasWatchedAny => watchProgressPercent > 0;
  bool get isFullyWatched => isCompleted || watchProgressPercent >= 80.0;

  StudentAttendanceItem copyWith({
    String? studentId,
    String? studentName,
    String? avatarUrl,
    String? phone,
    AttendanceStatus? status,
    String? note,
    String? existingAttendanceId,
    double? watchProgressPercent,
    int? watchSeconds,
    int? totalDurationSeconds,
    bool? isCompleted,
    DateTime? lastWatchedAt,
    bool? isSkipped,
    int? totalLecturesCount,
    int? completedLecturesCount,
    int? startedLecturesCount,
    String? currentLectureTitle,
  }) {
    return StudentAttendanceItem(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      note: note ?? this.note,
      existingAttendanceId: existingAttendanceId ?? this.existingAttendanceId,
      watchProgressPercent: watchProgressPercent ?? this.watchProgressPercent,
      watchSeconds: watchSeconds ?? this.watchSeconds,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
      isSkipped: isSkipped ?? this.isSkipped,
      totalLecturesCount: totalLecturesCount ?? this.totalLecturesCount,
      completedLecturesCount:
          completedLecturesCount ?? this.completedLecturesCount,
      startedLecturesCount: startedLecturesCount ?? this.startedLecturesCount,
      currentLectureTitle: currentLectureTitle ?? this.currentLectureTitle,
    );
  }

  @override
  List<Object?> get props => [
    studentId,
    studentName,
    avatarUrl,
    phone,
    status,
    note,
    existingAttendanceId,
    watchProgressPercent,
    watchSeconds,
    totalDurationSeconds,
    isCompleted,
    lastWatchedAt,
    isSkipped,
    totalLecturesCount,
    completedLecturesCount,
    startedLecturesCount,
    currentLectureTitle,
  ];
}

/// Academic attendance statistics (percentages, counts)
class AttendanceStats extends Equatable {
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;
  final double averageWatchPercentage;

  const AttendanceStats({
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
    this.averageWatchPercentage = 0.0,
  });

  const AttendanceStats.empty()
    : totalSessions = 0,
      presentCount = 0,
      absentCount = 0,
      lateCount = 0,
      excusedCount = 0,
      averageWatchPercentage = 0.0;

  factory AttendanceStats.fromRecords(List<AttendanceEntity> records) {
    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;

    for (final record in records) {
      switch (record.status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.excused:
          excused++;
      }
    }

    return AttendanceStats(
      totalSessions: records.length,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      excusedCount: excused,
    );
  }

  double get attendancePercentage {
    if (totalSessions == 0) return 0.0;
    // Present + Excused are considered compliant attendance
    final compliant = presentCount + excusedCount;
    return (compliant / totalSessions) * 100.0;
  }

  double get strictPresentPercentage {
    if (totalSessions == 0) return 0.0;
    return (presentCount / totalSessions) * 100.0;
  }

  @override
  List<Object?> get props => [
    totalSessions,
    presentCount,
    absentCount,
    lateCount,
    excusedCount,
    averageWatchPercentage,
  ];
}

/// Represents a single video lecture engagement item for a student
class StudentLectureEngagementItem extends Equatable {
  final String contentId;
  final String lectureTitle;
  final String groupId;
  final String groupName;
  final String? videoId;
  final int durationSeconds;
  final int watchSeconds;
  final double watchProgressPercent;
  final bool isCompleted;
  final DateTime? lastWatchedAt;
  final int sortOrder;

  const StudentLectureEngagementItem({
    required this.contentId,
    required this.lectureTitle,
    required this.groupId,
    required this.groupName,
    this.videoId,
    this.durationSeconds = 0,
    this.watchSeconds = 0,
    this.watchProgressPercent = 0.0,
    this.isCompleted = false,
    this.lastWatchedAt,
    this.sortOrder = 0,
  });

  bool get hasWatchedAny => watchProgressPercent > 0;
  bool get isFullyWatched => isCompleted || watchProgressPercent >= 80.0;

  String get formattedDuration {
    if (durationSeconds <= 0) return '';
    final d = Duration(seconds: durationSeconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedWatchTime {
    if (watchSeconds <= 0) return '00:00';
    final d = Duration(seconds: watchSeconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
    contentId,
    lectureTitle,
    groupId,
    groupName,
    videoId,
    durationSeconds,
    watchSeconds,
    watchProgressPercent,
    isCompleted,
    lastWatchedAt,
    sortOrder,
  ];
}

/// Represents student group membership metadata for filtering
class StudentGroupInfo extends Equatable {
  final String id;
  final String name;
  final String level;

  const StudentGroupInfo({
    required this.id,
    required this.name,
    required this.level,
  });

  @override
  List<Object?> get props => [id, name, level];
}

/// Consolidated student engagement summary across enrolled groups
class StudentEngagementSummary extends Equatable {
  final int totalWatchSeconds;
  final int totalDurationSeconds;
  final int totalLecturesCount;
  final int completedLecturesCount;
  final int inProgressLecturesCount;
  final int notStartedLecturesCount;
  final double overallCommitmentPercentage;
  final DateTime? lastActiveAt;
  final List<StudentLectureEngagementItem> items;
  final List<StudentGroupInfo> enrolledGroups;

  const StudentEngagementSummary({
    this.totalWatchSeconds = 0,
    this.totalDurationSeconds = 0,
    this.totalLecturesCount = 0,
    this.completedLecturesCount = 0,
    this.inProgressLecturesCount = 0,
    this.notStartedLecturesCount = 0,
    this.overallCommitmentPercentage = 0.0,
    this.lastActiveAt,
    this.items = const [],
    this.enrolledGroups = const [],
  });

  const StudentEngagementSummary.empty()
    : totalWatchSeconds = 0,
      totalDurationSeconds = 0,
      totalLecturesCount = 0,
      completedLecturesCount = 0,
      inProgressLecturesCount = 0,
      notStartedLecturesCount = 0,
      overallCommitmentPercentage = 0.0,
      lastActiveAt = null,
      items = const [],
      enrolledGroups = const [];

  String get formattedTotalWatchHours {
    if (totalWatchSeconds <= 0) return '0 د';
    final d = Duration(seconds: totalWatchSeconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) {
      return '$h س $m د';
    }
    return '$m د';
  }

  String get formattedTotalDurationHours {
    if (totalDurationSeconds <= 0) return '0 د';
    final d = Duration(seconds: totalDurationSeconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) {
      return '$h س $m د';
    }
    return '$m د';
  }

  @override
  List<Object?> get props => [
    totalWatchSeconds,
    totalDurationSeconds,
    totalLecturesCount,
    completedLecturesCount,
    inProgressLecturesCount,
    notStartedLecturesCount,
    overallCommitmentPercentage,
    lastActiveAt,
    items,
    enrolledGroups,
  ];
}

/// Consolidated bundle holding student engagement, attendance stats, and recent history
class StudentAttendanceBundle extends Equatable {
  final StudentEngagementSummary engagementSummary;
  final AttendanceStats stats;
  final List<AttendanceEntity> records;

  const StudentAttendanceBundle({
    required this.engagementSummary,
    required this.stats,
    required this.records,
  });

  @override
  List<Object?> get props => [engagementSummary, stats, records];
}

