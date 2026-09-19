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

/// Item representing a student row in the teacher's attendance sheet
class StudentAttendanceItem extends Equatable {
  final String studentId;
  final String studentName;
  final String? avatarUrl;
  final String? phone;
  final AttendanceStatus status;
  final String? note;
  final String? existingAttendanceId;

  const StudentAttendanceItem({
    required this.studentId,
    required this.studentName,
    this.avatarUrl,
    this.phone,
    required this.status,
    this.note,
    this.existingAttendanceId,
  });

  StudentAttendanceItem copyWith({
    String? studentId,
    String? studentName,
    String? avatarUrl,
    String? phone,
    AttendanceStatus? status,
    String? note,
    String? existingAttendanceId,
  }) {
    return StudentAttendanceItem(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      note: note ?? this.note,
      existingAttendanceId: existingAttendanceId ?? this.existingAttendanceId,
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
  ];
}

/// Academic attendance statistics (percentages, counts)
class AttendanceStats extends Equatable {
  final int totalSessions;
  final int presentCount;
  final int absentCount;
  final int lateCount;
  final int excusedCount;

  const AttendanceStats({
    required this.totalSessions,
    required this.presentCount,
    required this.absentCount,
    required this.lateCount,
    required this.excusedCount,
  });

  const AttendanceStats.empty()
    : totalSessions = 0,
      presentCount = 0,
      absentCount = 0,
      lateCount = 0,
      excusedCount = 0;

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
  ];
}
