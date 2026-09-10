import 'package:equatable/equatable.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_progress_entity.dart';

sealed class VideosState extends Equatable {
  const VideosState();

  @override
  List<Object?> get props => [];
}

final class VideosInitial extends VideosState {
  const VideosInitial();
}

final class VideosLoading extends VideosState {
  final String? message;
  const VideosLoading({this.message});

  @override
  List<Object?> get props => [message];
}

final class VideosLoaded extends VideosState {
  final List<VideoEntity> videos;
  final VideoEntity? currentVideo;
  final String? playbackUrl;
  final VideoProgressEntity? progress;

  const VideosLoaded({
    this.videos = const [],
    this.currentVideo,
    this.playbackUrl,
    this.progress,
  });

  VideosLoaded copyWith({
    List<VideoEntity>? videos,
    VideoEntity? currentVideo,
    String? playbackUrl,
    VideoProgressEntity? progress,
  }) {
    return VideosLoaded(
      videos: videos ?? this.videos,
      currentVideo: currentVideo ?? this.currentVideo,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      progress: progress ?? this.progress,
    );
  }

  @override
  List<Object?> get props => [videos, currentVideo, playbackUrl, progress];
}

final class VideoUploading extends VideosState {
  final double progress; // 0.0 to 1.0
  final int sentBytes;
  final int totalBytes;

  const VideoUploading({
    required this.progress,
    required this.sentBytes,
    required this.totalBytes,
  });

  int get percentage => (progress * 100).toInt();

  @override
  List<Object?> get props => [progress, sentBytes, totalBytes];
}

final class VideoUploadSuccess extends VideosState {
  final VideoEntity video;
  const VideoUploadSuccess(this.video);

  @override
  List<Object?> get props => [video];
}

final class VideosError extends VideosState {
  final String message;
  final String? code;

  const VideosError(this.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}
