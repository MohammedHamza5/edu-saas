import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../../content/domain/entities/attached_lesson_exam_entity.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_progress_entity.dart';
import 'video_academic_stats_card.dart';
import 'video_associated_exams_section.dart';
import 'video_attached_material_card.dart';
import 'video_lesson_notes_card.dart';

class VideoLessonAcademicPanel extends StatelessWidget {
  final VideoEntity? video;
  final VideoProgressEntity? progress;
  final bool isCompleted;
  final ValueNotifier<int> livePositionSecs;
  final ValueNotifier<int> liveDurationSecs;
  final ValueNotifier<bool> isPlayingNotifier;
  final bool isTeacher;
  final bool videoCompletedLocally;
  final void Function(int seconds)? onSeekTo;

  final List<AttachedLessonExamEntity> effectiveAttachedExams;
  final Map<String, ExamEntity> attachedExamDetails;
  final List<LessonAssignmentEntity> courseLessons;
  final String videoId;
  final void Function(LessonAssignmentEntity lesson, int index, int total)
  onOpenLesson;
  final void Function(String examId) onOpenQuizResult;
  final void Function(String examId) onStartLessonQuiz;

  final String? groupId;
  final String? groupPdfStoragePath;
  final String? groupPdfFileName;
  final bool isAttachingPdf;
  final bool isOpeningPdf;
  final String? preloadedPdfPath;
  final String? preloadedPdfUrl;
  final void Function(VideoEntity video) onOpenMaterial;
  final void Function(VideoEntity? video, {required bool hasGroupPdf})
  onOpenPdfDirectly;
  final void Function(VideoEntity video) onPickAndAttachPdf;

  const VideoLessonAcademicPanel({
    super.key,
    required this.video,
    required this.progress,
    required this.isCompleted,
    required this.livePositionSecs,
    required this.liveDurationSecs,
    required this.isPlayingNotifier,
    required this.isTeacher,
    required this.videoCompletedLocally,
    required this.onSeekTo,
    required this.effectiveAttachedExams,
    required this.attachedExamDetails,
    required this.courseLessons,
    required this.videoId,
    required this.onOpenLesson,
    required this.onOpenQuizResult,
    required this.onStartLessonQuiz,
    required this.groupId,
    required this.groupPdfStoragePath,
    required this.groupPdfFileName,
    required this.isAttachingPdf,
    required this.isOpeningPdf,
    required this.preloadedPdfPath,
    required this.preloadedPdfUrl,
    required this.onOpenMaterial,
    required this.onOpenPdfDirectly,
    required this.onPickAndAttachPdf,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        VideoAcademicStatsCard(
          video: video,
          progress: progress,
          isCompleted: isCompleted,
          livePositionSecs: livePositionSecs,
          liveDurationSecs: liveDurationSecs,
          isPlayingNotifier: isPlayingNotifier,
          isTeacher: isTeacher,
          videoCompletedLocally: videoCompletedLocally,
          onSeekTo: onSeekTo,
        ),
        const SizedBox(height: AppSpacing.s16),
        if (effectiveAttachedExams.isNotEmpty) ...[
          VideoAssociatedExamsSection(
            livePositionSecs: livePositionSecs,
            liveDurationSecs: liveDurationSecs,
            currentVideo: video,
            isTeacher: isTeacher,
            isInitiallyCompleted: isCompleted,
            videoCompletedLocally: videoCompletedLocally,
            attachedExams: effectiveAttachedExams,
            attachedExamDetails: attachedExamDetails,
            courseLessons: courseLessons,
            videoId: videoId,
            onOpenLesson: onOpenLesson,
            onOpenQuizResult: onOpenQuizResult,
            onStartLessonQuiz: onStartLessonQuiz,
            onSeekTo: onSeekTo,
          ),
          const SizedBox(height: AppSpacing.s16),
        ],
        VideoAttachedMaterialCard(
          video: video,
          isTeacher: isTeacher,
          groupId: groupId,
          groupPdfStoragePath: groupPdfStoragePath,
          groupPdfFileName: groupPdfFileName,
          isAttachingPdf: isAttachingPdf,
          isOpeningPdf: isOpeningPdf,
          preloadedPdfPath: preloadedPdfPath,
          preloadedPdfUrl: preloadedPdfUrl,
          onOpenMaterial: onOpenMaterial,
          onOpenPdfDirectly: onOpenPdfDirectly,
          onPickAndAttachPdf: onPickAndAttachPdf,
        ),
        const SizedBox(height: AppSpacing.s16),
        VideoLessonNotesCard(video: video),
      ],
    );
  }
}
