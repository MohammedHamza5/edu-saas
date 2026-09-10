import '../../domain/entities/student_360_entity.dart';
import '../../domain/entities/student_entity.dart';

class StudentModel extends StudentEntity {
  const StudentModel({
    required super.id,
    required super.tenantId,
    required super.fullName,
    required super.email,
    super.phone,
    super.avatarUrl,
    super.status,
    super.role,
    super.lastActivityAt,
    super.createdAt,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      status: json['status'] as String? ?? 'pending',
      role: json['role'] as String? ?? 'student',
      lastActivityAt: json['last_activity_at'] != null
          ? DateTime.tryParse(json['last_activity_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenant_id': tenantId,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'status': status,
        'role': role,
      };
}

// ---------------------------------------------------------------------------

class Student360Model extends Student360Entity {
  const Student360Model({
    required super.studentId,
    super.attendancePercentage,
    super.assignmentsSubmitted,
    super.assignmentsReviewed,
    super.examAverage,
    super.videoCompletionPercentage,
    super.lastActivityAt,
    super.groups,
    super.todayActiveSeconds,
    super.todayIdleSeconds,
    super.totalActiveSeconds7d,
    super.totalIdleSeconds7d,
    super.firstSeenToday,
    super.lastSeenToday,
    super.recentActivities,
    super.videoInsights,
  });

  /// Build from JSON returned by `get_student_360` RPC or fallback queries.
  factory Student360Model.fromJson(Map<String, dynamic> data, String studentId) {
    // 1. Groups
    final rawGroups = data['groups'] as List<dynamic>? ?? [];
    final groups = rawGroups.map((e) {
      final map = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return StudentGroupInfoModel.fromJson(map);
    }).toList();

    // 2. Last activity
    final lastActivity = data['last_activity_at'] != null
        ? DateTime.tryParse(data['last_activity_at'].toString())
        : null;

    // 3. Attendance
    final totalAtt = (data['attendance_total'] as num?)?.toInt() ?? 0;
    final presentAtt = (data['attendance_present'] as num?)?.toInt() ?? 0;

    // 4. Assignments
    final submitted = (data['submissions_total'] as num?)?.toInt() ?? 0;
    final reviewed = (data['submissions_reviewed'] as num?)?.toInt() ?? 0;

    // 5. Performance averages
    final avgScore = (data['exam_avg_percentage'] as num?)?.toDouble() ?? 0.0;
    final avgVideo = (data['video_avg_percentage'] as num?)?.toDouble() ?? 0.0;

    // 6. Smart Engagement
    final todayActive = (data['today_active_seconds'] as num?)?.toInt() ?? 0;
    final todayIdle = (data['today_idle_seconds'] as num?)?.toInt() ?? 0;
    final totalActive7d =
        (data['total_active_seconds_7d'] as num?)?.toInt() ?? 0;
    final totalIdle7d = (data['total_idle_seconds_7d'] as num?)?.toInt() ?? 0;

    final firstSeen = data['first_seen_today'] != null
        ? DateTime.tryParse(data['first_seen_today'].toString())
        : null;
    final lastSeen = data['last_seen_today'] != null
        ? DateTime.tryParse(data['last_seen_today'].toString())
        : null;

    // 7. Recent Activities
    final rawActivities = data['recent_activities'] as List<dynamic>? ?? [];
    final activities = rawActivities.map((e) {
      final map = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      final meta = map['metadata'];
      return StudentActivityItem(
        id: map['id']?.toString() ?? '',
        eventType: map['event_type']?.toString() ?? '',
        createdAt: map['created_at'] != null
            ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
            : DateTime.now(),
        contentId: map['content_id']?.toString(),
        contentTitle: map['content_title']?.toString(),
        groupName: map['group_name']?.toString(),
        metadata: meta is Map ? Map<String, dynamic>.from(meta) : const {},
      );
    }).toList();

    // 8. Video Insights
    final rawVideos = data['video_insights'] as List<dynamic>? ?? [];
    final videoInsights = rawVideos.map((e) {
      final map = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return StudentVideoInsight(
        videoId: map['video_id']?.toString() ?? '',
        videoTitle: map['video_title']?.toString() ?? '',
        durationSeconds: (map['duration_seconds'] as num?)?.toInt() ?? 0,
        progressSeconds: (map['progress_seconds'] as num?)?.toInt() ?? 0,
        actualWatchSeconds: (map['actual_watch_seconds'] as num?)?.toInt() ?? 0,
        percentage: (map['percentage'] as num?)?.toDouble() ?? 0.0,
        completed: map['completed'] == true,
        isSkipped: map['is_skipped'] == true,
        lastWatchedAt: map['last_watched_at'] != null
            ? DateTime.tryParse(map['last_watched_at'].toString()) ??
                DateTime.now()
            : DateTime.now(),
      );
    }).toList();

    return Student360Model(
      studentId: studentId,
      attendancePercentage: totalAtt > 0 ? (presentAtt / totalAtt) * 100 : 0,
      assignmentsSubmitted: submitted,
      assignmentsReviewed: reviewed,
      examAverage: avgScore,
      videoCompletionPercentage: avgVideo,
      lastActivityAt: lastActivity,
      groups: groups,
      todayActiveSeconds: todayActive,
      todayIdleSeconds: todayIdle,
      totalActiveSeconds7d: totalActive7d,
      totalIdleSeconds7d: totalIdle7d,
      firstSeenToday: firstSeen,
      lastSeenToday: lastSeen,
      recentActivities: activities,
      videoInsights: videoInsights,
    );
  }
}

class StudentGroupInfoModel extends StudentGroupInfo {
  const StudentGroupInfoModel({
    required super.groupId,
    required super.groupName,
    required super.groupLevel,
    required super.joinedAt,
  });

  factory StudentGroupInfoModel.fromJson(Map<String, dynamic> json) {
    // joined via group_members join with groups table or rpc
    final groupData = json['groups'];
    final groupJson =
        groupData is Map ? Map<String, dynamic>.from(groupData) : null;
    return StudentGroupInfoModel(
      groupId: json['group_id']?.toString() ?? '',
      groupName: groupJson?['name']?.toString() ??
          json['group_name']?.toString() ??
          '',
      groupLevel: groupJson?['level']?.toString() ??
          json['group_level']?.toString() ??
          '',
      joinedAt: json['joined_at'] != null
          ? DateTime.tryParse(json['joined_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
