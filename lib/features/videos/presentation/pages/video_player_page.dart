import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/utils/fullscreen_util.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/presentation/widgets/material_viewer_sheet.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_progress_entity.dart';
import '../cubit/videos_cubit.dart';
import '../cubit/videos_state.dart';
import '../widgets/app_video_player.dart';
import '../widgets/video_upload_dialog.dart';
import '../../../../core/services/student_activity_tracker.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoId;
  final String? studentId;
  final String? associatedExamId;
  final String? associatedExamTitle;

  const VideoPlayerPage({
    super.key,
    required this.videoId,
    this.studentId,
    this.associatedExamId,
    this.associatedExamTitle,
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
  void Function(int seconds)? _seekTo;
  bool _hasRecordedStarted = false;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthCubit>().state;
    final authUser = authState is AuthAuthenticated ? authState.user : null;
    _activeStudentId = widget.studentId ?? authUser?.id ?? '';
    _isTeacher = authUser?.isTeacher ?? false;
    _loadVideo();

    listenToFullscreenChange((isFull) {
      if (!kIsWeb && mounted && _isFullscreen != isFull) {
        setState(() {
          _isFullscreen = isFull;
        });
      }
    });
  }

  void _handleFullscreenChanged(bool isFull) {
    if (kIsWeb) {
      final currentWeb = checkIsFullscreen();
      if (isFull != currentWeb) {
        requestToggleFullscreen();
      }
    } else {
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

  bool _isFlushingProgress = false;

  Future<void> _flushProgressAndExit() async {
    if (_isFlushingProgress) return;
    _isFlushingProgress = true;

    if (!_isTeacher && _activeStudentId.isNotEmpty && _currentVideo != null) {
      final pos = _livePositionSecs.value;
      final dur = _liveDurationSecs.value > 0 ? _liveDurationSecs.value : _currentVideo!.duration;
      if (pos > 0 && dur > 0) {
        try {
          await context.read<VideosCubit>().updateProgress(
                videoId: _currentVideo!.id,
                studentId: _activeStudentId,
                progressSeconds: pos,
                durationSeconds: dur,
                force: true,
              );
        } catch (_) {
          try {
            await InjectionContainer.videosRepository.updateVideoProgress(
              videoId: _currentVideo!.id,
              studentId: _activeStudentId,
              progressSeconds: pos,
              durationSeconds: dur,
            );
          } catch (_) {}
        }
      }
    }

    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go(AppRoutes.studentDashboard);
      }
    }
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
    if (!_isFlushingProgress && !_isTeacher && _activeStudentId.isNotEmpty && _currentVideo != null) {
      final pos = _livePositionSecs.value;
      final dur = _liveDurationSecs.value > 0 ? _liveDurationSecs.value : _currentVideo!.duration;
      if (pos > 0 && dur > 0) {
        unawaited(InjectionContainer.videosRepository.updateVideoProgress(
          videoId: _currentVideo!.id,
          studentId: _activeStudentId,
          progressSeconds: pos,
          durationSeconds: dur,
        ));
      }
    }
    _livePositionSecs.dispose();
    _liveDurationSecs.dispose();
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
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _flushProgressAndExit();
      },
      child: Scaffold(
        backgroundColor: _isFullscreen ? Colors.black : theme.scaffoldBackgroundColor,
        appBar: _isFullscreen
            ? null
            : AppBar(
                title: Row(
            children: [
              const Icon(Icons.play_lesson_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  context.l10n.watchLessonTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Container(
              margin: const EdgeInsetsDirectional.only(end: AppSpacing.s16),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s10,
                vertical: AppSpacing.s4,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentVideo?.isYouTube == true ? Icons.play_circle_fill_rounded : Icons.lock_outline_rounded, 
                    size: 13, 
                    color: _currentVideo?.isYouTube == true ? const Color(0xFFFF0000) : AppColors.primary
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _currentVideo?.isYouTube == true ? 'Protected Streaming' : context.l10n.secureCdnBadge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _currentVideo?.isYouTube == true ? const Color(0xFFFF0000) : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          leading: BackButton(
            onPressed: _flushProgressAndExit,
          ),
        ),
        body: BlocBuilder<VideosCubit, VideosState>(
          buildWhen: (previous, current) {
            if (previous is VideosLoaded && current is VideosLoaded) {
              return previous.playbackUrl != current.playbackUrl ||
                  previous.currentVideo?.id != current.currentVideo?.id;
            }
            return previous != current;
          },
          builder: (context, state) {
            if (state is VideosLoading) {
              return AppLoadingView(message: state.message ?? context.l10n.loadingVideo);
            }

            if (state is VideosError) {
              return _buildErrorView(context, state);
            }

            if (state is VideosLoaded) {
              if (state.playbackUrl == null || state.playbackUrl!.isEmpty) {
                return _buildPendingUploadView(context, state.currentVideo);
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
                  _livePositionSecs.value = current;
                  _liveDurationSecs.value = total;
                },
                onSeekReady: (seekFn) {
                  _seekTo = seekFn;
                },
                onFullscreenChanged: _handleFullscreenChanged,
                onMetricsProgress: (currentSeconds, totalSeconds, actualWatch, isSkipped) {
                  if (!_isTeacher && _activeStudentId.isNotEmpty && video != null) {
                    if (!_hasRecordedStarted && currentSeconds > 0) {
                      _hasRecordedStarted = true;
                      StudentActivityTracker.instance.recordActivity(
                        eventType: 'video_started',
                        contentId: video.contentId,
                      );
                    }
                    final dur = totalSeconds > 0 ? totalSeconds : video.duration;
                    context.read<VideosCubit>().updateProgress(
                          videoId: video.id,
                          studentId: _activeStudentId,
                          progressSeconds: currentSeconds,
                          durationSeconds: dur,
                          actualWatchSeconds: actualWatch,
                          isSkipped: isSkipped,
                        );
                  }
                },
                onCompleted: () {
                  if (!_isTeacher && _activeStudentId.isNotEmpty && video != null) {
                    context.read<VideosCubit>().updateProgress(
                          videoId: video.id,
                          studentId: _activeStudentId,
                          progressSeconds: video.duration,
                          durationSeconds: video.duration,
                          force: true,
                        );
                    StudentActivityTracker.instance.recordActivity(
                      eventType: 'video_completed',
                      contentId: video.contentId,
                    );
                    if (widget.associatedExamId != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 6),
                          content: Text(context.l10n.videoCompletedCongrats),
                          action: SnackBarAction(
                            label: context.l10n.takeQuizNowAction,
                            textColor: Colors.white,
                            onPressed: () {
                              context.push(AppRoutes.studentExams);
                            },
                          ),
                        ),
                      );
                    }
                  }
                },
              );

              if (_isFullscreen && !kIsWeb) {
                return ColoredBox(
                  color: Colors.black,
                  child: SizedBox.expand(
                    child: Center(
                      child: videoPlayerWidget,
                    ),
                  ),
                );
              }

              return Center(
                child: ResponsiveContainer(
                  maxWidth: ResponsiveBreakpoints.maxWideContentWidth,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isDesktopTheater = constraints.maxWidth >= 960;

                      if (isDesktopTheater) {
                        // ── Wide Desktop Academic Theater Layout ─────────────
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSpacing.s24),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Main Column: Player
                              Expanded(
                                flex: 7,
                                child: videoPlayerWidget,
                              ),
                              const SizedBox(width: AppSpacing.s20),
                              // Right Sidebar: Academic Stats & Notes
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildAcademicStatsCard(theme, video, progress, isCompleted),
                                    const SizedBox(height: AppSpacing.s16),
                                    if (widget.associatedExamId != null) ...[
                                      _buildAssociatedExamCard(theme, isCompleted),
                                      const SizedBox(height: AppSpacing.s16),
                                    ],
                                    _buildAttachedMaterialCard(theme, video),
                                    const SizedBox(height: AppSpacing.s16),
                                    _buildLessonNotesCard(theme, video),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      // ── Mobile & Tablet Stacked Layout ───────────────────
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.s16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            videoPlayerWidget,
                            const SizedBox(height: AppSpacing.s16),
                            _buildAcademicStatsCard(theme, video, progress, isCompleted),
                            const SizedBox(height: AppSpacing.s16),
                            if (widget.associatedExamId != null) ...[
                              _buildAssociatedExamCard(theme, isCompleted),
                              const SizedBox(height: AppSpacing.s16),
                            ],
                            _buildAttachedMaterialCard(theme, video),
                            const SizedBox(height: AppSpacing.s16),
                            _buildLessonNotesCard(theme, video),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildPendingUploadView(BuildContext context, VideoEntity? video) {
    final theme = Theme.of(context);
    final authState = context.read<AuthCubit>().state;
    final isTeacher = authState is AuthAuthenticated && authState.user.isTeacher;

    return Center(
      child: ResponsiveContainer(
        maxWidth: ResponsiveBreakpoints.maxFormWidth,
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: AppCard(
          variant: AppCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.s32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: (isTeacher ? AppColors.primary : AppColors.warning).withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isTeacher ? AppColors.primary : AppColors.warning).withAlpha(60),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isTeacher ? Icons.cloud_upload_outlined : Icons.hourglass_top_rounded,
                  size: 36,
                  color: isTeacher ? AppColors.primary : AppColors.warning,
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              Text(
                video?.title ?? context.l10n.defaultLessonTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: (isTeacher ? AppColors.primary : AppColors.warning).withAlpha(15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: (isTeacher ? AppColors.primary : AppColors.warning).withAlpha(60),
                  ),
                ),
                child: Text(
                  isTeacher
                      ? context.l10n.teacherVideoNotUploadedBadge
                      : context.l10n.videoPendingUploadTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isTeacher ? AppColors.primary : AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                isTeacher
                    ? context.l10n.teacherVideoNotUploadedDesc
                    : context.l10n.studentVideoPendingUploadDesc,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              if (video?.description != null && video!.description!.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withAlpha(40),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(color: AppColors.border.withAlpha(50)),
                  ),
                  child: Text(
                    video.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s24),
              if (isTeacher) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: Text(context.l10n.uploadVideoAction),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(200, 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s24,
                      vertical: AppSpacing.s12,
                    ),
                  ),
                  onPressed: () {
                    VideoUploadDialog.show(
                      context,
                      contentId: video?.contentId ?? widget.videoId,
                      onUploadSuccess: _loadVideo,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              Wrap(
                spacing: AppSpacing.s12,
                runSpacing: AppSpacing.s8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(context.l10n.backToContentAction),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.l10n.retryAction),
                    onPressed: _loadVideo,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, VideosError state) {
    final authState = context.read<AuthCubit>().state;
    final isTeacher = authState is AuthAuthenticated && authState.user.isTeacher;

    final isNotFoundOrCoerce = state.code == 'VIDEO_NOT_FOUND' ||
        state.message.contains('Cannot coerce') ||
        state.message.contains('not found');

    final message = isNotFoundOrCoerce
        ? (isTeacher
            ? context.l10n.teacherVideoNotUploadedDesc
            : context.l10n.videoNotFoundMessage)
        : (state.code == 'VIDEO_NOT_READY'
            ? context.l10n.videoPlaybackError
            : state.message);

    return Center(
      child: ResponsiveContainer(
        maxWidth: ResponsiveBreakpoints.maxFormWidth,
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: AppCard(
          variant: AppCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_camera_back_outlined,
                size: 56,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              if (isTeacher) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: Text(context.l10n.uploadVideoAction),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s20,
                      vertical: AppSpacing.s12,
                    ),
                  ),
                  onPressed: () {
                    VideoUploadDialog.show(
                      context,
                      contentId: widget.videoId,
                      onUploadSuccess: _loadVideo,
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s12),
              ],
              Wrap(
                spacing: AppSpacing.s12,
                runSpacing: AppSpacing.s8,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: Text(context.l10n.backToContentAction),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.l10n.retryAction),
                    onPressed: _loadVideo,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicStatsCard(
    ThemeData theme,
    VideoEntity? video,
    VideoProgressEntity? progress,
    bool isCompleted,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge([_livePositionSecs, _liveDurationSecs]),
      builder: (context, _) {
        final livePos = _livePositionSecs.value > 0
            ? _livePositionSecs.value
            : (progress?.progressSeconds ?? 0);
        final liveDur = _liveDurationSecs.value > 0
            ? _liveDurationSecs.value
            : (video?.duration ?? progress?.durationSeconds ?? 0);
        final pct = liveDur > 0
            ? ((livePos / liveDur) * 100).clamp(0.0, 100.0)
            : (progress?.percentage ?? 0.0);
        final completed = isCompleted || pct >= 95.0;
        final remainingSecs = (liveDur - livePos).clamp(0, liveDur);

        return AppCard(
          variant: AppCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Title + Dynamic Status Pill
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.primary, AppColors.primaryLight],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      context.l10n.lessonAcademicProgress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  // Dynamic Status Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _isTeacher
                          ? AppColors.primary.withAlpha(20)
                          : completed
                              ? AppColors.success.withAlpha(20)
                              : pct > 0
                                  ? AppColors.primary.withAlpha(15)
                                  : AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(
                        color: _isTeacher
                            ? AppColors.primary.withAlpha(60)
                            : completed
                                ? AppColors.success.withAlpha(70)
                                : pct > 0
                                    ? AppColors.primary.withAlpha(50)
                                    : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isTeacher
                              ? Icons.sensors_rounded
                              : completed
                                  ? Icons.check_circle_rounded
                                  : pct > 0
                                      ? Icons.timelapse_rounded
                                      : Icons.radio_button_unchecked_rounded,
                          size: 11,
                          color: _isTeacher
                              ? AppColors.primary
                              : completed
                                  ? AppColors.success
                                  : pct > 0
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _isTeacher
                              ? context.l10n.teacherPreviewMode
                              : completed
                                  ? context.l10n.statusCompleted
                                  : pct > 0
                                      ? context.l10n.statusInProgress
                                      : context.l10n.statusNotStarted,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _isTeacher
                                ? AppColors.primary
                                : completed
                                    ? AppColors.success
                                    : pct > 0
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s16),

              // Hero Mathematical Metric Container
              Container(
                padding: const EdgeInsets.all(AppSpacing.s14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withAlpha(50),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: AppColors.border.withAlpha(60)),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Large mathematical percentage
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${pct.toInt()}%',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 30,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                context.l10n.remainingTime(_formatTime(remainingSecs)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        // Time elapsed/total badge + restart action
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.border.withAlpha(80),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${_formatTime(livePos)} / ${_formatTime(liveDur)}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: () => _seekTo?.call(0),
                              borderRadius: BorderRadius.circular(4),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.replay_rounded,
                                      size: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.l10n.restartLesson,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s14),

                    // Interactive Precision Progress Bar
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final barWidth = constraints.maxWidth;
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapDown: (details) {
                            if (liveDur > 0 && _seekTo != null && barWidth > 0) {
                              final ratio = (details.localPosition.dx / barWidth).clamp(0.0, 1.0);
                              final targetSecs = (ratio * liveDur).round();
                              _seekTo?.call(targetSecs);
                            }
                          },
                          child: Tooltip(
                            message: context.l10n.clickToSeek,
                            child: Container(
                              height: 18,
                              alignment: Alignment.center,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Track background
                                  Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  // Active Gradient Progress
                                  FractionallySizedBox(
                                    widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                                    child: Container(
                                      height: 8,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.primaryLight,
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withAlpha(90),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s12),

              // Educational completion touch / status banner
              if (completed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(color: AppColors.success.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.success,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          context.l10n.lessonCompletedSuccess,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withAlpha(35),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(color: AppColors.border.withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insights_rounded,
                        color: AppColors.primary,
                        size: 15,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          context.l10n.progressSavedAutomatically,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleOpenAttachedMaterial(VideoEntity video) async {
    final file = video.attachedFile;
    if (file == null) return;

    final contentWrapper = ContentEntity(
      id: video.contentId,
      tenantId: file.tenantId,
      groupId: '',
      title: video.title ?? file.fileName,
      description: video.description,
      type: ContentType.pdf,
      status: ContentStatus.published,
      file: file,
      createdAt: video.createdAt,
      updatedAt: video.updatedAt,
    );

    final cubit = context.read<VideosCubit>();
    await MaterialViewerSheet.show(
      context,
      content: contentWrapper,
      onGetSignedUrl: (storagePath) => cubit.getSignedFileUrl(storagePath),
    );
  }

  Future<void> _pickAndAttachPdf(VideoEntity video) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) return;

        if (!mounted) return;
        final cubit = context.read<VideosCubit>();
        setState(() => _isAttachingPdf = true);
        final success = await cubit.attachMaterialToVideo(
              videoId: video.id,
              contentId: video.contentId,
              fileName: file.name,
              fileBytes: bytes,
            );

        if (mounted) {
          setState(() => _isAttachingPdf = false);
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text(context.l10n.contentCreatedToast),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAttachingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  Widget _buildAssociatedExamCard(ThemeData theme, bool isInitiallyCompleted) {
    return AnimatedBuilder(
      animation: Listenable.merge([_livePositionSecs, _liveDurationSecs]),
      builder: (context, _) {
        final livePos = _livePositionSecs.value;
        final liveDur = _liveDurationSecs.value;
        final pct = liveDur > 0 ? (livePos / liveDur) * 100 : 0.0;
        final isUnlocked = _isTeacher || isInitiallyCompleted || pct >= 90.0;
        final themeColor = isUnlocked ? AppColors.success : AppColors.warning;

        return AppCard(
          variant: AppCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 18,
                    decoration: BoxDecoration(
                      color: themeColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      context.l10n.associatedExamBadge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: themeColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                      border: Border.all(
                        color: themeColor.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isUnlocked ? Icons.quiz_rounded : Icons.lock_outline_rounded,
                          size: 11,
                          color: themeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isUnlocked ? 'QUIZ' : 'LOCKED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: themeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isUnlocked
                    ? context.l10n.videoCompletedCongrats
                    : context.l10n.quizGateNotice,
                style: TextStyle(
                  fontSize: 11,
                  color: isUnlocked ? AppColors.success : AppColors.textSecondary,
                  fontWeight: isUnlocked ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: themeColor.withAlpha(70)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: themeColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                      ),
                      child: Icon(
                        isUnlocked ? Icons.quiz_rounded : Icons.lock_rounded,
                        size: 22,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.associatedExamTitle ?? context.l10n.associatedExamBadge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
              ElevatedButton.icon(
                icon: Icon(
                  isUnlocked ? Icons.arrow_forward_rounded : Icons.lock_outline_rounded,
                  size: 16,
                ),
                label: Text(
                  isUnlocked
                      ? context.l10n.takeQuizNowAction
                      : context.l10n.quizGateNotice,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isUnlocked ? AppColors.success : AppColors.surfaceVariant,
                  foregroundColor: isUnlocked ? Colors.white : AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s12,
                    horizontal: AppSpacing.s16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                ),
                onPressed: isUnlocked
                    ? () {
                        if (_isTeacher) {
                          context.push(AppRoutes.teacherExams);
                        } else {
                          context.push(AppRoutes.studentExams);
                        }
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachedMaterialCard(ThemeData theme, VideoEntity? video) {
    final attachedFile = video?.attachedFile;
    if (attachedFile == null && !_isTeacher) {
      return const SizedBox.shrink();
    }

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title + PDF Tag
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  context.l10n.attachedLessonMaterial,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withAlpha(20),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: const Color(0xFFEA580C).withAlpha(60),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 11,
                      color: Color(0xFFEA580C),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'PDF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            context.l10n.attachedLessonMaterialSubtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.s12),

          if (attachedFile != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withAlpha(25),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border.withAlpha(70)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withAlpha(20),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 22,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachedFile.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${attachedFile.formattedFileSize} • PDF',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            ElevatedButton.icon(
              icon: const Icon(Icons.download_rounded, size: 16),
              label: Text(context.l10n.viewAttachedPdf),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.s12,
                  horizontal: AppSpacing.s16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
              ),
              onPressed: () => _handleOpenAttachedMaterial(video!),
            ),
            if (_isTeacher) ...[
              const SizedBox(height: AppSpacing.s8),
              OutlinedButton.icon(
                icon: _isAttachingPdf
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 15),
                label: Text(context.l10n.attachPdfToLessonAction),
                onPressed: _isAttachingPdf ? null : () => _pickAndAttachPdf(video!),
              ),
            ],
          ] else if (_isTeacher) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withAlpha(20),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: AppColors.border.withAlpha(80),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.note_add_outlined,
                    size: 32,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    context.l10n.noAttachedMaterialForLesson,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isAttachingPdf
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(context.l10n.attachPdfToLessonAction),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s10,
                        ),
                      ),
                      onPressed:
                          _isAttachingPdf ? null : () => _pickAndAttachPdf(video!),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLessonNotesCard(ThemeData theme, VideoEntity? video) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            video?.title ?? context.l10n.defaultLessonTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Row(
            children: [
              const Icon(Icons.verified_user_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  context.l10n.protectedStreamCdnNotice,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (video?.description != null && video!.description!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s12),
            Text(
              context.l10n.lessonNotesAndTopics,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            Text(
              video.description!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Time Formatter Helper ───────────────────────────────────────────────────

String _formatTime(int totalSeconds) {
  if (totalSeconds < 0) totalSeconds = 0;
  final minutes = (totalSeconds ~/ 60).remainder(60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final hours = totalSeconds ~/ 3600;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
