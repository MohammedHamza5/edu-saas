import '../../domain/entities/attendance_entity.dart';

class AttendanceModel extends AttendanceEntity {
  const AttendanceModel({
    required super.id,
    required super.tenantId,
    required super.groupId,
    required super.studentId,
    required super.date,
    required super.status,
    required super.markedAt,
    super.markedBy,
    super.note,
    super.studentName,
    super.groupName,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    // Check if user/group details are joined
    String? studentName;
    if (json['users'] != null && json['users'] is Map) {
      studentName = json['users']['full_name'] as String?;
    } else if (json['student_name'] != null) {
      studentName = json['student_name'] as String?;
    }

    String? groupName;
    if (json['groups'] != null && json['groups'] is Map) {
      groupName = json['groups']['name'] as String?;
    } else if (json['group_name'] != null) {
      groupName = json['group_name'] as String?;
    }

    return AttendanceModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      groupId: json['group_id'] as String,
      studentId: json['student_id'] as String,
      date: DateTime.parse(json['date'] as String),
      status: AttendanceStatus.fromString(json['status'] as String?),
      markedAt: json['marked_at'] != null
          ? DateTime.parse(json['marked_at'] as String)
          : DateTime.now(),
      markedBy: json['marked_by'] as String?,
      note: json['note'] as String?,
      studentName: studentName,
      groupName: groupName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'group_id': groupId,
      'student_id': studentId,
      'date': "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'status': status.name,
      'marked_at': markedAt.toIso8601String(),
      'marked_by': markedBy,
      'note': note,
    };
  }

  static Map<String, dynamic> toUpsertMap({
    required String tenantId,
    required String groupId,
    required String studentId,
    required DateTime date,
    required AttendanceStatus status,
    required String markedBy,
    String? note,
  }) {
    final formattedDate =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    return {
      'tenant_id': tenantId,
      'group_id': groupId,
      'student_id': studentId,
      'date': formattedDate,
      'status': status.name,
      'marked_at': DateTime.now().toUtc().toIso8601String(),
      'marked_by': markedBy,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
    };
  }
}
