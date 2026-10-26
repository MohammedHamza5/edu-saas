import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/fullscreen_util.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../content/domain/entities/attached_lesson_exam_entity.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../domain/entities/video_entity.dart';
import '../cubit/videos_cubit.dart';
import '../cubit/videos_state.dart';
import '../utils/video_pdf_helper.dart';
import '../utils/video_player_quiz_navigator.dart';
import '../utils/video_progress_tracker.dart';
import '../widgets/app_video_player.dart';
import '../widgets/video_course_lessons_sheet.dart';
import '../widgets/video_lesson_academic_panel.dart';
import '../widgets/video_pending_upload_view.dart';
import '../widgets/video_playback_error_view.dart';
import '../widgets/video_player_app_bar.dart';
import '../widgets/video_player_content_view.dart';
import '../widgets/video_sequential_navigation_bar.dart';

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

  /// بيانات الدرس الخاصة بالمجموعة (PDF + Exam من content_groups / lesson_exams)
  String? _groupPdfStoragePath;
  String? _groupPdfFileName;
  String? _preloadedPdfPath;
  String? _preloadedPdfUrl;
  bool _isOpeningPdf = false;
  String? _groupExamId;
  String? _groupExamTitle;

  ExamEntity? _lessonExam;
  List<LessonAssignmentEntity> _courseLessons = [];
  List<AttachedLessonExamEntity> _attachedExams = [];
  final Map<String, ExamEntity> _attachedExamDetails = {};

  List<AttachedLessonExamEntity> get _effectiveAttachedExams {
    if (_attachedExams.isNotEmpty) return _attachedExams;
    final legacyId = _groupExamId ?? widget.associatedExamId;
    if (legacyId != null && legacyId.isNotEmpty) {
      return [
        AttachedLessonExamEntity(
          examId: legacyId,
          examTitle:
              _lessonExam?.title ??
              _groupExamTitle ??
              widget.associatedExamTitle ??
              '',
          isRequired: true,
          sortOrder: 0,
          isPassed:
              _lessonExam?.myLatestAttempt?.isPassed(
                _lessonExam?.passingScore ?? 60,
              ) ??
              false,
          bestScore: _lessonExam?.myLatestAttempt?.score?.toDouble(),
          passingScore: _lessonExam?.passingScore ?? 60,
        ),
      ];
    }
    return const [];
  }

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
    // جلب بيانات الدرس الخاصة بالمجموعة إذا توفرت
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
    try {
      if (widget.groupId != null) {
        // Run course progress and lesson context concurrently (parallel round-trip)
        final progressFuture = !_isTeacher
            ? InjectionContainer.contentRepository.getGroupCourseProgress(
                groupId: widget.groupId!,
                studentId: _activeStudentId,
              )
            : null;

        final contextFuture = InjectionContainer.videosRepository
            .getLessonContext(
              contentId: widget.videoId, // videoId is content_id
              groupId: widget.groupId!,
            );

        final results = await Future.wait<dynamic>([
          progressFuture ?? Future.value(null),
          contextFuture,
        ]);

        if (!mounted) return;

        final lessonsResult =
            results[0] as Result<List<LessonAssignmentEntity>>?;
        final contextResult = results[1] as Result<Map<String, dynamic>?>;

        if (lessonsResult != null &&
            lessonsResult.isSuccess &&
            lessonsResult.dataOrNull != null) {
          final loadedLessons = lessonsResult.dataOrNull!;
          setState(() {
            _courseLessons = loadedLessons
                .where((l) => l.type == ContentType.video)
                .toList();
          });
          final current = loadedLessons
              .where(
                (LessonAssignmentEntity l) => l.contentId == widget.videoId,
              )
              .firstOrNull;
          if (current != null && current.attachedExams.isNotEmpty) {
            setState(() {
              _attachedExams = current.attachedExams;
            });
          }
        }

        contextResult.when(
          onSuccess: (Map<String, dynamic>? ctx) {
            if (ctx != null && mounted) {
              final examId =
                  ctx['lesson_exam_id'] as String? ?? widget.associatedExamId;
              final examTitle =
                  ctx['lesson_exam_title'] as String? ??
                  widget.associatedExamTitle;
              final rawAttached = ctx['attached_exams'] as List<dynamic>?;
              final parsedAttached = rawAttached != null
                  ? rawAttached
                        .map(
                          (e) => AttachedLessonExamEntity.fromJson(
                            e as Map<String, dynamic>,
                          ),
                        )
                        .toList()
                  : <AttachedLessonExamEntity>[];

              setState(() {
                _groupPdfStoragePath = ctx['pdf_storage_path'] as String?;
                _groupPdfFileName = ctx['pdf_file_name'] as String?;
                _groupExamId = examId;
                _groupExamTitle = examTitle;
                if (parsedAttached.isNotEmpty) {
                  _attachedExams = parsedAttached;
                  for (final att in parsedAttached) {
                    unawaited(
                      InjectionContainer.examsRepository
                          .getExamDetails(att.examId)
                          .then((res) {
                        if (res.isSuccess &&
                            res.dataOrNull != null &&
                            mounted) {
                          setState(() {
                            _attachedExamDetails[att.examId] = res.dataOrNull!;
                          });
                        }
                      }),
                    );
                  }
                }
              });
              if (_groupPdfStoragePath != null &&
                  _groupPdfStoragePath!.isNotEmpty) {
                _prewarmPdfUrl(_groupPdfStoragePath!);
              }
            }
          },
          onFailure: (_) {},
        );
      } else if (widget.associatedExamId != null) {
        final examResult = await InjectionContainer.examsRepository
            .getExamDetails(widget.associatedExamId!);
        if (examResult.isSuccess && examResult.dataOrNull != null && mounted) {
          final ex = examResult.dataOrNull!;
          setState(() {
            _lessonExam = ex;
            _attachedExamDetails[ex.id] = ex;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _startLessonQuiz(String examId) {
    return VideoPlayerQuizNavigator.startLessonQuiz(
      context: context,
      examId: examId,
      videoId: widget.videoId,
      courseLessons: _courseLessons,
      onReloadLessonContext: _loadLessonContext,
    );
  }

  Future<void> _openQuizResult(String examId) {
    return VideoPlayerQuizNavigator.openQuizResult(
      context: context,
      examId: examId,
      videoId: widget.videoId,
      courseLessons: _courseLessons,
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

    // Fire-and-forget progress flush in background so navigation happens instantly without lag
    unawaited(_forceFlushProgressToDB());

    if (mounted) {
      if (thenNavigateToLesson != null) {
        final encodedTitle = thenNavigateToLesson.lessonExamTitle != null
            ? Uri.encodeComponent(thenNavigateToLesson.lessonExamTitle!)
            : '';
        final encodedGroupName = widget.groupName != null
            ? Uri.encodeComponent(widget.groupName!)
            : '';
        final lIdx = lessonIndex ?? thenNavigateToLesson.sortOrder;
        final tLessons = totalLessons ?? _courseLessons.length;
        context.pushReplacement(
          '${AppRoutes.videoPlayer}?id=${thenNavigateToLesson.contentId}&associatedExamId=${thenNavigateToLesson.lessonExamId ?? ''}&associatedExamTitle=$encodedTitle&groupId=${widget.groupId}&groupName=$encodedGroupName&lessonIndex=$lIdx&totalLessons=$tLessons',
        );
      } else {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go(AppRoutes.studentDashboard);
        }
      }
    }
  }

  Future<void> _openLesson(
    LessonAssignmentEntity lesson,
    int lessonIndex,
    int totalLessons,
  ) async {
    if (lesson.isLocked) {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        ),
      );

      await _forceFlushProgressToDB();
      if (!mounted || !context.mounted) return;
      await _loadLessonContext();
      if (!mounted || !context.mounted) return;

      Navigator.of(context).pop();

      final updatedLesson = _courseLessons.firstWhere(
        (l) => l.contentId == lesson.contentId,
        orElse: () => lesson,
      );

      if (updatedLesson.isLocked) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                context.l10n.completeLessonToUnlock(
                  lessonIndex > 1 ? lessonIndex - 1 : 1,
                ),
              ),
            ),
          );
        }
        return;
      }

      lesson = updatedLesson;
    }

    await _flushProgressAndExit(
      thenNavigateToLesson: lesson,
      lessonIndex: lessonIndex,
      totalLessons: totalLessons,
    );
  }

  Widget _buildSequentialNavigationBar(ThemeData theme) {
    return VideoSequentialNavigationBar(
      courseLessons: _courseLessons,
      currentVideoId: widget.videoId,
      lessonIndex: widget.lessonIndex,
      totalLessons: widget.totalLessons,
      onOpenDrawer: _showCourseLessonsDrawer,
      onOpenLesson: (lesson, index, total) =>
          _openLesson(lesson, index, total),
    );
  }

  void _showCourseLessonsDrawer() {
    VideoCourseLessonsSheet.show(
      context: context,
      courseLessons: _courseLessons,
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
    // Fallback unawaited flush directly to repository in case exit didn't flush
    if (!_isFlushingProgress &&
        !_isTeacher &&
        _activeStudentId.isNotEmpty &&
        _currentVideo != null) {
      final pos = _livePositionSecs.value;
      final dur = _liveDurationSecs.value > 0
          ? _liveDurationSecs.value
          : _currentVideo!.duration;
      if (pos > 0 && dur > 0 && SupabaseService.isAuthenticated) {
        unawaited(
          InjectionContainer.videosRepository.updateVideoProgress(
            videoId: _currentVideo!.id,
            studentId: _activeStudentId,
            progressSeconds: pos,
            durationSeconds: dur,
            furthestPositionSeconds: _progressTracker.furthestPositionSecs,
            newSegment: _progressTracker.segmentStart != null &&
                    _progressTracker.segmentEnd != null
                ? [_progressTracker.segmentStart!, _progressTracker.segmentEnd!]
                : null,
          ),
        );
      }
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
        backgroundColor: _isFullscreen
            ? Colors.black
            : theme.scaffoldBackgroundColor,
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
              if (_groupPdfStoragePath == null &&
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

              final video = state.currentVideo;
              final playbackUrl = state.playbackUrl!;
              final progress = state.progress;
              final isCompleted = progress?.completed ?? false;
              final initialSeconds = progress?.progressSeconds ?? 0;

              _currentVideo = video;
              final videoPlayerWidget = AppVideoPlayer(
                key: _videoPlayerKey,
                streamUrl: playbackUrl,
                initialProgressSeconds: initialSeconds,
                totalDurationSeconds: video?.duration,
                isFullscreen: _isFullscreen,
                videoTitle: video?.title,
                onProgress: (current, total) {
                  if (current >= 0 && current != _livePositionSecs.value) {
                    _livePositionSecs.value = current;
                  }
                  if (total > 0 && total != _liveDurationSecs.value) {
                    _liveDurationSecs.value = total;
                  }
                  if (!_isPlayingNotifier.value && current > 0) {
                    _isPlayingNotifier.value = true;
                  }
                },
                onSeekReady: (seekFn) {
                  _seekTo = seekFn;
                },
                onFullscreenChanged: _handleFullscreenChanged,
                onMetricsProgress:
                    (currentSeconds, totalSeconds, actualWatch, isSkipped) {
                  _progressTracker.handleMetricsProgress(
                    video: video,
                    currentSeconds: currentSeconds,
                    totalSeconds: totalSeconds,
                    actualWatch: actualWatch,
                    isSkipped: isSkipped,
                  );
                },
                onCompleted: () {
                  _progressTracker.handleVideoCompleted(
                    video: video,
                    liveDurationSecs: _liveDurationSecs.value,
                    onMarkCompletedLocally: () {
                      if ((_groupExamId != null ||
                              widget.associatedExamId != null ||
                              _effectiveAttachedExams.isNotEmpty) &&
                          mounted) {
                        setState(() => _videoCompletedLocally = true);
                      }
                    },
                  );
                },
              );

              if (_isFullscreen && !kIsWeb) {
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
                livePositionSecs: _livePositionSecs,
                liveDurationSecs: _liveDurationSecs,
                isPlayingNotifier: _isPlayingNotifier,
                isTeacher: _isTeacher,
                videoCompletedLocally: _videoCompletedLocally,
                onSeekTo: (s) => _seekTo?.call(s),
                effectiveAttachedExams: _effectiveAttachedExams,
                attachedExamDetails: _attachedExamDetails,
                courseLessons: _courseLessons,
                videoId: widget.videoId,
                onOpenLesson: _openLesson,
                onOpenQuizResult: _openQuizResult,
                onStartLessonQuiz: _startLessonQuiz,
                groupId: widget.groupId,
                groupPdfStoragePath: _groupPdfStoragePath,
                groupPdfFileName: _groupPdfFileName,
                isAttachingPdf: _isAttachingPdf,
                isOpeningPdf: _isOpeningPdf,
                preloadedPdfPath: _preloadedPdfPath,
                preloadedPdfUrl: _preloadedPdfUrl,
                onOpenMaterial: _handleOpenAttachedMaterial,
                onOpenPdfDirectly: (v, {required bool hasGroupPdf}) =>
                    _handleOpenPdfDirectly(v, hasGroupPdf: hasGroupPdf),
                onPickAndAttachPdf: _pickAndAttachPdf,
              );

              return VideoPlayerContentView(
                videoPlayer: videoPlayerWidget,
                navigationBar: _buildSequentialNavigationBar(theme),
                academicPanel: academicPanel,
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
        ? _groupPdfStoragePath
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
