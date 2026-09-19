import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../attendance/data/models/attendance_model.dart';
import '../../../attendance/domain/entities/attendance_entity.dart';
import '../../domain/entities/child_entity.dart';
import '../models/child_model.dart';

abstract interface class ParentRemoteDataSource {
  Future<List<ChildModel>> getLinkedChildren();
  Future<ChildAcademicSummary> getChildAcademicSummary(String studentId);
}

class ParentRemoteDataSourceImpl implements ParentRemoteDataSource {
  final SupabaseClient? _client;

  ParentRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _safeClient => _client ?? SupabaseService.client;

  @override
  Future<List<ChildModel>> getLinkedChildren() async {
    final parentId = _safeClient.auth.currentUser?.id;
    if (parentId == null) {
      throw const AuthException('User is not authenticated');
    }

    final response = await _safeClient
        .from('parent_students')
        .select('''
          id,
          relationship,
          created_at,
          users!student_id(
            id,
            full_name,
            email,
            phone,
            avatar_url,
            status
          )
        ''')
        .eq('parent_id', parentId)
        .order('created_at', ascending: true);

    final list = response as List<dynamic>;
    return list
        .map((item) => ChildModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ChildAcademicSummary> getChildAcademicSummary(String studentId) async {
    // 1. Fetch attendance records for this child
    final attendanceRes = await _safeClient
        .from('attendance')
        .select('''
          id,
          tenant_id,
          group_id,
          student_id,
          date,
          status,
          note,
          marked_at,
          groups(name)
        ''')
        .eq('student_id', studentId)
        .order('date', ascending: false);

    final attendanceList = (attendanceRes as List<dynamic>)
        .map((item) => AttendanceModel.fromJson(item as Map<String, dynamic>))
        .toList();

    int present = 0;
    int absent = 0;
    int late = 0;
    int excused = 0;

    for (final item in attendanceList) {
      switch (item.status) {
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

    final totalClasses = attendanceList.length;
    final attendancePercentage = totalClasses > 0
        ? ((present + (0.5 * late)) / totalClasses) * 100.0
        : 100.0;

    // 2. Fetch exam attempts for this child
    final examsRes = await _safeClient
        .from('exam_attempts')
        .select('''
          id,
          exam_id,
          score,
          percentage,
          submitted_at,
          exams(
            id,
            max_score,
            content:content!exams_content_id_fkey(title)
          )
        ''')
        .eq('student_id', studentId)
        .eq('status', 'submitted')
        .order('submitted_at', ascending: false);

    final examsList = examsRes as List<dynamic>;
    final List<ParentExamResult> examResults = [];
    double totalPercentages = 0.0;

    for (final raw in examsList) {
      final map = raw as Map<String, dynamic>;
      final examData = map['exams'] as Map<String, dynamic>? ?? {};
      final contentData = examData['content'] as Map<String, dynamic>? ?? {};

      final examTitle = contentData['title'] as String? ?? 'Academic Exam';
      final score = (map['score'] as num?)?.toDouble() ?? 0.0;
      final maxScore = (examData['max_score'] as num?)?.toDouble() ?? 100.0;
      final percentage =
          (map['percentage'] as num?)?.toDouble() ??
          (maxScore > 0 ? (score / maxScore) * 100.0 : 0.0);
      final submittedAt = map['submitted_at'] != null
          ? DateTime.parse(map['submitted_at'] as String)
          : DateTime.now();

      totalPercentages += percentage;
      examResults.add(
        ParentExamResult(
          examId: map['exam_id'] as String? ?? '',
          examTitle: examTitle,
          score: score,
          maxScore: maxScore,
          percentage: percentage,
          submittedAt: submittedAt,
        ),
      );
    }

    final examsAverageScore = examResults.isNotEmpty
        ? totalPercentages / examResults.length
        : 0.0;

    // 3. Fetch enrolled groups
    final groupsRes = await _safeClient
        .from('group_members')
        .select('group_id, groups(name, level)')
        .eq('student_id', studentId)
        .eq('status', 'active');

    final List<String> enrolledGroups = [];
    for (final raw in groupsRes as List<dynamic>) {
      final map = raw as Map<String, dynamic>;
      final groupData = map['groups'] as Map<String, dynamic>?;
      if (groupData != null) {
        final name = groupData['name'] as String? ?? '';
        final level = groupData['level'] as String? ?? '';
        enrolledGroups.add(level.isNotEmpty ? '$name ($level)' : name);
      }
    }

    return ChildAcademicSummary(
      studentId: studentId,
      attendancePercentage: attendancePercentage,
      totalClasses: totalClasses,
      presentCount: present,
      absentCount: absent,
      lateCount: late,
      excusedCount: excused,
      examsCount: examResults.length,
      examsAverageScore: examsAverageScore,
      recentAttendance: attendanceList.take(5).toList(),
      recentExams: examResults.take(5).toList(),
      enrolledGroups: enrolledGroups,
    );
  }
}
