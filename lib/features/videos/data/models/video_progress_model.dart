import '../../domain/entities/video_progress_entity.dart';

class VideoProgressModel extends VideoProgressEntity {
  const VideoProgressModel({
    super.id,
    required super.videoId,
    required super.studentId,
    required super.progressSeconds,
    required super.durationSeconds,
    required super.percentage,
    required super.completed,
    super.actualWatchSeconds = 0,
    super.isSkipped = false,
    required super.lastWatchedAt,
    super.furthestPositionSeconds = 0,
  });

  factory VideoProgressModel.fromJson(Map<String, dynamic> json) {
    return VideoProgressModel(
      id: json['id'] as String?,
      videoId: json['video_id'] as String,
      studentId: json['student_id'] as String,
      progressSeconds: json['progress_seconds'] as int? ?? 0,
      durationSeconds: json['duration_seconds'] as int? ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
      completed: json['completed'] as bool? ?? false,
      actualWatchSeconds: json['actual_watch_seconds'] as int? ?? 0,
      isSkipped: json['is_skipped'] as bool? ?? false,
      lastWatchedAt: json['last_watched_at'] != null
          ? DateTime.parse(json['last_watched_at'] as String)
          : DateTime.now(),
      furthestPositionSeconds: json['furthest_position_seconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson({String? tenantId}) {
    final map = <String, dynamic>{
      'video_id': videoId,
      'student_id': studentId,
      'progress_seconds': progressSeconds,
      'duration_seconds': durationSeconds,
      'percentage': percentage,
      'completed': completed,
      'actual_watch_seconds': actualWatchSeconds,
      'is_skipped': isSkipped,
      'last_watched_at': lastWatchedAt.toIso8601String(),
      'furthest_position_seconds': furthestPositionSeconds,
    };
    if (id != null) map['id'] = id;
    if (tenantId != null) map['tenant_id'] = tenantId;
    return map;
  }
}
