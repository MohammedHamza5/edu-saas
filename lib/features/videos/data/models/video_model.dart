import '../../../content/data/models/file_attachment_model.dart';
import '../../domain/entities/video_entity.dart';

class VideoModel extends VideoEntity {
  const VideoModel({
    required super.id,
    required super.contentId,
    super.title,
    super.description,
    super.provider = 'bunny',
    super.providerVideoId,
    super.thumbnailUrl,
    super.duration = 0,
    super.status = VideoStatus.uploading,
    super.playbackUrl,
    super.attachedFile,
    required super.createdAt,
    required super.updatedAt,
  });

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    // If content object is joined in the query:
    final content = json['content'] as Map<String, dynamic>?;
    final title = json['title'] as String? ?? content?['title'] as String?;
    final description = json['description'] as String? ?? content?['description'] as String?;

    FileAttachmentModel? attachedFile;
    final rawFiles = content?['files'] ?? json['files'];
    if (rawFiles != null) {
      if (rawFiles is List && rawFiles.isNotEmpty) {
        attachedFile = FileAttachmentModel.fromJson(rawFiles.first as Map<String, dynamic>);
      } else if (rawFiles is Map<String, dynamic>) {
        attachedFile = FileAttachmentModel.fromJson(rawFiles);
      }
    }

    return VideoModel(
      id: json['id'] as String,
      contentId: json['content_id'] as String? ?? json['id'] as String,
      title: title,
      description: description,
      provider: json['provider'] as String? ?? 'bunny',
      providerVideoId: json['provider_video_id'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      duration: json['duration'] as int? ?? 0,
      status: VideoStatus.fromString(json['status'] as String? ?? 'uploading'),
      playbackUrl: json['playback_url'] as String?,
      attachedFile: attachedFile,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content_id': contentId,
      'provider': provider,
      'provider_video_id': providerVideoId,
      'thumbnail_url': thumbnailUrl,
      'duration': duration,
      'status': status.toDbString(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  VideoModel copyWithPlaybackUrl(String url) {
    return VideoModel(
      id: id,
      contentId: contentId,
      title: title,
      description: description,
      provider: provider,
      providerVideoId: providerVideoId,
      thumbnailUrl: thumbnailUrl,
      duration: duration,
      status: status,
      playbackUrl: url,
      attachedFile: attachedFile,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
