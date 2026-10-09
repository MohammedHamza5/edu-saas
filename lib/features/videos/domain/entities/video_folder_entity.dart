import 'package:equatable/equatable.dart';

class FolderAssignedGroupInfo extends Equatable {
  final String groupId;
  final String groupName;
  final String? chapterId;
  final String? chapterTitle;

  const FolderAssignedGroupInfo({
    required this.groupId,
    required this.groupName,
    this.chapterId,
    this.chapterTitle,
  });

  factory FolderAssignedGroupInfo.fromJson(Map<String, dynamic> json) {
    return FolderAssignedGroupInfo(
      groupId: json['group_id'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
      chapterId: json['chapter_id'] as String?,
      chapterTitle: json['chapter_title'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'group_id': groupId,
      'group_name': groupName,
      'chapter_id': chapterId,
      'chapter_title': chapterTitle,
    };
  }

  @override
  List<Object?> get props => [groupId, groupName, chapterId, chapterTitle];
}

class VideoFolderEntity extends Equatable {
  final String id;
  final String tenantId;
  final String? parentId;
  final String name;
  final String? color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int videoCount;
  final int subfolderCount;
  final int totalDurationSeconds;
  final int readyVideoCount;
  final int assignedChaptersCount;
  final List<FolderAssignedGroupInfo> assignedGroups;

  const VideoFolderEntity({
    required this.id,
    required this.tenantId,
    this.parentId,
    required this.name,
    this.color,
    required this.createdAt,
    required this.updatedAt,
    this.videoCount = 0,
    this.subfolderCount = 0,
    this.totalDurationSeconds = 0,
    this.readyVideoCount = 0,
    this.assignedChaptersCount = 0,
    this.assignedGroups = const [],
  });

  bool get isAssigned => assignedChaptersCount > 0 || assignedGroups.isNotEmpty;
  bool get hasVideos => videoCount > 0;
  bool get allVideosReady => videoCount > 0 && readyVideoCount == videoCount;
  bool get hasPendingVideos => videoCount > 0 && readyVideoCount < videoCount;

  String? get primaryAssignedGroupName =>
      assignedGroups.isNotEmpty ? assignedGroups.first.groupName : null;

  String? get primaryAssignedChapterTitle =>
      assignedGroups.isNotEmpty ? assignedGroups.first.chapterTitle : null;

  VideoFolderEntity copyWith({
    String? id,
    String? tenantId,
    String? parentId,
    String? name,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? videoCount,
    int? subfolderCount,
    int? totalDurationSeconds,
    int? readyVideoCount,
    int? assignedChaptersCount,
    List<FolderAssignedGroupInfo>? assignedGroups,
  }) {
    return VideoFolderEntity(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      videoCount: videoCount ?? this.videoCount,
      subfolderCount: subfolderCount ?? this.subfolderCount,
      totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      readyVideoCount: readyVideoCount ?? this.readyVideoCount,
      assignedChaptersCount:
          assignedChaptersCount ?? this.assignedChaptersCount,
      assignedGroups: assignedGroups ?? this.assignedGroups,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tenantId,
    parentId,
    name,
    color,
    createdAt,
    updatedAt,
    videoCount,
    subfolderCount,
    totalDurationSeconds,
    readyVideoCount,
    assignedChaptersCount,
    assignedGroups,
  ];
}
