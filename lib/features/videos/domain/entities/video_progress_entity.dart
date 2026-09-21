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
  /// أبعد نقطة وصل إليها الطالب (للعودة أو تتبع الاستئناف)
  final int furthestPositionSeconds;
  /// النسب المئوية للمشاهدة الفعلية المحسوبة بناء على فترات المشاهدة
  final double watchedCoveragePercentage;
  /// فترات المشاهدة [start, end]
  final List<List<int>> watchedSegments;

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
    this.furthestPositionSeconds = 0,
    this.watchedCoveragePercentage = 0.0,
    this.watchedSegments = const [],
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
      furthestPositionSeconds: 0,
      watchedCoveragePercentage: 0.0,
      watchedSegments: const [],
    );
  }

  /// هل أكمل الطالب 90% من الفيديو فعلياً؟ (يعتمد الآن على completed التي يحسبها السيرفر أو watchedCoveragePercentage)
  bool get hasWatched90Percent => completed || watchedCoveragePercentage >= 90.0;

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
    int? furthestPositionSeconds,
    double? watchedCoveragePercentage,
    List<List<int>>? watchedSegments,
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
      furthestPositionSeconds: furthestPositionSeconds ?? this.furthestPositionSeconds,
      watchedCoveragePercentage: watchedCoveragePercentage ?? this.watchedCoveragePercentage,
      watchedSegments: watchedSegments ?? this.watchedSegments,
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
        furthestPositionSeconds,
        watchedCoveragePercentage,
        watchedSegments,
      ];
}
