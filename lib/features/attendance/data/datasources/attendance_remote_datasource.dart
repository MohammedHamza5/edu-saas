import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../notifications/domain/services/notification_dispatcher.dart';
import '../../domain/entities/attendance_entity.dart';
import '../models/attendance_model.dart';

abstract interface class AttendanceRemoteDataSource {
  Future<GroupAttendanceData> getGroupStudentsWithAttendance({
    required String groupId,
    required DateTime date,
    String? lectureContentId,
  });

  Future<void> saveGroupAttendance({
    required String groupId,
    required DateTime date,
    required List<StudentAttendanceItem> items,
  });

  Future<List<AttendanceModel>> getStudentAttendanceHistory({
    required String studentId,
    String? groupId,
    int? page,
    int? pageSize,
  });

  Future<AttendanceStats> getStudentAttendanceStats({
    required String studentId,
    String? groupId,
  });
}

class AttendanceRemoteDataSourceImpl implements AttendanceRemoteDataSource {
  final SupabaseClient? _client;

  AttendanceRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<GroupAttendanceData> getGroupStudentsWithAttendance({
    required String groupId,
    required DateTime date,
    String? lectureContentId,
  }) async {
    final formattedDate =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // 1. Concurrently fetch active students, group video lectures, and existing attendance records
    final responses = await Future.wait([
      _safeClient
          .from('group_members')
          .select('student_id, users(id, full_name, phone, avatar_url, status)')
          .eq('group_id', groupId)
          .eq('status', 'active'),
      _safeClient
          .from('content')
          .select('id, title, published_at, sort_order, videos(id, duration, provider, provider_video_id)')
          .eq('group_id', groupId)
          .eq('type', 'video')
          .eq('status', 'published')
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true),
      _safeClient
          .from('attendance')
          .select('id, student_id, status, note')
          .eq('group_id', groupId)
          .eq('date', formattedDate),
    ]);

    final membersList = responses[0] as List<dynamic>;
    final contentList = responses[1] as List<dynamic>;
    final existingRecordsList = responses[2] as List<dynamic>;

    // 2. Parse available lectures
    final lectures = <LectureItem>[];
    final videoIdToContentIdMap = <String, String>{};
    final videoIds = <String>[];

    for (final cJson in contentList) {
      final contentMap = cJson as Map<String, dynamic>;
      final contentId = contentMap['id'] as String;
      final title = contentMap['title'] as String? ?? 'محاضرة';
      final sortOrder = (contentMap['sort_order'] as num?)?.toInt() ?? 0;
      final publishedAtStr = contentMap['published_at'] as String?;
      final publishedAt =
          publishedAtStr != null ? DateTime.tryParse(publishedAtStr) : null;

      final videosRaw = contentMap['videos'];
      Map<String, dynamic>? videoMap;
      if (videosRaw is List && videosRaw.isNotEmpty) {
        videoMap = videosRaw.first as Map<String, dynamic>?;
      } else if (videosRaw is Map<String, dynamic>) {
        videoMap = videosRaw;
      }

      final videoId = videoMap?['id'] as String?;
      final duration = (videoMap?['duration'] as num?)?.toInt();
      final provider = videoMap?['provider'] as String?;
      final providerVideoId = videoMap?['provider_video_id'] as String?;

      final lecture = LectureItem(
        contentId: contentId,
        videoId: videoId,
        title: title,
        durationSeconds: duration,
        publishedAt: publishedAt,
        provider: provider,
        providerVideoId: providerVideoId,
        sortOrder: sortOrder,
      );
      lectures.add(lecture);

      if (videoId != null && videoId.isNotEmpty) {
        videoIds.add(videoId);
        videoIdToContentIdMap[videoId] = contentId;
      }
    }

    // 3. Resolve active lecture
    LectureItem? activeLecture;
    if (lectureContentId != null) {
      activeLecture = lectures.cast<LectureItem?>().firstWhere(
        (l) => l?.contentId == lectureContentId,
        orElse: () => null,
      );
    }
    activeLecture ??= lectures.isNotEmpty ? lectures.first : null;

