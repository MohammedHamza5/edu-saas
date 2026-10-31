import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/utils/fullscreen_util.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../domain/entities/video_entity.dart';
import '../cubit/videos_cubit.dart';
import '../cubit/videos_state.dart';
import '../utils/video_lesson_context_coordinator.dart';
import '../utils/video_lesson_navigator.dart';
import '../utils/video_pdf_helper.dart';
import '../utils/video_player_quiz_navigator.dart';
import '../utils/video_progress_tracker.dart';
import '../widgets/video_course_lessons_sheet.dart';
import '../widgets/video_pending_upload_view.dart';
import '../widgets/video_playback_error_view.dart';
import '../widgets/video_player_app_bar.dart';
import '../widgets/video_player_loaded_body.dart';

/// Video Player Page supporting authenticated playback, progress sync, sequential navigation, attached PDFs, and quizzes.
class VideoPlayerPage extends StatefulWidget {
  final String videoId;
  final String? studentId;
  final String? associatedExamId;
  final String? associatedExamTitle;

  /// المجموعة التي يُشاهَد منها هذا الدرس (لجلب PDF الخاص بالمجموعة والاختبار المخصص)
  final String? groupId;
  final String? groupName;
  final int? lessonIndex;
  final int? totalLessons;

  const VideoPlayerPage({
    super.key,
    required this.videoId,
    this.studentId,
    this.associatedExamId,
    this.associatedExamTitle,
    this.groupId,
    this.groupName,
    this.lessonIndex,
    this.totalLessons,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  final GlobalKey _videoPlayerKey = GlobalKey();
  late final String _activeStudentId;
  late final bool _isTeacher;
  bool _isFullscreen = false;
  bool _isAttachingPdf = false;
  VideoEntity? _currentVideo;
  final ValueNotifier<int> _livePositionSecs = ValueNotifier<int>(0);
  final ValueNotifier<int> _liveDurationSecs = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  void Function(int seconds)? _seekTo;

  late final VideoProgressTracker _progressTracker;

  /// حالة ما بعد اكتمال الفيديو
  bool _videoCompletedLocally = false;

  VideoLessonContextData _contextData = const VideoLessonContextData();
  String? _preloadedPdfPath;
  String? _preloadedPdfUrl;
  bool _isOpeningPdf = false;

  /// Pre-warms the signed URL in the background as soon as storage path is discovered.
  void _prewarmPdfUrl(String storagePath) {
    if (storagePath.isEmpty ||
        (_preloadedPdfPath == storagePath && _preloadedPdfUrl != null)) {
      return;
    }
    unawaited(
      context.read<VideosCubit>().getSignedFileUrl(storagePath).then((url) {
        if (mounted && url != null && url.isNotEmpty) {
          setState(() {
            _preloadedPdfPath = storagePath;
            _preloadedPdfUrl = url;
          });
        }
      }),
    );
  }

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthCubit>().state;
    final authUser = authState is AuthAuthenticated ? authState.user : null;
    _activeStudentId = widget.studentId ?? authUser?.id ?? '';
    _isTeacher = authUser?.isTeacher ?? false;

    _progressTracker = VideoProgressTracker(
      isTeacher: _isTeacher,
      studentId: _activeStudentId,
      cubit: context.read<VideosCubit>(),
      videosRepository: InjectionContainer.videosRepository,
    );

    _loadVideo();
    if (!_isTeacher) {
      _loadLessonContext();
    }

    listenToFullscreenChange((isFull) {
      if (!kIsWeb && mounted && _isFullscreen != isFull) {
        setState(() {
          _isFullscreen = isFull;
        });
      }
    });
  }

  Future<void> _loadLessonContext() async {
    final data = await VideoLessonContextCoordinator.load(
      videoId: widget.videoId,
      activeStudentId: _activeStudentId,
      isTeacher: _isTeacher,
      groupId: widget.groupId,
      associatedExamId: widget.associatedExamId,
      associatedExamTitle: widget.associatedExamTitle,
    );
    if (!mounted) return;
    setState(() {
      _contextData = data;
    });
    if (data.groupPdfStoragePath != null &&
        data.groupPdfStoragePath!.isNotEmpty) {
      _prewarmPdfUrl(data.groupPdfStoragePath!);
    }
  }

  Future<void> _startLessonQuiz(String examId) {
    return VideoPlayerQuizNavigator.startLessonQuiz(
      context: context,
      examId: examId,
      videoId: widget.videoId,
      courseLessons: _contextData.courseLessons,
      onReloadLessonContext: _loadLessonContext,
    );
  }

  Future<void> _openQuizResult(String examId) {
    return VideoPlayerQuizNavigator.openQuizResult(
      context: context,
      examId: examId,
      videoId: widget.videoId,
      courseLessons: _contextData.courseLessons,
      onReloadLessonContext: _loadLessonContext,
    );
  }

  void _handleFullscreenChanged(bool isFull) {
    if (!kIsWeb) {
      if (isFull) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
    if (mounted && _isFullscreen != isFull) {
      setState(() {
        _isFullscreen = isFull;
      });
    }
  }

  Future<void> _forceFlushProgressToDB() {
    return _progressTracker.forceFlushToDB(
      video: _currentVideo,
      livePositionSecs: _livePositionSecs.value,
      liveDurationSecs: _liveDurationSecs.value,
    );
  }

  bool _isFlushingProgress = false;

  Future<void> _flushProgressAndExit({
    LessonAssignmentEntity? thenNavigateToLesson,
    int? lessonIndex,
    int? totalLessons,
  }) async {
    if (_isFlushingProgress) return;
    _isFlushingProgress = true;
    await VideoLessonNavigator.flushProgressAndExit(
      context: context,
      forceFlushProgress: _forceFlushProgressToDB,
      thenNavigateToLesson: thenNavigateToLesson,
      lessonIndex: lessonIndex,
      totalLessons: totalLessons,
      groupId: widget.groupId,
      groupName: widget.groupName,
      courseLessons: _contextData.courseLessons,
    );
  }

  Future<void> _openLesson(
    LessonAssignmentEntity lesson,
    int lessonIndex,
    int totalLessons,
  ) {
    return VideoLessonNavigator.openLesson(
      context: context,
      lesson: lesson,
      lessonIndex: lessonIndex,
      totalLessons: totalLessons,
      groupId: widget.groupId,
      groupName: widget.groupName,
      courseLessons: _contextData.courseLessons,
      forceFlushProgress: _forceFlushProgressToDB,
      reloadLessonContext: _loadLessonContext,
    );
  }

  void _showCourseLessonsDrawer() {
    VideoCourseLessonsSheet.show(
      context: context,
      courseLessons: _contextData.courseLessons,
      currentVideoId: widget.videoId,
      groupName: widget.groupName,
      onLessonTap: (lesson, index, total) =>
          _openLesson(lesson, index, total),
    );
  }

  @override
  void dispose() {
    removeFullscreenListener();
    if (_isFullscreen) {
      if (kIsWeb) {
        if (checkIsFullscreen()) requestToggleFullscreen();
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    }
    if (!_isFlushingProgress) {
      unawaited(
        _progressTracker.forceFlushToDB(
          video: _currentVideo,
          livePositionSecs: _livePositionSecs.value,
          liveDurationSecs: _liveDurationSecs.value,
        ),
      );
    }
    _livePositionSecs.dispose();
    _liveDurationSecs.dispose();
    _isPlayingNotifier.dispose();
    super.dispose();
  }

  void _loadVideo() {
    context.read<VideosCubit>().loadVideoPlayback(
      videoId: widget.videoId,
      studentId: _activeStudentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        unawaited(_forceFlushProgressToDB());
      },
      child: Scaffold(
        backgroundColor:
            _isFullscreen ? Colors.black : theme.scaffoldBackgroundColor,
        appBar: _isFullscreen
            ? null
            : VideoPlayerAppBar(
                groupName: widget.groupName,
                currentVideo: _currentVideo,
                lessonIndex: widget.lessonIndex,
                totalLessons: widget.totalLessons,
                onBack: _flushProgressAndExit,
              ),
        body: BlocConsumer<VideosCubit, VideosState>(
          listener: (context, state) {
            if (state is VideosLoaded) {
              final attachedPath =
                  state.currentVideo?.attachedFile?.storagePath;
              if (_contextData.groupPdfStoragePath == null &&
                  attachedPath != null &&
                  attachedPath.isNotEmpty) {
                _prewarmPdfUrl(attachedPath);
              }
            }
          },
          buildWhen: (previous, current) {
            if (previous is VideosLoaded && current is VideosLoaded) {
              return previous.playbackUrl != current.playbackUrl ||
                  previous.currentVideo?.id != current.currentVideo?.id ||
                  previous.progress?.completed != current.progress?.completed;
            }
            return previous != current;
          },
          builder: (context, state) {
            if (state is VideosLoading) {
              return AppLoadingView(
                message: state.message ?? context.l10n.loadingVideo,
              );
            }

            if (state is VideosError) {
              return VideoPlaybackErrorView(
                state: state,
                videoId: widget.videoId,
                onUploadSuccess: _loadVideo,
                onRetry: _loadVideo,
              );
            }

            if (state is VideosLoaded) {
              if (state.playbackUrl == null || state.playbackUrl!.isEmpty) {
                return VideoPendingUploadView(
                  video: state.currentVideo,
                  videoId: widget.videoId,
                  onUploadSuccess: _loadVideo,
                  onRetry: _loadVideo,
                );
              }

              _currentVideo = state.currentVideo;

              return VideoPlayerLoadedBody(
                videoPlayerKey: _videoPlayerKey,
                video: state.currentVideo,
                playbackUrl: state.playbackUrl!,
                progress: state.progress,
                isFullscreen: _isFullscreen,
                livePositionSecs: _livePositionSecs,
                liveDurationSecs: _liveDurationSecs,
                isPlayingNotifier: _isPlayingNotifier,
                isTeacher: _isTeacher,
                videoCompletedLocally: _videoCompletedLocally,
                effectiveAttachedExams: _contextData.effectiveAttachedExams,
                attachedExamDetails: _contextData.attachedExamDetails,
                courseLessons: _contextData.courseLessons,
                videoId: widget.videoId,
                groupId: widget.groupId,
                groupName: widget.groupName,
                lessonIndex: widget.lessonIndex,
                totalLessons: widget.totalLessons,
                groupPdfStoragePath: _contextData.groupPdfStoragePath,
                groupPdfFileName: _contextData.groupPdfFileName,
                isAttachingPdf: _isAttachingPdf,
                isOpeningPdf: _isOpeningPdf,
                preloadedPdfPath: _preloadedPdfPath,
                preloadedPdfUrl: _preloadedPdfUrl,
                onSeekTo: _seekTo,
                onSeekReady: (seekFn) => _seekTo = seekFn,
                onFullscreenChanged: _handleFullscreenChanged,
                onMetricsProgress: (current, total, actualWatch, isSkipped) {
                  _progressTracker.handleMetricsProgress(
                    video: state.currentVideo,
                    currentSeconds: current,
                    totalSeconds: total,
                    actualWatch: actualWatch,
                    isSkipped: isSkipped,
                  );
                },
                onCompleted: () {
                  _progressTracker.handleVideoCompleted(
                    video: state.currentVideo,
                    liveDurationSecs: _liveDurationSecs.value,
                    onMarkCompletedLocally: () {
                      if (_contextData.effectiveAttachedExams.isNotEmpty &&
                          mounted) {
                        setState(() => _videoCompletedLocally = true);
                      }
                    },
                  );
                },
                onOpenLesson: _openLesson,
                onOpenQuizResult: _openQuizResult,
                onStartLessonQuiz: _startLessonQuiz,
                onOpenMaterial: _handleOpenAttachedMaterial,
                onOpenPdfDirectly: (v, {required bool hasGroupPdf}) =>
                    _handleOpenPdfDirectly(v, hasGroupPdf: hasGroupPdf),
                onPickAndAttachPdf: _pickAndAttachPdf,
                onOpenDrawer: _showCourseLessonsDrawer,
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Future<void> _handleOpenAttachedMaterial(VideoEntity video) {
    return VideoPdfHelper.openAttachedMaterial(
      context: context,
      video: video,
      preloadedPdfPath: _preloadedPdfPath,
      preloadedPdfUrl: _preloadedPdfUrl,
    );
  }

  Future<void> _handleOpenPdfDirectly(
    VideoEntity? video, {
    required bool hasGroupPdf,
  }) async {
    final storagePath = hasGroupPdf
        ? _contextData.groupPdfStoragePath
        : video?.attachedFile?.storagePath;
    if (storagePath == null || storagePath.isEmpty) return;

    final url = await VideoPdfHelper.openPdfDirectly(
      context: context,
      storagePath: storagePath,
      preloadedPdfPath: _preloadedPdfPath,
      preloadedPdfUrl: _preloadedPdfUrl,
      onOpeningStateChanged: (isOpening) {
        if (mounted) setState(() => _isOpeningPdf = isOpening);
      },
    );
    if (url != null && mounted) {
      setState(() {
        _preloadedPdfPath = storagePath;
        _preloadedPdfUrl = url;
      });
    }
  }

  Future<void> _pickAndAttachPdf(VideoEntity video) {
    return VideoPdfHelper.pickAndAttachPdf(
      context: context,
      video: video,
      onAttachingStateChanged: (isAttaching) {
        if (mounted) setState(() => _isAttachingPdf = isAttaching);
      },
    );
  }
}
