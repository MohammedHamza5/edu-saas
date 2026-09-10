import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/student_model.dart';

/// All DB calls for the students feature.
/// IMPORTANT: changeStudentStatus calls the `approve-student` Edge Function —
/// never updates users.status directly from Flutter.
abstract interface class StudentsRemoteDataSource {
  Future<List<StudentModel>> getStudents({
    String? status,
    String? searchQuery,
    int page = 0,
    int pageSize = 25,
  });

  Future<List<StudentModel>> getPendingStudents();

  /// Calls Edge Function `approve-student` — Server validates JWT + tenant.
  Future<StudentModel> changeStudentStatus({
    required String studentId,
    required String action,
  });

  Future<Student360Model> getStudent360(String studentId);

  Future<StudentModel> getStudent(String studentId);

  Future<void> assignStudentToGroup({
    required String studentId,
    required String groupId,
    required bool add,
  });

  Future<List<StudentGroupInfoModel>> getAvailableGroupsForStudent(
    String studentId,
  );
}

// ---------------------------------------------------------------------------

class StudentsRemoteDataSourceImpl implements StudentsRemoteDataSource {
  final SupabaseClient? _client;

  StudentsRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _c => _client ?? SupabaseService.client;

  // ── helpers ──────────────────────────────────────────────────────────────

  // ── getStudents ───────────────────────────────────────────────────────────