    // 4. Fetch all video progress for group's videos
    // studentId -> { videoId -> progressMap }
    final studentProgressMap = <String, Map<String, Map<String, dynamic>>>{};
    if (videoIds.isNotEmpty) {
      try {
        final progressResponse = await _safeClient
            .from('video_progress')
            .select(
              'video_id, student_id, progress_seconds, duration_seconds, percentage, watched_coverage_percentage, actual_watch_seconds, completed, is_skipped, last_watched_at',
            )
            .inFilter('video_id', videoIds);

        for (final pItem in (progressResponse as List<dynamic>)) {
          final pMap = pItem as Map<String, dynamic>;
          final sId = pMap['student_id'] as String?;
          final vId = pMap['video_id'] as String?;
          if (sId != null && vId != null) {
            studentProgressMap.putIfAbsent(sId, () => {})[vId] = pMap;
          }
        }
      } catch (_) {
        // Fallback safely if video_progress query errors
      }
    }

    // 5. Existing manual attendance records map
    final existingMap = <String, Map<String, dynamic>>{};
    for (final record in existingRecordsList) {
      final studentId = record['student_id'] as String;
      existingMap[studentId] = record as Map<String, dynamic>;
    }

    // 6. Build StudentAttendanceItems
    final result = <StudentAttendanceItem>[];
    for (final item in membersList) {
      final studentId = item['student_id'] as String;
      final userData = item['users'] as Map<String, dynamic>?;

      // Filter out rejected or suspended students
      final userStatus = userData?['status'] as String?;
      if (userStatus == 'suspended' || userStatus == 'rejected') {
        continue;
      }

      final studentName = userData?['full_name'] as String? ?? 'طالب';
      final avatarUrl = userData?['avatar_url'] as String?;
      final phone = userData?['phone'] as String?;

      // Calculate progress stats across all group lectures
      final studentVideos = studentProgressMap[studentId] ?? {};
      int startedCount = 0;
      int completedCount = 0;

      for (final l in lectures) {
        if (l.videoId != null && studentVideos.containsKey(l.videoId)) {
          final vp = studentVideos[l.videoId]!;
          final cov = _parseCoverage(vp['watched_coverage_percentage'], vp['percentage']);
          final isComp = vp['completed'] == true || cov >= 80.0;
          if (cov > 0.0 || (vp['actual_watch_seconds'] as num? ?? 0) > 0) {
            startedCount++;
          }
          if (isComp) {
            completedCount++;
          }
        }
      }

      // Calculate progress for active lecture
      double watchPercent = 0.0;
      int watchSec = 0;
      int totalDur = activeLecture?.durationSeconds ?? 0;
      bool isComp = false;
      bool isSkip = false;
      DateTime? lastWatch;

      if (activeLecture != null && activeLecture.videoId != null) {
        final activeVp = studentVideos[activeLecture.videoId];
        if (activeVp != null) {
          watchPercent = _parseCoverage(
            activeVp['watched_coverage_percentage'],
            activeVp['percentage'],
          );
          watchSec = (activeVp['actual_watch_seconds'] as num?)?.toInt() ??
              (activeVp['progress_seconds'] as num?)?.toInt() ??
              0;
          final durSec = (activeVp['duration_seconds'] as num?)?.toInt();
          if (durSec != null && durSec > 0) {
            totalDur = durSec;
          }
          isComp = activeVp['completed'] == true || watchPercent >= 80.0;
          isSkip = activeVp['is_skipped'] == true;
          final lwStr = activeVp['last_watched_at'] as String?;
          lastWatch = lwStr != null ? DateTime.tryParse(lwStr) : null;
        }
      }

      // Determine attendance status:
      // Priority 1: Manual attendance recorded by teacher
      // Priority 2: Automatically derived from real video watch percentage
      final existingRecord = existingMap[studentId];
      final AttendanceStatus status;
      if (existingRecord != null) {
        status = AttendanceStatus.fromString(existingRecord['status'] as String?);
      } else {
        if (isComp || watchPercent >= 80.0) {
          status = AttendanceStatus.present; // أتم المشاهدة (حاضر)
        } else if (watchPercent > 0.0) {
          status = AttendanceStatus.late; // قيد المشاهدة (مشاهدة جزئية)
        } else {
          status = AttendanceStatus.absent; // لم يبدأ المشاهدة بعد (غائب)
        }
      }

      result.add(
        StudentAttendanceItem(
          studentId: studentId,
          studentName: studentName,
          avatarUrl: avatarUrl,
          phone: phone,
          status: status,
          note: existingRecord?['note'] as String?,
          existingAttendanceId: existingRecord?['id'] as String?,
          watchProgressPercent: watchPercent,
          watchSeconds: watchSec,
          totalDurationSeconds: totalDur,
          isCompleted: isComp,
          lastWatchedAt: lastWatch,
          isSkipped: isSkip,
          totalLecturesCount: lectures.length,
          completedLecturesCount: completedCount,
          startedLecturesCount: startedCount,
          currentLectureTitle: activeLecture?.title,
        ),
      );
    }

