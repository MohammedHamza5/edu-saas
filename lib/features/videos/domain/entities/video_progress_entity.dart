import 'package:equatable/equatable.dart';

class VideoProgressEntity extends Equatable {
  final String? id;
  final String videoId;
  final String studentId;
  final int progressSeconds;
  final int durationSeconds;
  final double percentage;
  final bool completed;
  final int actualWatchSeconds;
  final bool isSkipped;
  final DateTime lastWatchedAt;

  const VideoProgressEntity({
    this.id,
    required this.videoId,
    required this.studentId,
    required this.progressSeconds,
    required this.durationSeconds,
    required this.percentage,
    required this.completed,
    this.actualWatchSeconds = 0,
    this.isSkipped = false,
    required this.lastWatchedAt,
  });

  /// Factory for a fresh zero-progress state
  factory VideoProgressEntity.initial({
    required String videoId,
    required String studentId,
  }) {
    return VideoProgressEntity(
      videoId: videoId,
      studentId: studentId,
      progressSeconds: 0,
      durationSeconds: 0,
      percentage: 0.0,
      completed: false,
      actualWatchSeconds: 0,
      isSkipped: false,
      lastWatchedAt: DateTime.now(),
    );
  }

  VideoProgressEntity copyWith({
    String? id,
    String? videoId,
    String? studentId,
    int? progressSeconds,
    int? durationSeconds,
    double? percentage,
    bool? completed,
    int? actualWatchSeconds,
    bool? isSkipped,
    DateTime? lastWatchedAt,
  }) {
    return VideoProgressEntity(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      studentId: studentId ?? this.studentId,
      progressSeconds: progressSeconds ?? this.progressSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      percentage: percentage ?? this.percentage,
      completed: completed ?? this.completed,
      actualWatchSeconds: actualWatchSeconds ?? this.actualWatchSeconds,
      isSkipped: isSkipped ?? this.isSkipped,
      lastWatchedAt: lastWatchedAt ?? this.lastWatchedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        videoId,
        studentId,
        progressSeconds,
        durationSeconds,
        percentage,
        completed,
        actualWatchSeconds,
        isSkipped,
        lastWatchedAt,
      ];
}
