import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../domain/entities/student_dashboard_stats.dart';

abstract class StudentDashboardRemoteDataSource {
  Future<StudentDashboardStats> getStudentDashboardStats(String studentId);
}

class StudentDashboardRemoteDataSourceImpl implements StudentDashboardRemoteDataSource {
  final SupabaseClient _supabase;

  StudentDashboardRemoteDataSourceImpl(this._supabase);

  @override
  Future<StudentDashboardStats> getStudentDashboardStats(String studentId) async {
    try {
      // 1. Fetch active group
      final groupResponse = await _supabase
          .from('group_members')
          .select('groups(name, level)')
          .eq('student_id', studentId)
          .eq('status', 'active')
          .maybeSingle();

      String groupName = 'No Active Group';
      String groupLevel = 'N/A';
      if (groupResponse != null && groupResponse['groups'] != null) {
        final g = groupResponse['groups'];
        if (g is Map<String, dynamic>) {
          groupName = (g['name'] as String?) ?? groupName;
          groupLevel = (g['level'] as String?) ?? groupLevel;
        } else if (g is List && g.isNotEmpty && g.first is Map<String, dynamic>) {
          final firstMap = g.first as Map<String, dynamic>;
          groupName = (firstMap['name'] as String?) ?? groupName;
          groupLevel = (firstMap['level'] as String?) ?? groupLevel;
        }
      }

      // 2. Fetch attendance percentage
      final attendanceResponse = await _supabase
          .from('attendance')
          .select('status')
          .eq('student_id', studentId);

      double attendancePercentage = 0;
      final attList = attendanceResponse as List<dynamic>;
      if (attList.isNotEmpty) {
        final total = attList.length;
        final presentCount = attList.where((e) => (e as Map<String, dynamic>)['status'] == 'present').length;
        attendancePercentage = (presentCount / total) * 100;
      }

      // 3. Fetch exam average
      final examResponse = await _supabase
          .from('exam_attempts')
          .select('percentage')
          .eq('student_id', studentId)
          .eq('status', 'submitted');

      double examAverage = 0;
      final examList = examResponse as List<dynamic>;
      if (examList.isNotEmpty) {
        double sum = 0;
        for (var e in examList) {
          final pct = (e as Map<String, dynamic>)['percentage'];
          if (pct != null) sum += (pct as num).toDouble();
        }
        examAverage = sum / examList.length;
      }

      // 4. Fetch assignments submitted
      final assignmentsResponse = await _supabase
          .from('assignment_submissions')
          .select('id')
          .eq('student_id', studentId);
      final assignmentsCount = (assignmentsResponse as List<dynamic>).length;

      // 5. Fetch video completion percentage
      final videoResponse = await _supabase
          .from('video_progress')
          .select('percentage')
          .eq('student_id', studentId);

      double videoPercentage = 0;
      final videoList = videoResponse as List<dynamic>;
      if (videoList.isNotEmpty) {
        double sum = 0;
        for (var e in videoList) {
          final pct = (e as Map<String, dynamic>)['percentage'];
          if (pct != null) sum += (pct as num).toDouble();
        }
        videoPercentage = sum / videoList.length;
      }

      return StudentDashboardStats(
        attendancePercentage: attendancePercentage,
        examAverage: examAverage,
        assignmentsSubmitted: assignmentsCount,
        videoCompletionPercentage: videoPercentage,
        activeGroupName: groupName,
        activeGroupLevel: groupLevel,
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException('Failed to load dashboard stats: $e');
    }
  }
}