    // Sort alphabetically by student name
    result.sort((a, b) => a.studentName.compareTo(b.studentName));

    return GroupAttendanceData(
      students: result,
      lectures: lectures,
      selectedLectureContentId: activeLecture?.contentId,
    );
  }

  static double _parseCoverage(dynamic coverage, dynamic fallbackPercentage) {
    if (coverage != null) {
      if (coverage is num) return coverage.toDouble();
      final parsed = double.tryParse(coverage.toString());
      if (parsed != null) return parsed;
    }
    if (fallbackPercentage != null) {
      if (fallbackPercentage is num) return fallbackPercentage.toDouble();
      final parsed = double.tryParse(fallbackPercentage.toString());
      if (parsed != null) return parsed;
    }
    return 0.0;
  }

  @override
  Future<void> saveGroupAttendance({
    required String groupId,
    required DateTime date,
    required List<StudentAttendanceItem> items,
  }) async {
    if (items.isEmpty) return;

    final currentUser = _safeClient.auth.currentUser;
    if (currentUser == null) {
      throw const AuthException('AUTH_REQUIRED: User not authenticated');
    }

    // Fetch teacher's tenant_id
    final userProfile = await _safeClient
        .from('users')
        .select('tenant_id')
        .eq('id', currentUser.id)
        .maybeSingle();

    if (userProfile == null) {
      throw const PostgrestException(message: 'Teacher user profile not found');
    }

    final tenantId = userProfile['tenant_id'] as String;

    final records = items.map((item) {
      return AttendanceModel.toUpsertMap(
        tenantId: tenantId,
        groupId: groupId,
        studentId: item.studentId,
        date: date,
        status: item.status,
        markedBy: currentUser.id,
        note: item.note,
      );
    }).toList();

    // Atomic upsert based on constraint attendance_unique (group_id, student_id, date)
    await _safeClient
        .from('attendance')
        .upsert(records, onConflict: 'group_id,student_id,date');

    final formattedDate =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    for (final item in items) {
      final statusLabel = switch (item.status) {
        AttendanceStatus.present => 'حاضر',
        AttendanceStatus.absent => 'غائب',
        AttendanceStatus.late => 'متأخر',
        AttendanceStatus.excused => 'غياب بعذر',
      };
      unawaited(
        NotificationDispatcher.notifyAttendanceMarked(
          studentId: item.studentId,
          sessionDate: formattedDate,
          statusLabel: statusLabel,
          groupId: groupId,
        ),
      );
    }
  }

  @override
  Future<List<AttendanceModel>> getStudentAttendanceHistory({
    required String studentId,
    String? groupId,
    int? page,
    int? pageSize,
  }) async {
    var query = _safeClient
        .from('attendance')
        .select('*, groups(name), users!student_id(full_name)')
        .eq('student_id', studentId);

    if (groupId != null && groupId.isNotEmpty) {
      query = query.eq('group_id', groupId);
    }

    var orderedQuery = query.order('date', ascending: false);
    if (page != null && pageSize != null) {
      final from = page * pageSize;
      final to = from + pageSize - 1;
      final response = await orderedQuery.range(from, to);
      final list = response as List<dynamic>;

      return list
          .map((json) => AttendanceModel.fromJson(json as Map<String, dynamic>))
          .toList();
    }

    final response = await orderedQuery;
    final list = response as List<dynamic>;

    return list
        .map((json) => AttendanceModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<AttendanceStats> getStudentAttendanceStats({
    required String studentId,
    String? groupId,
  }) async {
    final history = await getStudentAttendanceHistory(
      studentId: studentId,
      groupId: groupId,
    );

    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;

    for (final record in history) {
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
      totalSessions: history.length,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      excusedCount: excused,
    );
  }
}
