import '../../domain/entities/library_video_entity.dart';
import '../../domain/entities/video_entity.dart';

class LibraryVideoModel extends LibraryVideoEntity {
  const LibraryVideoModel({
    required super.id,
    required super.tenantId,
    super.folderId,
    required super.title,
    super.description,
    super.provider = 'bunny',
    super.providerVideoId,
    super.thumbnailUrl,
    super.duration = 0,
    super.status = VideoStatus.uploading,
    super.playbackUrl,
    required super.createdAt,
    required super.updatedAt,
    super.assignedLecturesCount = 0,
    super.assignedGroupNames = const [],
  });

  factory LibraryVideoModel.fromJson(Map<String, dynamic> json) {
    // If joined with videos or content for usage counts
    int lecturesCount = json['assigned_lectures_count'] as int? ?? 0;
    List<String> groupNames = [];

    final rawVideos = json['videos'];
    if (rawVideos is List) {
      lecturesCount = rawVideos.length;
      for (final v in rawVideos) {
        if (v is Map<String, dynamic>) {
          final content = v['content'] as Map<String, dynamic>?;
          final group = content?['group'] as Map<String, dynamic>?;
          final name = group?['name'] as String?;
          if (name != null && !groupNames.contains(name)) {
            groupNames.add(name);
          }
        }
      }
    }

    final rawGroupNames = json['assigned_group_names'];
    if (rawGroupNames is List) {
      groupNames = rawGroupNames.map((e) => e.toString()).toList();
    }

    return LibraryVideoModel(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String? ?? '',
      folderId: json['folder_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      provider: json['provider'] as String? ?? 'bunny',
      providerVideoId: json['provider_video_id'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      duration: json['duration'] as int? ?? 0,
      status: VideoStatus.fromString(json['status'] as String? ?? 'uploading'),
      playbackUrl: json['playback_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      assignedLecturesCount: lecturesCount,
      assignedGroupNames: groupNames,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'folder_id': folderId,
      'title': title,
      'description': description,
      'provider': provider,
      'provider_video_id': providerVideoId,
      'thumbnail_url': thumbnailUrl,
      'duration': duration,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
