import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../content/domain/entities/attached_lesson_exam_entity.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_progress_entity.dart';
import 'app_video_player.dart';
import 'video_lesson_academic_panel.dart';
import 'video_player_content_view.dart';
import 'video_sequential_navigation_bar.dart';

/// Loaded body view coordinator for VideoPlayerPage.
class VideoPlayerLoadedBody extends StatelessWidget {
  final GlobalKey videoPlayerKey;
  final VideoEntity? video;
  final String playbackUrl;
  final VideoProgressEntity? progress;
  final bool isFullscreen;
  final ValueNotifier<int> livePositionSecs;
  final ValueNotifier<int> liveDurationSecs;
  final ValueNotifier<bool> isPlayingNotifier;
  final bool isTeacher;
  final bool videoCompletedLocally;
  final List<AttachedLessonExamEntity> effectiveAttachedExams;
  final Map<String, ExamEntity> attachedExamDetails;
  final List<LessonAssignmentEntity> courseLessons;
  final String videoId;
  final String? groupId;
  final String? groupName;
  final int? lessonIndex;
  final int? totalLessons;
  final String? groupPdfStoragePath;
  final String? groupPdfFileName;
  final bool isAttachingPdf;
  final bool isOpeningPdf;
  final String? preloadedPdfPath;
  final String? preloadedPdfUrl;
  final void Function(int seconds)? onSeekTo;
  final ValueChanged<void Function(int seconds)> onSeekReady;
  final ValueChanged<bool> onFullscreenChanged;
  final void Function(
    int currentSeconds,
    int totalSeconds,
    int actualWatch,
    bool isSkipped,
  ) onMetricsProgress;
  final VoidCallback onCompleted;
  final Future<void> Function(
    LessonAssignmentEntity lesson,
    int lessonIndex,
    int totalLessons,
  ) onOpenLesson;
  final Future<void> Function(String examId) onOpenQuizResult;
  final Future<void> Function(String examId) onStartLessonQuiz;
  final Future<void> Function(VideoEntity video) onOpenMaterial;
  final Future<void> Function(VideoEntity? video, {required bool hasGroupPdf})
      onOpenPdfDirectly;
  final Future<void> Function(VideoEntity video) onPickAndAttachPdf;
  final VoidCallback onOpenDrawer;

  const VideoPlayerLoadedBody({
    super.key,
    required this.videoPlayerKey,
    required this.video,
    required this.playbackUrl,
    required this.progress,
    required this.isFullscreen,
    required this.livePositionSecs,
    required this.liveDurationSecs,
    required this.isPlayingNotifier,
    required this.isTeacher,
    required this.videoCompletedLocally,
    required this.effectiveAttachedExams,
    required this.attachedExamDetails,
    required this.courseLessons,
    required this.videoId,
    required this.groupId,
    required this.groupName,
    required this.lessonIndex,
    required this.totalLessons,
    required this.groupPdfStoragePath,
    required this.groupPdfFileName,
    required this.isAttachingPdf,
    required this.isOpeningPdf,
    required this.preloadedPdfPath,
    required this.preloadedPdfUrl,
    required this.onSeekTo,
    required this.onSeekReady,
    required this.onFullscreenChanged,
    required this.onMetricsProgress,
    required this.onCompleted,
    required this.onOpenLesson,
    required this.onOpenQuizResult,
    required this.onStartLessonQuiz,
    required this.onOpenMaterial,
    required this.onOpenPdfDirectly,
    required this.onPickAndAttachPdf,
    required this.onOpenDrawer,
  });

  @override
  Widget build(BuildContext context) {
    final initialSeconds = progress?.progressSeconds ?? 0;
    final isCompleted = progress?.completed ?? false;

    final videoPlayerWidget = AppVideoPlayer(
      key: videoPlayerKey,
      streamUrl: playbackUrl,
      initialProgressSeconds: initialSeconds,
      totalDurationSeconds: video?.duration,
      isFullscreen: isFullscreen,
      videoTitle: video?.title,
      onProgress: (current, total) {
        if (current >= 0 && current != livePositionSecs.value) {
          livePositionSecs.value = current;
        }
        if (total > 0 && total != liveDurationSecs.value) {
          liveDurationSecs.value = total;
        }
        if (!isPlayingNotifier.value && current > 0) {
          isPlayingNotifier.value = true;
        }
      },
      onSeekReady: onSeekReady,
      onFullscreenChanged: onFullscreenChanged,
      onMetricsProgress: onMetricsProgress,
      onCompleted: onCompleted,
    );

    if (isFullscreen && !kIsWeb) {
      return ColoredBox(
        color: Colors.black,
        child: SizedBox.expand(
          child: Center(child: videoPlayerWidget),
        ),
      );
    }

    final academicPanel = VideoLessonAcademicPanel(
      video: video,
      progress: progress,
      isCompleted: isCompleted,
      livePositionSecs: livePositionSecs,
      liveDurationSecs: liveDurationSecs,
      isPlayingNotifier: isPlayingNotifier,
      isTeacher: isTeacher,
      videoCompletedLocally: videoCompletedLocally,
      onSeekTo: onSeekTo,
      effectiveAttachedExams: effectiveAttachedExams,
      attachedExamDetails: attachedExamDetails,
      courseLessons: courseLessons,
      videoId: videoId,
      onOpenLesson: onOpenLesson,
      onOpenQuizResult: onOpenQuizResult,
      onStartLessonQuiz: onStartLessonQuiz,
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
    );

    final navigationBar = VideoSequentialNavigationBar(
      courseLessons: courseLessons,
      currentVideoId: videoId,
      lessonIndex: lessonIndex,
      totalLessons: totalLessons,
      onOpenDrawer: onOpenDrawer,
      onOpenLesson: (lesson, index, total) =>
          onOpenLesson(lesson, index, total),
    );

    return VideoPlayerContentView(
      videoPlayer: videoPlayerWidget,
      navigationBar: navigationBar,
      academicPanel: academicPanel,
    );
  }
}