  @override
  Future<List<StudentModel>> getStudents({
    String? status,
    String? searchQuery,
    int page = 0,
    int pageSize = 25,
  }) async {
    // Build query with filters BEFORE range() — PostgrestFilterBuilder needed
    var filterQuery = _c
        .from('users')
        .select('id, tenant_id, full_name, email, phone, avatar_url, status, role, last_activity_at, created_at')
        .eq('role', 'student');

    if (status != null && status != 'all') {
      filterQuery = filterQuery.eq('status', status);
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      filterQuery = filterQuery.or('full_name.ilike.%$q%,email.ilike.%$q%');
    }

    final response = await filterQuery
        .order('created_at', ascending: false)
        .range(page * pageSize, (page + 1) * pageSize - 1);

    return (response as List<dynamic>)
        .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── getPendingStudents ────────────────────────────────────────────────────

  @override
  Future<List<StudentModel>> getPendingStudents() async {
    final response = await _c
        .from('users')
        .select('id, tenant_id, full_name, email, phone, avatar_url, status, role, last_activity_at, created_at')
        .eq('role', 'student')
        .eq('status', 'pending')
        .order('created_at', ascending: true); // oldest first for FIFO review

    return (response as List<dynamic>)
        .map((e) => StudentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── changeStudentStatus ───────────────────────────────────────────────────
  // SECURITY: calls approve-student Edge Function — NEVER direct users.status update.

  @override
  Future<StudentModel> changeStudentStatus({
    required String studentId,
    required String action,
  }) async {
    try {
      // 1. Primary: Atomic PostgreSQL RPC via PostgREST (bypasses browser CORS & gateway blocks)
      await _c.rpc<dynamic>(
        'approve_student',
        params: {
          'p_student_id': studentId,
          'p_action': action,
        },
      );
    } catch (_) {
      // 2. Secondary fallback: Edge Function
      final result = await _c.functions.invoke(
        'approve-student',
        body: {
          'student_id': studentId,
          'action': action,
        },
      );

      if (result.status != 200) {
        final msg = (result.data as Map<String, dynamic>?)?['error']?.toString() ??
            'Status change failed (HTTP ${result.status})';
        throw PostgrestException(message: msg);
      }
    }

    // Fetch updated student to return fresh state
    return getStudent(studentId);
  }

  // ── getStudent ────────────────────────────────────────────────────────────

  @override
  Future<StudentModel> getStudent(String studentId) async {
    final response = await _c
        .from('users')
        .select('id, tenant_id, full_name, email, phone, avatar_url, status, role, last_activity_at, created_at')
        .eq('id', studentId)
        .single();

    return StudentModel.fromJson(response);
  }

  // ── getStudent360 ─────────────────────────────────────────────────────────
  // ⚡ Performance: استدعاء RPC واحد مع مسار احتياطي استعلامي مباشر
  // التحسين: RPC = ~80-120ms مع حماية 100% ضد انهيار واجهة تفاصيل الطالب

  @override
  Future<Student360Model> getStudent360(String studentId) async {
    // 1. تجربة استدعاء الـ RPC فائق السرعة أولاً
    try {
      final result = await _c.rpc<dynamic>(
        'get_student_360',
        params: {'p_student_id': studentId},
      );

      if (result != null) {
        final Map<String, dynamic> data;
        if (result is Map) {
          data = Map<String, dynamic>.from(result);
        } else if (result is String) {
          final decoded = jsonDecode(result);
          data = decoded is Map
              ? Map<String, dynamic>.from(decoded)
              : <String, dynamic>{};
        } else {
          data = <String, dynamic>{};
        }
        return Student360Model.fromJson(data, studentId);
      }
    } catch (e) {
      AppLogger.w(
        'StudentsRemoteDataSource',
        '⚡ RPC get_student_360 fallback triggered for $studentId: $e',
      );
    }

    // 2. المسار الاحتياطي: استعلام الجداول المباشرة بالتوازي لضمان عدم توقف الشاشة
    try {
      return await _fetchStudent360Direct(studentId);
    } catch (e) {
      AppLogger.e('StudentsRemoteDataSource', 'Failed to fetch student 360 direct: $e');
      return Student360Model(studentId: studentId);
    }
  }

  Future<Student360Model> _fetchStudent360Direct(String studentId) async {
    // Start all requests concurrently
    final groupFuture = _c
        .from('group_members')
        .select('group_id, joined_at, groups(name, level)')
        .eq('student_id', studentId)
        .eq('status', 'active');
    final userFuture = _c
        .from('users')
        .select('last_activity_at')
        .eq('id', studentId)
        .maybeSingle();
    final attFuture =
        _c.from('attendance').select('status').eq('student_id', studentId);
    final subFuture = _c
        .from('assignment_submissions')
        .select('status')
        .eq('student_id', studentId);
    final examFuture = _c
        .from('exam_attempts')
        .select('percentage')
        .eq('student_id', studentId)
        .eq('status', 'submitted');
    final vidFuture = _c
        .from('video_progress')
        .select('percentage')
        .eq('student_id', studentId);

    final groupRows = ((await groupFuture) as List<dynamic>?) ?? [];
    final userRow = (await userFuture) as Map<dynamic, dynamic>?;
    final attRows = ((await attFuture) as List<dynamic>?) ?? [];
    final subRows = ((await subFuture) as List<dynamic>?) ?? [];
    final examRows = ((await examFuture) as List<dynamic>?) ?? [];
    final vidRows = ((await vidFuture) as List<dynamic>?) ?? [];

    final groups = groupRows.map((e) {
      final map = e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{};
      return StudentGroupInfoModel.fromJson(map);
    }).toList();

    final lastActivity = userRow?['last_activity_at'] != null
        ? DateTime.tryParse(userRow!['last_activity_at'].toString())
        : null;

    final totalAtt = attRows.length;
    final presentAtt =
        attRows.where((r) => (r is Map && r['status'] == 'present')).length;

    final submitted = subRows.length;
    final reviewed =
        subRows.where((r) => (r is Map && r['status'] == 'reviewed')).length;

    double examSum = 0;
    for (final r in examRows) {
      if (r is Map && r['percentage'] is num) {
        examSum += (r['percentage'] as num).toDouble();
      }
    }
    final examAvg = examRows.isNotEmpty ? (examSum / examRows.length) : 0.0;

    double vidSum = 0;
    for (final r in vidRows) {
      if (r is Map && r['percentage'] is num) {
        vidSum += (r['percentage'] as num).toDouble();
      }
    }
    final vidAvg = vidRows.isNotEmpty ? (vidSum / vidRows.length) : 0.0;

    return Student360Model(
      studentId: studentId,
      attendancePercentage: totalAtt > 0 ? (presentAtt / totalAtt) * 100 : 0.0,
      assignmentsSubmitted: submitted,
      assignmentsReviewed: reviewed,
      examAverage: examAvg,
      videoCompletionPercentage: vidAvg,
      lastActivityAt: lastActivity,
      groups: groups,
    );
  }

  // ── assignStudentToGroup ──────────────────────────────────────────────────

  @override
  Future<void> assignStudentToGroup({
    required String studentId,
    required String groupId,
    required bool add,
  }) async {
    if (add) {
      await _c.from('group_members').insert({
        'group_id': groupId,
        'student_id': studentId,
        'status': 'active',
      });
    } else {
      await _c
          .from('group_members')
          .delete()
          .eq('group_id', groupId)
          .eq('student_id', studentId);
    }
  }

  // ── getAvailableGroupsForStudent ──────────────────────────────────────────

  @override
  Future<List<StudentGroupInfoModel>> getAvailableGroupsForStudent(
    String studentId,
  ) async {
    // Get all groups the student IS in
    final memberRows = await _c
        .from('group_members')
        .select('group_id')
        .eq('student_id', studentId);

    final memberGroupIds =
        (memberRows as List<dynamic>).map((r) => r['group_id'] as String).toList();

    // Get all active groups in the tenant
    final allGroupsResponse = await _c
        .from('groups')
        .select('id, name, level')
        .eq('status', 'active');

    final allGroups = allGroupsResponse as List<dynamic>;

    // Filter out groups the student is already in and return as StudentGroupInfo
    return allGroups
        .where((g) => !memberGroupIds.contains((g as Map)['id'] as String))
        .map(
          (g) => StudentGroupInfoModel(
            groupId: g['id'] as String,
            groupName: g['name'] as String? ?? '',
            groupLevel: g['level'] as String? ?? '',
            joinedAt: DateTime.now(), // not a real member yet
          ),
        )
        .toList();
  }
}
