import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
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
      // Execute all core queries concurrently via Future.wait
      // 1. Core student metrics & video telemetry (RPC get_student_360 with fallback)
      // 2. Urgent assignments
      // 3. Student assignment submissions
      // 4. Urgent exams
      // 5. Student exam attempts
      final coreStatsFuture = _fetchCoreStatsWithFallback(studentId);
      final assignmentsFuture = _fetchUrgentAssignments();
      final submissionsFuture = _fetchStudentSubmissions(studentId);
      final examsFuture = _fetchUrgentExams();
      final attemptsFuture = _fetchStudentAttempts(studentId);

      final results = await Future.wait<dynamic>(<Future<dynamic>>[
        coreStatsFuture,
        assignmentsFuture,
        submissionsFuture,
        examsFuture,
        attemptsFuture,
      ]);

      final coreStats = results[0] as _CoreDashboardData;
      final assignmentsData = results[1] as List<dynamic>;
      final submissionsData = results[2] as List<dynamic>;
      final examsData = results[3] as List<dynamic>;
      final attemptsData = results[4] as List<dynamic>;

      // Assemble urgent tasks
      final urgentTasks = _assembleUrgentTasks(
        coreStats.activeGroupName,
        assignmentsData,
        submissionsData,
        examsData,
        attemptsData,
      );

      return StudentDashboardStats(
        attendancePercentage: coreStats.attendancePercentage,
        examAverage: coreStats.examAverage,
        assignmentsSubmitted: coreStats.assignmentsSubmitted,
        videoCompletionPercentage: coreStats.videoCompletionPercentage,
        activeGroupName: coreStats.activeGroupName,
        activeGroupLevel: coreStats.activeGroupLevel,
        continueLearningItem: coreStats.continueLearningItem,
        urgentTasks: urgentTasks,
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message, code: e.code);
    } catch (e) {
      throw ServerException('Failed to load dashboard stats: $e');
    }
  }

  Future<_CoreDashboardData> _fetchCoreStatsWithFallback(String studentId) async {
    // 1. Fast path: Supabase RPC get_student_360 (single round-trip for 6 metrics)
    try {
      final result = await _supabase.rpc<dynamic>(
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

        // Active Group
        String groupName = 'No Active Group';
        String groupLevel = 'N/A';
        final groupsList = data['groups'] as List<dynamic>?;
        if (groupsList != null && groupsList.isNotEmpty) {
          final firstGroup = groupsList.first;
          if (firstGroup is Map<String, dynamic>) {
            final innerGroup = firstGroup['groups'];
            if (innerGroup is Map<String, dynamic>) {
              groupName = (innerGroup['name'] as String?) ?? groupName;
              groupLevel = (innerGroup['level'] as String?) ?? groupLevel;
            }
          }
        }

        // Attendance Percentage
        final attTotal = (data['attendance_total'] as num?)?.toDouble() ?? 0;
        final attPresent = (data['attendance_present'] as num?)?.toDouble() ?? 0;
        final attendancePercentage = attTotal > 0 ? (attPresent / attTotal) * 100 : 0.0;

        // Exam Average
        final examAverage = (data['exam_avg_percentage'] as num?)?.toDouble() ?? 0.0;

        // Assignments Submitted
        final assignmentsSubmitted = (data['submissions_total'] as num?)?.toInt() ?? 0;

        // Video Percentage
        final videoPercentage = (data['video_avg_percentage'] as num?)?.toDouble() ?? 0.0;

        // Continue learning video from video_insights
        ContinueLearningItem? continueItem;
        final insights = data['video_insights'] as List<dynamic>?;
        if (insights != null && insights.isNotEmpty) {
          for (final vi in insights) {
            if (vi is Map<String, dynamic>) {
              final completed = vi['completed'] == true;
              final progressSec = (vi['progress_seconds'] as num?)?.toInt() ?? 0;
              if (!completed && progressSec > 0) {
                final videoId = (vi['video_id'] as String?) ?? '';
                final title = (vi['video_title'] as String?) ?? 'Video Lesson';
                final durationSec = (vi['duration_seconds'] as num?)?.toInt() ?? 0;
                final pct = (vi['percentage'] as num?)?.toDouble() ?? 0.0;

                continueItem = ContinueLearningItem(
                  videoId: videoId,
                  contentId: videoId,
                  title: title,
                  groupName: groupName,
                  progressSeconds: progressSec,
                  durationSeconds: durationSec,
                  percentage: pct,
                );
                break;
              }
            }
          }
        }

        return _CoreDashboardData(
          attendancePercentage: attendancePercentage,
          examAverage: examAverage,
          assignmentsSubmitted: assignmentsSubmitted,
          videoCompletionPercentage: videoPercentage,
          activeGroupName: groupName,
          activeGroupLevel: groupLevel,
          continueLearningItem: continueItem,
        );
      }
    } catch (e) {
      AppLogger.w(
        'StudentDashboardRemoteDataSource',
        '⚡ RPC get_student_360 fallback triggered for $studentId: $e',
      );
    }

    // 2. Fallback path: Direct parallel queries
    return _fetchCoreStatsDirect(studentId);
  }

  Future<_CoreDashboardData> _fetchCoreStatsDirect(String studentId) async {
    final groupFuture = _supabase
        .from('group_members')
        .select('groups(name, level)')
        .eq('student_id', studentId)
        .eq('status', 'active')
        .maybeSingle();

    final attFuture = _supabase
        .from('attendance')
        .select('status')
        .eq('student_id', studentId);

    final examFuture = _supabase
        .from('exam_attempts')
        .select('percentage')
        .eq('student_id', studentId)
        .eq('status', 'submitted');

    final assignFuture = _supabase
        .from('assignment_submissions')
        .select('id')
        .eq('student_id', studentId);

    final vidPctFuture = _supabase
        .from('video_progress')
        .select('percentage')
        .eq('student_id', studentId);

    final vidContinueFuture = _supabase
        .from('video_progress')
        .select('''
          video_id,
          progress_seconds,
          duration_seconds,
          percentage,
          last_watched_at,
          videos (
            id,
            duration,
            content (
              id,
              title,
              status,
              groups (name)
            )
          )
        ''')
        .eq('student_id', studentId)
        .eq('completed', false)
        .gt('progress_seconds', 0)
        .order('last_watched_at', ascending: false)
        .limit(1)
        .maybeSingle();

    final directResults = await Future.wait<dynamic>(<Future<dynamic>>[
      groupFuture,
      attFuture,
      examFuture,
      assignFuture,
      vidPctFuture,
      vidContinueFuture,
    ]);

    final groupResponse = directResults[0] as Map<String, dynamic>?;
    final attendanceResponse = directResults[1] as List<dynamic>;
    final examResponse = directResults[2] as List<dynamic>;
    final assignmentsResponse = directResults[3] as List<dynamic>;
    final videoResponse = directResults[4] as List<dynamic>;
    final videoProgressResponse = directResults[5] as Map<String, dynamic>?;

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

    double attendancePercentage = 0;
    if (attendanceResponse.isNotEmpty) {
      final total = attendanceResponse.length;
      final presentCount = attendanceResponse
          .where((e) => (e as Map<String, dynamic>)['status'] == 'present')
          .length;
      attendancePercentage = (presentCount / total) * 100;
    }

    double examAverage = 0;
    if (examResponse.isNotEmpty) {
      double sum = 0;
      for (var e in examResponse) {
        final pct = (e as Map<String, dynamic>)['percentage'];
        if (pct != null) sum += (pct as num).toDouble();
      }
      examAverage = sum / examResponse.length;
    }

    final assignmentsCount = assignmentsResponse.length;

    double videoPercentage = 0;
    if (videoResponse.isNotEmpty) {
      double sum = 0;
      for (var e in videoResponse) {
        final pct = (e as Map<String, dynamic>)['percentage'];
        if (pct != null) sum += (pct as num).toDouble();
      }
      videoPercentage = sum / videoResponse.length;
    }

    ContinueLearningItem? continueItem;
    if (videoProgressResponse != null) {
      final vidMap = videoProgressResponse['videos'];
      if (vidMap is Map<String, dynamic>) {
        final contentMap = vidMap['content'];
        if (contentMap is Map<String, dynamic> && contentMap['status'] == 'published') {
          final title = (contentMap['title'] as String?) ?? 'Video Lesson';
          final contentId = (contentMap['id'] as String?) ?? '';
          final groupsMap = contentMap['groups'];
          String itemGroupName = groupName;
          if (groupsMap is Map<String, dynamic> && groupsMap['name'] != null) {
            itemGroupName = groupsMap['name'] as String;
          }
          final progressSec =
              (videoProgressResponse['progress_seconds'] as num?)?.toInt() ?? 0;
          final durationSec =
              (videoProgressResponse['duration_seconds'] as num?)?.toInt() ??
                  (vidMap['duration'] as num?)?.toInt() ??
                  0;
          final pct =
              (videoProgressResponse['percentage'] as num?)?.toDouble() ?? 0.0;

          continueItem = ContinueLearningItem(
            videoId: (videoProgressResponse['video_id'] as String?) ?? '',
            contentId: contentId,
            title: title,
            groupName: itemGroupName,
            progressSeconds: progressSec,
            durationSeconds: durationSec,
            percentage: pct,
          );
        }
      }
    }

    return _CoreDashboardData(
      attendancePercentage: attendancePercentage,
      examAverage: examAverage,
      assignmentsSubmitted: assignmentsCount,
      videoCompletionPercentage: videoPercentage,
      activeGroupName: groupName,
      activeGroupLevel: groupLevel,
      continueLearningItem: continueItem,
    );
  }

  Future<List<dynamic>> _fetchUrgentAssignments() async {
    try {
      final res = await _supabase
          .from('assignments')
          .select('''
            id,
            due_at,
            max_score,
            content (
              id,
              title,
              status,
              groups (name)
            )
          ''')
          .order('due_at', ascending: true)
          .limit(5);
      return res as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> _fetchStudentSubmissions(String studentId) async {
    try {
      final res = await _supabase
          .from('assignment_submissions')
          .select('assignment_id, status, score')
          .eq('student_id', studentId);
      return res as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> _fetchUrgentExams() async {
    try {
      final res = await _supabase
          .from('exams')
          .select('''
            id,
            max_score,
            end_at,
            content:content!exams_content_id_fkey (
              id,
              title,
              status,
              groups (name)
            )
          ''')
          .limit(5);
      return res as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> _fetchStudentAttempts(String studentId) async {
    try {
      final res = await _supabase
          .from('exam_attempts')
          .select('exam_id, status')
          .eq('student_id', studentId);
      return res as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  List<UrgentTaskItem> _assembleUrgentTasks(
    String groupName,
    List<dynamic> assignmentsData,
    List<dynamic> submissionsData,
    List<dynamic> examsData,
    List<dynamic> attemptsData,
  ) {
    final List<UrgentTaskItem> urgentTasks = [];

    final submittedMap = <String, Map<String, dynamic>>{};
    for (final s in submissionsData) {
      if (s is Map<String, dynamic> && s['assignment_id'] != null) {
        submittedMap[s['assignment_id'] as String] = s;
      }
    }

    for (final a in assignmentsData) {
      if (a is! Map<String, dynamic>) continue;
      final content = a['content'];
      if (content is Map<String, dynamic> && content['status'] == 'published') {
        final assignmentId = a['id'] as String;
        final submission = submittedMap[assignmentId];
        if (submission == null) {
          DateTime? dueAt;
          if (a['due_at'] != null) {
            dueAt = DateTime.tryParse(a['due_at'] as String);
          }
          final groups = content['groups'];
          String gName = groupName;
          if (groups is Map<String, dynamic> && groups['name'] != null) {
            gName = groups['name'] as String;
          }

          urgentTasks.add(UrgentTaskItem(
            id: assignmentId,
            title: (content['title'] as String?) ?? 'Homework',
            groupName: gName,
            taskType: 'assignment',
            dueAt: dueAt,
            status: 'pending',
            maxScore: (a['max_score'] as num?)?.toInt(),
          ));
        }
      }
    }

    final attemptedExamIds = <String>{};
    for (final att in attemptsData) {
      if (att is Map<String, dynamic> && att['status'] == 'submitted') {
        attemptedExamIds.add(att['exam_id'] as String);
      }
    }

    for (final ex in examsData) {
      if (ex is! Map<String, dynamic>) continue;
      final content = ex['content'];
      if (content is Map<String, dynamic> && content['status'] == 'published') {
        final examId = ex['id'] as String;
        if (!attemptedExamIds.contains(examId)) {
          DateTime? endAt;
          if (ex['end_at'] != null) {
            endAt = DateTime.tryParse(ex['end_at'] as String);
          }
          final groups = content['groups'];
          String gName = groupName;
          if (groups is Map<String, dynamic> && groups['name'] != null) {
            gName = groups['name'] as String;
          }

          urgentTasks.add(UrgentTaskItem(
            id: examId,
            title: (content['title'] as String?) ?? 'Assessment',
            groupName: gName,
            taskType: 'exam',
            dueAt: endAt,
            status: 'available',
            maxScore: (ex['max_score'] as num?)?.toInt(),
          ));
        }
      }
    }

    return urgentTasks;
  }
}

class _CoreDashboardData {
  final double attendancePercentage;
  final double examAverage;
  final int assignmentsSubmitted;
  final double videoCompletionPercentage;
  final String activeGroupName;
  final String activeGroupLevel;
  final ContinueLearningItem? continueLearningItem;

  const _CoreDashboardData({
    required this.attendancePercentage,
    required this.examAverage,
    required this.assignmentsSubmitted,
    required this.videoCompletionPercentage,
    required this.activeGroupName,
    required this.activeGroupLevel,
    this.continueLearningItem,
  });
}
