import 'package:equatable/equatable.dart';
import 'video_entity.dart';

class LibraryVideoEntity extends Equatable {
  final String id;
  final String tenantId;
  final String? folderId;
  final String title;
  final String? description;
  final String provider;
  final String? providerVideoId;
  final String? thumbnailUrl;
  final int duration;
  final VideoStatus status;
  final String? playbackUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int assignedLecturesCount;
  final List<String> assignedGroupNames;

  const LibraryVideoEntity({
    required this.id,
    required this.tenantId,
    this.folderId,
    required this.title,
    this.description,
    this.provider = 'bunny',
    this.providerVideoId,
    this.thumbnailUrl,
    this.duration = 0,
    this.status = VideoStatus.uploading,
    this.playbackUrl,
    required this.createdAt,
    required this.updatedAt,
    this.assignedLecturesCount = 0,
    this.assignedGroupNames = const [],
  });

  bool get isReady => status == VideoStatus.ready;
  bool get isProcessing =>
      status == VideoStatus.processing || status == VideoStatus.uploading;
  bool get isFailed => status == VideoStatus.failed;
  bool get isBunny => provider == 'bunny';
  bool get isYouTube => provider == 'youtube';

  String get formattedDuration {
    if (duration <= 0) return '00:00';
    final minutes = duration ~/ 60;
    final seconds = duration % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours.toString().padLeft(2, '0')}:${remainingMinutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  LibraryVideoEntity copyWith({
    String? id,
    String? tenantId,
    String? folderId,
    String? title,
    String? description,
    String? provider,
    String? providerVideoId,
    String? thumbnailUrl,
    int? duration,
    VideoStatus? status,
    String? playbackUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? assignedLecturesCount,
    List<String>? assignedGroupNames,
  }) {
    return LibraryVideoEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      description: description ?? this.description,
      provider: provider ?? this.provider,
      providerVideoId: providerVideoId ?? this.providerVideoId,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      playbackUrl: playbackUrl ?? this.playbackUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignedLecturesCount:
          assignedLecturesCount ?? this.assignedLecturesCount,
      assignedGroupNames: assignedGroupNames ?? this.assignedGroupNames,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    folderId,
    title,
    description,
    provider,
    providerVideoId,
    thumbnailUrl,
    duration,
    status,
    playbackUrl,
    createdAt,
    updatedAt,
    assignedLecturesCount,
    assignedGroupNames,
  ];
}
