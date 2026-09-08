import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../domain/entities/attendance_entity.dart';
import '../models/attendance_model.dart';

abstract interface class AttendanceRemoteDataSource {
  Future<List<StudentAttendanceItem>> getGroupStudentsWithAttendance({
    required String groupId,
    required DateTime date,
  });

  Future<void> saveGroupAttendance({
    required String groupId,
    required DateTime date,
    required List<StudentAttendanceItem> items,
  });

  Future<List<AttendanceModel>> getStudentAttendanceHistory({
    required String studentId,
    String? groupId,
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
  Future<List<StudentAttendanceItem>> getGroupStudentsWithAttendance({
    required String groupId,
    required DateTime date,
  }) async {
    final formattedDate =
        "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    // 1. Fetch active group members with user details
    final membersResponse = await _safeClient
        .from('group_members')
        .select('student_id, users(id, full_name, phone, avatar_url, status)')
        .eq('group_id', groupId)
        .eq('status', 'active');

    final membersList = membersResponse as List<dynamic>;

    // 2. Fetch any existing attendance records for this group and date
    final existingRecordsResponse = await _safeClient
        .from('attendance')
        .select('id, student_id, status, note')
        .eq('group_id', groupId)
        .eq('date', formattedDate);

    final existingRecordsList = existingRecordsResponse as List<dynamic>;
    final existingMap = <String, Map<String, dynamic>>{};
    for (final record in existingRecordsList) {
      final studentId = record['student_id'] as String;
      existingMap[studentId] = record as Map<String, dynamic>;
    }

    // 3. Merge members with their attendance records
    final result = <StudentAttendanceItem>[];
    for (final item in membersList) {
      final studentId = item['student_id'] as String;
      final userData = item['users'] as Map<String, dynamic>?;

      // Filter out rejected or suspended students if needed
      final userStatus = userData?['status'] as String?;
      if (userStatus == 'suspended' || userStatus == 'rejected') {
        continue;
      }

      final studentName = userData?['full_name'] as String? ?? 'طالب';
      final avatarUrl = userData?['avatar_url'] as String?;
      final phone = userData?['phone'] as String?;

      final existingRecord = existingMap[studentId];
      if (existingRecord != null) {
        result.add(StudentAttendanceItem(
          studentId: studentId,
          studentName: studentName,
          avatarUrl: avatarUrl,
          phone: phone,
          status: AttendanceStatus.fromString(existingRecord['status'] as String?),
          note: existingRecord['note'] as String?,
          existingAttendanceId: existingRecord['id'] as String?,
        ));
      } else {
        // Default to present if not marked yet
        result.add(StudentAttendanceItem(
          studentId: studentId,
          studentName: studentName,
          avatarUrl: avatarUrl,
          phone: phone,
          status: AttendanceStatus.present,
          note: null,
          existingAttendanceId: null,
        ));
      }
    }

    // Sort alphabetically by student name
    result.sort((a, b) => a.studentName.compareTo(b.studentName));
    return result;
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
  }

  @override
  Future<List<AttendanceModel>> getStudentAttendanceHistory({
    required String studentId,
    String? groupId,
  }) async {
    var query = _safeClient
        .from('attendance')
        .select('*, groups(name), users(full_name)')
        .eq('student_id', studentId);

    if (groupId != null && groupId.isNotEmpty) {
      query = query.eq('group_id', groupId);
    }

    final response = await query.order('date', ascending: false);
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
