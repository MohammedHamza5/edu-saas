import 'package:equatable/equatable.dart';
import '../../../content/domain/entities/file_attachment_entity.dart';

enum VideoStatus {
  uploading,
  processing,
  ready,
  failed,
  deleted;

  static VideoStatus fromString(String value) {
    return switch (value.toLowerCase()) {
      'uploading' => VideoStatus.uploading,
      'processing' => VideoStatus.processing,
      'ready' => VideoStatus.ready,
      'failed' => VideoStatus.failed,
      'deleted' => VideoStatus.deleted,
      _ => VideoStatus.uploading,
    };
  }

  String toDbString() => name;

  bool get isReady => this == VideoStatus.ready;
  bool get isProcessing => this == VideoStatus.processing || this == VideoStatus.uploading;
  bool get isFailed => this == VideoStatus.failed;
}

class VideoEntity extends Equatable {
  final String id;
  final String contentId;
  final String? title;
  final String? description;
  final String provider;
  final String? providerVideoId;
  final String? thumbnailUrl;
  final int duration; // in seconds
  final VideoStatus status;
  final String? playbackUrl; // Generated temporary tokenized HLS stream URL
  final FileAttachmentEntity? attachedFile;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VideoEntity({
    required this.id,
    required this.contentId,
    this.title,
    this.description,
    this.provider = 'bunny',
    this.providerVideoId,
    this.thumbnailUrl,
    this.duration = 0,
    this.status = VideoStatus.uploading,
    this.playbackUrl,
    this.attachedFile,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isYouTube => provider.toLowerCase() == 'youtube';
  bool get isBunny => provider.toLowerCase() == 'bunny';

  VideoEntity copyWith({
    String? id,
    String? contentId,
    String? title,
    String? description,
    String? provider,
    String? providerVideoId,
    String? thumbnailUrl,
    int? duration,
    VideoStatus? status,
    String? playbackUrl,
    FileAttachmentEntity? attachedFile,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VideoEntity(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      description: description ?? this.description,
      provider: provider ?? this.provider,
      providerVideoId: providerVideoId ?? this.providerVideoId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      attachedFile: attachedFile ?? this.attachedFile,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get formattedDuration {
    if (duration <= 0) return '00:00';
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remMinutes = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [
        id,
        contentId,
        title,
        description,
        provider,
        providerVideoId,
        thumbnailUrl,
        duration,
        status,
        playbackUrl,
        attachedFile,
        createdAt,
        updatedAt,
      ];
}
