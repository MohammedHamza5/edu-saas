import 'package:flutter/material.dart';

import '../../domain/entities/chapter_entity.dart';
import '../models/lesson_studio_models.dart';
import 'lesson_studio_lecture_card.dart';
import 'lesson_studio_no_videos_placeholder.dart';
import 'lesson_studio_staging_deck.dart';

/// Coordinator widget managing the right-hand staging area and lecture cards.
class LessonStudioDeckCoordinator extends StatelessWidget {
  final List<ChapterEntity> chapters;
  final List<String> stagedOrder;
  final Map<String, StagedLecture> stagedLectures;
  final String? batchGlobalChapterId;
  final bool batchGlobalPublished;
  final bool isSaving;
  final bool hasFolders;
  final List<Map<String, dynamic>> availableExams;
  final VoidCallback onSelectFirstFolder;
  final VoidCallback onClearSelection;
  final ValueChanged<String?> onBatchChapterChanged;
  final VoidCallback onQuickCreateChapter;
  final ValueChanged<bool> onBatchPublishChanged;
  final void Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onSaveUnified;
  final void Function(StagedLecture staged) onRemoveVideo;
  final void Function(StagedLecture staged) onPickFromLibrary;
  final void Function(StagedLecture staged) onPickPdf;
  final void Function(StagedLecture staged, String? chapterId) onChapterChanged;
  final void Function(StagedLecture staged, bool isPublished) onPublishChanged;
  final void Function(StagedLecture staged, String examId, String examTitle)
      onAddExam;
  final void Function(StagedLecture staged, int examIndex) onRemoveExam;
  final void Function(StagedLecture staged) onRemovePdf;

  const LessonStudioDeckCoordinator({
    super.key,
    required this.chapters,
    required this.stagedOrder,
    required this.stagedLectures,
    required this.batchGlobalChapterId,
    required this.batchGlobalPublished,
    required this.isSaving,
    required this.hasFolders,
    required this.availableExams,
    required this.onSelectFirstFolder,
    required this.onClearSelection,
    required this.onBatchChapterChanged,
    required this.onQuickCreateChapter,
    required this.onBatchPublishChanged,
    required this.onReorder,
    required this.onSaveUnified,
    required this.onRemoveVideo,
    required this.onPickFromLibrary,
    required this.onPickPdf,
    required this.onChapterChanged,
    required this.onPublishChanged,
    required this.onAddExam,
    required this.onRemoveExam,
    required this.onRemovePdf,
  });

  @override
  Widget build(BuildContext context) {
    if (stagedOrder.isEmpty) {
      return LessonStudioNoVideosPlaceholder(
        hasFolders: hasFolders,
        onSelectFirstFolder: onSelectFirstFolder,
      );
    }

    return LessonStudioStagingDeck(
      chapters: chapters,
      stagedOrder: stagedOrder,
      stagedLectures: stagedLectures,
      batchGlobalChapterId: batchGlobalChapterId,
      batchGlobalPublished: batchGlobalPublished,
      isSaving: isSaving,
      onClearSelection: onClearSelection,
      onBatchChapterChanged: onBatchChapterChanged,
      onQuickCreateChapter: onQuickCreateChapter,
      onBatchPublishChanged: onBatchPublishChanged,
      onReorder: onReorder,
      onSaveUnified: onSaveUnified,
      cardBuilder: (ctx, staged, index, isOnlyOne) => LessonStudioLectureCard(
        staged: staged,
        index: index,
        chapters: chapters,
        isOnlyOne: isOnlyOne,
        availableExams: availableExams,
        onRemoveVideo: () => onRemoveVideo(staged),
        onPickFromLibrary: () => onPickFromLibrary(staged),
        onPickPdf: () => onPickPdf(staged),
        onChapterChanged: (val) => onChapterChanged(staged, val),
        onPublishChanged: (val) => onPublishChanged(staged, val),
        onAddExam: (examId, title) => onAddExam(staged, examId, title),
        onRemoveExam: (examIdx) => onRemoveExam(staged, examIdx),
        onRemovePdf: () => onRemovePdf(staged),
      ),
    );
  }
}
