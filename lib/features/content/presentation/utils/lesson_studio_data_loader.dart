import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../../videos/domain/entities/video_folder_entity.dart';
import '../../../videos/domain/repositories/video_bank_repository.dart';
import '../../domain/entities/chapter_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/quick_create_chapter_dialog.dart';
import '../dialogs/select_material_from_library_dialog.dart';
import '../models/lesson_studio_models.dart';

/// Helper for preloading, checking video presence, picking assets, and staging lectures within a course.
class LessonStudioDataLoader {
  LessonStudioDataLoader._();

  /// Collects all video IDs and provider IDs currently in the course into sets for O(1) checks.
  static void populateCourseVideoIds({
    required BuildContext context,
    required Set<String> courseVideoIds,
    required Set<String> courseVideoProviderIds,
  }) {
    courseVideoIds.clear();
    courseVideoProviderIds.clear();
    final cubit = context.read<ContentCubit>();
    if (cubit.state is ContentLoaded) {
      for (final item in (cubit.state as ContentLoaded).items) {
        if (item.id.isNotEmpty) courseVideoIds.add(item.id);
        if (item.videoId != null) courseVideoIds.add(item.videoId!);
        if (item.videoProviderId != null) {
          courseVideoProviderIds.add(item.videoProviderId!);
        }
      }
    }
  }

  /// Determines whether a given video is already part of the target group in O(1) time.
  static bool isVideoAlreadyInCourse({
    required LibraryVideoEntity video,
    required String groupName,
    required Set<String> courseVideoIds,
    required Set<String> courseVideoProviderIds,
  }) {
    if (courseVideoIds.contains(video.id) ||
        (video.providerVideoId != null &&
            courseVideoProviderIds.contains(video.providerVideoId))) {
      return true;
    }
    for (final name in video.assignedGroupNames) {
      if (name.trim().toLowerCase() == groupName.trim().toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  /// Loads all folders and root videos from the video bank repository.
  static Future<
      ({
        List<VideoFolderEntity> folders,
        List<LibraryVideoEntity> rootVideos,
      })> loadInitialLibrary(VideoBankRepository repo) async {
    List<VideoFolderEntity> folders = [];
    List<LibraryVideoEntity> rootVideos = [];

    final foldersRes = await repo.getAllFolders();
    if (foldersRes.isSuccess) {
      folders = foldersRes.data;
    }
    final rootVideosRes = await repo.getVideos(folderId: null);
    if (rootVideosRes.isSuccess) {
      rootVideos = rootVideosRes.data;
    }
    return (folders: folders, rootVideos: rootVideos);
  }

  /// Loads videos belonging to a specific folder.
  static Future<List<LibraryVideoEntity>> loadVideosForFolder({
    required VideoBankRepository repo,
    required String? folderId,
  }) async {
    final res = await repo.getVideos(folderId: folderId);
    return res.isSuccess ? res.data : [];
  }

  /// Toggles all videos in a folder into or out of the staging selection.
  static void toggleFolderSelection({
    required List<LibraryVideoEntity> videos,
    required Map<String, LibraryVideoEntity> selectedVideos,
    required Map<String, StagedLecture> stagedLectures,
    required List<String> stagedOrder,
    required String? batchGlobalChapterId,
    required bool batchGlobalPublished,
  }) {
    if (videos.isEmpty) return;
    final allSelected = videos.every((v) => selectedVideos.containsKey(v.id));
    if (allSelected) {
      for (final v in videos) {
        selectedVideos.remove(v.id);
        stagedLectures.remove(v.id)?.dispose();
        stagedOrder.remove(v.id);
      }
    } else {
      for (final v in videos) {
        if (!selectedVideos.containsKey(v.id)) {
          selectedVideos[v.id] = v;
          stagedOrder.add(v.id);
          stagedLectures[v.id] = StagedLecture(
            video: v,
            initialTitle: v.title,
            chapterId: batchGlobalChapterId,
            isPublished: batchGlobalPublished,
          );
        }
      }
    }
  }

  /// Picks a local PDF file and assigns it to a staged lecture.
  static Future<void> pickPdf(StagedLecture staged) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      staged.pdfFile = result.files.first;
      staged.pdfBytes = result.files.first.bytes;
      staged.libraryMaterial = null;
    }
  }

  /// Picks a PDF material from the teacher's library and assigns it to a staged lecture.
  static Future<void> pickMaterialFromLibrary(
    BuildContext context,
    StagedLecture staged,
  ) async {
    final selected = await SelectMaterialFromLibraryDialog.show(context);
    if (selected != null) {
      staged.libraryMaterial = selected;
      staged.pdfFile = null;
      staged.pdfBytes = null;
    }
  }

  /// Opens the quick chapter creation dialog with feedback.
  static Future<ChapterEntity?> showQuickCreateChapterDialog(
    BuildContext context,
    String groupId,
  ) async {
    final l10n = context.l10n;
    final createdChapter = await QuickCreateChapterDialog.show(
      context,
      groupId: groupId,
    );
    if (createdChapter != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.chapterCreatedSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    }
    return createdChapter;
  }
}
