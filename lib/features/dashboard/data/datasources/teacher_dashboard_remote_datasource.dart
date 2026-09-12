import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/supabase_service.dart';
import '../../domain/entities/teacher_radar_alerts.dart';

abstract class TeacherDashboardRemoteDataSource {
  Future<TeacherRadarAlerts> getTeacherRadarAlerts(String teacherId);
}

class TeacherDashboardRemoteDataSourceImpl implements TeacherDashboardRemoteDataSource {
  final SupabaseClient? _client;

  TeacherDashboardRemoteDataSourceImpl({SupabaseClient? client}) : _client = client;

  SupabaseClient get _c => _client ?? SupabaseService.client;

  @override
  Future<TeacherRadarAlerts> getTeacherRadarAlerts(String teacherId) async {
    try {
      final result = await _c.rpc<dynamic>(
        'get_teacher_radar_alerts',
        params: {'p_teacher_id': teacherId},
      );

      final Map<String, dynamic> data;
      if (result is Map) {
        data = Map<String, dynamic>.from(result);
      } else if (result is String) {
        final decoded = jsonDecode(result);
        data = decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
      } else {
        data = <String, dynamic>{};
      }

      final lowScoresList = data['low_scores'] as List<dynamic>? ?? [];
      final unwatchedList = data['unwatched_videos'] as List<dynamic>? ?? [];
      final overdueList = data['overdue_assignments'] as List<dynamic>? ?? [];

      return TeacherRadarAlerts(
        lowScores: lowScoresList.map((e) => RadarAlertItem.fromJson(e as Map<String, dynamic>)).toList(),
        unwatchedVideos: unwatchedList.map((e) => RadarAlertItem.fromJson(e as Map<String, dynamic>)).toList(),
        overdueAssignments: overdueList.map((e) => RadarAlertItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
    } on PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (e) {
      throw ServerException('Failed to load radar alerts: $e');
    }
  }
}
