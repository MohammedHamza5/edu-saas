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
import '../../../content/domain/entities/lesson_assignment_entity.dart';
import '../../../content/presentation/widgets/material_viewer_sheet.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../../exams/presentation/cubit/exams_cubit.dart';
import '../../../exams/presentation/pages/exam_intro_page.dart';
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
  VoidCallback? _togglePlayPauseFn;
  bool _hasRecordedStarted = false;
  /// أبعد نقطة مشاهدة لإرسالها مع كل update
  int _furthestPositionSecs = 0;
  
  /// Segment tracking for watched coverage
  int? _segmentStart;
  int? _segmentEnd;

  /// حالة ما بعد اكتمال الفيديو
  bool _videoCompletedLocally = false;
  /// بيانات الدرس الخاصة بالمجموعة (PDF + Exam من content_groups)
  String? _groupPdfStoragePath;
  String? _groupPdfFileName;
  String? _groupExamId;
  String? _groupExamTitle;
  ExamEntity? _lessonExam;
  List<LessonAssignmentEntity> _courseLessons = [];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthCubit>().state;
    final authUser = authState is AuthAuthenticated ? authState.user : null;
    _activeStudentId = widget.studentId ?? authUser?.id ?? '';
    _isTeacher = authUser?.isTeacher ?? false;
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
      if (widget.groupId != null && !_isTeacher) {
        final lessonsResult = await InjectionContainer.contentRepository.getGroupCourseProgress(
          groupId: widget.groupId!,
          studentId: _activeStudentId,
        );
        if (lessonsResult.isSuccess && lessonsResult.dataOrNull != null && mounted) {
          setState(() {
            _courseLessons = lessonsResult.dataOrNull!;
          });
        }
      }

      if (widget.groupId != null) {
        final result = await InjectionContainer.videosRepository.getLessonContext(
          contentId: widget.videoId,  // videoId هنا هو content_id
          groupId: widget.groupId!,
        );
        result.when(
          onSuccess: (ctx) {
            if (ctx != null && mounted) {
              final examId = ctx['lesson_exam_id'] as String? ?? widget.associatedExamId;
              final examTitle = ctx['lesson_exam_title'] as String? ?? widget.associatedExamTitle;
              setState(() {
                _groupPdfStoragePath = ctx['pdf_storage_path'] as String?;
                _groupPdfFileName = ctx['pdf_file_name'] as String?;
                _groupExamId = examId;
                _groupExamTitle = examTitle;
              });
              if (examId != null && examId.isNotEmpty) {
                InjectionContainer.examsRepository.getExamDetails(examId).then((examResult) {
                  if (examResult.isSuccess && examResult.dataOrNull != null && mounted) {
                    setState(() {
                      _lessonExam = examResult.dataOrNull;
                    });
                  }
                });
              }
            }
          },
          onFailure: (_) {},
        );
      } else if (widget.associatedExamId != null) {
        final examResult = await InjectionContainer.examsRepository.getExamDetails(widget.associatedExamId!);
        if (examResult.isSuccess && examResult.dataOrNull != null && mounted) {
          setState(() {
            _lessonExam = examResult.dataOrNull;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _startLessonQuiz(String examId) async {
    try {
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        ),
      );
      final result = await InjectionContainer.examsRepository.getExamDetails(examId);
      if (mounted) Navigator.of(context).pop();

      if (result.isSuccess && result.dataOrNull != null) {
        final exam = result.dataOrNull!;
        final examsCubit = InjectionContainer.createExamsCubit();
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider<ExamsCubit>.value(
              value: examsCubit,
              child: ExamIntroPage(exam: exam),
            ),
          ),
        );
        if (mounted) {
          await _loadLessonContext();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(result.failureOrNull?.message ?? context.l10n.errorOccurred),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text(e.toString())),
        );
      }
    }
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

  Future<void> _flushProgressAndExit({
    LessonAssignmentEntity? thenNavigateToLesson,
    int? lessonIndex,
    int? totalLessons,
  }) async {
    if (_isFlushingProgress) return;
    _isFlushingProgress = true;

    if (!_isTeacher && _activeStudentId.isNotEmpty && _currentVideo != null) {
      final pos = _livePositionSecs.value;
      final dur = _liveDurationSecs.value > 0
          ? _liveDurationSecs.value
          : _currentVideo!.duration;
      if (pos > 0 && dur > 0) {
        try {
          await context.read<VideosCubit>().updateProgress(
            videoId: _currentVideo!.id,
            studentId: _activeStudentId,
            progressSeconds: pos,
            durationSeconds: dur,
            furthestPositionSeconds: _furthestPositionSecs,
            force: true,
            newSegment: _segmentStart != null && _segmentEnd != null ? [_segmentStart!, _segmentEnd!] : null,
          );
        } catch (_) {
          try {
            await InjectionContainer.videosRepository.updateVideoProgress(
              videoId: _currentVideo!.id,
              studentId: _activeStudentId,
              progressSeconds: pos,
              durationSeconds: dur,
              furthestPositionSeconds: _furthestPositionSecs,
              newSegment: _segmentStart != null && _segmentEnd != null ? [_segmentStart!, _segmentEnd!] : null,
            );
          } catch (_) {}
        }
      }
    }

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

  Future<void> _openLesson(LessonAssignmentEntity lesson, int lessonIndex, int totalLessons) async {
    if (lesson.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(context.l10n.completeLessonToUnlock(lessonIndex > 1 ? lessonIndex - 1 : 1)),
        ),
      );
      return;
    }

    await _flushProgressAndExit(
      thenNavigateToLesson: lesson,
      lessonIndex: lessonIndex,
      totalLessons: totalLessons,
    );
  }

  Widget _buildSequentialNavigationBar(ThemeData theme) {
    if (_courseLessons.isEmpty && widget.lessonIndex == null) return const SizedBox.shrink();

    final currentIndex = _courseLessons.isNotEmpty
        ? _courseLessons.indexWhere((l) => l.contentId == widget.videoId)
        : (widget.lessonIndex != null ? widget.lessonIndex! - 1 : -1);

    final totalCount = _courseLessons.isNotEmpty ? _courseLessons.length : (widget.totalLessons ?? 1);
    final displayIndex = (currentIndex >= 0 ? currentIndex + 1 : (widget.lessonIndex ?? 1));

    final prevLesson = currentIndex > 0 ? _courseLessons[currentIndex - 1] : null;
    final nextLesson = (currentIndex >= 0 && currentIndex < _courseLessons.length - 1)
        ? _courseLessons[currentIndex + 1]
        : null;

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.s12, bottom: AppSpacing.s8),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12, vertical: AppSpacing.s8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withAlpha(50),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border.withAlpha(60)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous Lesson Button
          if (prevLesson != null)
            TextButton.icon(
              onPressed: () => _openLesson(prevLesson, displayIndex - 1, totalCount),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(context.l10n.previousLessonAction),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            )
          else
            const SizedBox(width: 80),

          // Middle: "Lesson X of Y" + View syllabus button
          InkWell(
            onTap: _courseLessons.isNotEmpty ? _showCourseLessonsDrawer : null,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.lessonXofY(displayIndex, totalCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  if (_courseLessons.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.format_list_bulleted_rounded, size: 14, color: AppColors.primary),
                  ],
                ],
              ),
            ),
          ),

          // Next Lesson Button
          if (nextLesson != null)
            TextButton.icon(
              onPressed: () => _openLesson(nextLesson, displayIndex + 1, totalCount),
              icon: Icon(
                nextLesson.isLocked ? Icons.lock_outline_rounded : Icons.arrow_forward_rounded,
                size: 16,
                color: nextLesson.isLocked ? AppColors.textMuted : AppColors.primary,
              ),
              label: Text(
                context.l10n.nextLessonAction,
                style: TextStyle(
                  color: nextLesson.isLocked ? AppColors.textMuted : AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            )
          else
            const SizedBox(width: 80),
        ],
      ),
    );
  }

  void _showCourseLessonsDrawer() {
    if (_courseLessons.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        final theme = Theme.of(modalContext);
        final completedCount = _courseLessons.where((l) => l.isEffectivelyCompleted).length;
        final totalCount = _courseLessons.length;
        final pct = totalCount > 0 ? ((completedCount / totalCount) * 100).toInt() : 0;

        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
          ),
          padding: const EdgeInsets.all(AppSpacing.s20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalContext).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.groupName ?? context.l10n.courseLessonsTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.lessonsCompletedRatio(completedCount, totalCount),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalCount > 0 ? completedCount / totalCount : 0,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),
              const Divider(height: 1, color: AppColors.border),
              const SizedBox(height: AppSpacing.s8),

              // Lessons List
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _courseLessons.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (ctx, i) {
                    final item = _courseLessons[i];
                    final isCurrent = item.contentId == widget.videoId;
                    final isCompleted = item.isEffectivelyCompleted;
                    final isLocked = item.isLocked;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: isCompleted
                            ? AppColors.success.withAlpha(25)
                            : isCurrent
                                ? AppColors.primary.withAlpha(25)
                                : isLocked
                                    ? AppColors.surfaceVariant
                                    : AppColors.primary.withAlpha(15),
                        child: Icon(
                          isCompleted
                              ? Icons.check_rounded
                              : isCurrent
                                  ? Icons.play_arrow_rounded
                                  : isLocked
                                      ? Icons.lock_rounded
                                      : Icons.radio_button_unchecked_rounded,
                          size: 14,
                          color: isCompleted
                              ? AppColors.success
                              : isCurrent
                                  ? AppColors.primary
                                  : isLocked
                                      ? AppColors.textMuted
                                      : AppColors.primary,
                        ),
                      ),
                      title: Text(
                        '${i + 1}. ${item.title}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCurrent
                              ? AppColors.primary
                              : isLocked
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                        ),
                      ),
                      trailing: isCurrent
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(20),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              ),
                              child: Text(
                                context.l10n.statusInProgress,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : isCompleted
                              ? const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success)
                              : isLocked
                                  ? const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textMuted)
                                  : null,
                      onTap: () {
                        Navigator.of(modalContext).pop();
                        if (!isCurrent) {
                          _openLesson(item, i + 1, totalCount);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
      if (pos > 0 && dur > 0) {
        unawaited(
          InjectionContainer.videosRepository.updateVideoProgress(
            videoId: _currentVideo!.id,
            studentId: _activeStudentId,
            progressSeconds: pos,
            durationSeconds: dur,
            furthestPositionSeconds: _furthestPositionSecs,
            newSegment: _segmentStart != null && _segmentEnd != null ? [_segmentStart!, _segmentEnd!] : null,
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
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _flushProgressAndExit();
      },
      child: Scaffold(
        backgroundColor: _isFullscreen
            ? Colors.black
            : theme.scaffoldBackgroundColor,
        appBar: _isFullscreen
            ? null
            : AppBar(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.groupName ?? _currentVideo?.title ?? context.l10n.watchLessonTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (widget.lessonIndex != null && widget.totalLessons != null)
                      Text(
                        '${context.l10n.lessonXofY(widget.lessonIndex!, widget.totalLessons!)} · ${_currentVideo?.title ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.normal,
                        ),
                      )
                    else if (_currentVideo?.title != null && widget.groupName != null)
                      Text(
                        _currentVideo!.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                  ],
                ),
                actions: [
                  Container(
                    margin: const EdgeInsetsDirectional.only(
                      end: AppSpacing.s16,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s10,
                      vertical: AppSpacing.s4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      border: Border.all(
                        color: AppColors.primary.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _currentVideo?.isYouTube == true
                              ? Icons.play_circle_fill_rounded
                              : Icons.lock_outline_rounded,
                          size: 13,
                          color: _currentVideo?.isYouTube == true
                              ? const Color(0xFFFF0000)
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _currentVideo?.isYouTube == true
                              ? 'Protected Streaming'
                              : context.l10n.secureCdnBadge,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _currentVideo?.isYouTube == true
                                ? const Color(0xFFFF0000)
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                leading: BackButton(onPressed: _flushProgressAndExit),
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
              return AppLoadingView(
                message: state.message ?? context.l10n.loadingVideo,
              );
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
                  if (!_isPlayingNotifier.value && current > 0) {
                    _isPlayingNotifier.value = true;
                  }
                },
                onSeekReady: (seekFn) {
                  _seekTo = seekFn;
                },
                onPlaybackControlsReady: (play, pause, toggle) {
                  _togglePlayPauseFn = () {
                    toggle();
                    _isPlayingNotifier.value = !_isPlayingNotifier.value;
                  };
                },
                onFullscreenChanged: _handleFullscreenChanged,
                onMetricsProgress:
                    (currentSeconds, totalSeconds, actualWatch, isSkipped) {
                      if (!_isTeacher &&
                          _activeStudentId.isNotEmpty &&
                          video != null) {
                        // تتبع furthest position محلياً
                        if (currentSeconds > _furthestPositionSecs) {
                          _furthestPositionSecs = currentSeconds;
                        }
                        if (!_hasRecordedStarted && currentSeconds > 0) {
                          _hasRecordedStarted = true;
                          StudentActivityTracker.instance.recordActivity(
                            eventType: 'video_started',
                            contentId: video.contentId,
                          );
                        }
                        final dur = totalSeconds > 0
                            ? totalSeconds
                            : video.duration;
                        if (_segmentStart == null) {
                          _segmentStart = currentSeconds;
                          _segmentEnd = currentSeconds;
                        }

                        bool isSeek = false;
                        if (_segmentEnd != null && (currentSeconds - _segmentEnd!).abs() > 2) {
                          isSeek = true;
                          // Force commit the old segment before starting a new one
                          context.read<VideosCubit>().updateProgress(
                            videoId: video.id,
                            studentId: _activeStudentId,
                            progressSeconds: currentSeconds,
                            durationSeconds: dur,
                            furthestPositionSeconds: _furthestPositionSecs,
                            actualWatchSeconds: actualWatch,
                            isSkipped: isSkipped,
                            force: true,
                            newSegment: [_segmentStart!, _segmentEnd!],
                          );
                          _segmentStart = currentSeconds;
                          _segmentEnd = currentSeconds;
                        } else {
                          _segmentEnd = currentSeconds;
                        }

                        if (!isSeek) {
                          context.read<VideosCubit>().updateProgress(
                            videoId: video.id,
                            studentId: _activeStudentId,
                            progressSeconds: currentSeconds,
                            durationSeconds: dur,
                            furthestPositionSeconds: _furthestPositionSecs,
                            actualWatchSeconds: actualWatch,
                            isSkipped: isSkipped,
                            newSegment: [_segmentStart!, _segmentEnd!],
                          );
                        }
                      }
                    },
                onCompleted: () {
                  if (!_isTeacher &&
                      _activeStudentId.isNotEmpty &&
                      video != null) {
                    final dur = _liveDurationSecs.value > 0
                        ? _liveDurationSecs.value
                        : video.duration;
                    // تحديث التقدم بقيمة الإكمال الكاملة
                    context.read<VideosCubit>().updateProgress(
                      videoId: video.id,
                      studentId: _activeStudentId,
                      progressSeconds: dur,
                      durationSeconds: dur,
                      furthestPositionSeconds: _furthestPositionSecs > 0
                          ? _furthestPositionSecs
                          : dur,
                      force: true,
                      newSegment: _segmentStart != null && _segmentEnd != null ? [_segmentStart!, _segmentEnd!] : null,
                    );
                    StudentActivityTracker.instance.recordActivity(
                      eventType: 'video_completed',
                      contentId: video.contentId,
                    );
                    // عرض قسم الاختبار مباشرة في الصفحة
                    final examId = _groupExamId ?? widget.associatedExamId;
                    if (examId != null && mounted) {
                      setState(() => _videoCompletedLocally = true);
                    }
                  }
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    videoPlayerWidget,
                                    _buildSequentialNavigationBar(theme),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s20),
                              // Right Sidebar: Academic Stats & Notes
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildAcademicStatsCard(
                                      theme,
                                      video,
                                      progress,
                                      isCompleted,
                                    ),
                                    const SizedBox(height: AppSpacing.s16),
                                    if ((_groupExamId ?? widget.associatedExamId) != null) ...[
                                      _buildAssociatedExamCard(
                                        theme,
                                        isCompleted,
                                      ),
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
                            _buildSequentialNavigationBar(theme),
                            const SizedBox(height: AppSpacing.s12),
                            _buildAcademicStatsCard(
                              theme,
                              video,
                              progress,
                              isCompleted,
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            if ((_groupExamId ?? widget.associatedExamId) != null) ...[
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
    final isTeacher =
        authState is AuthAuthenticated && authState.user.isTeacher;

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
                  color: (isTeacher ? AppColors.primary : AppColors.warning)
                      .withAlpha(20),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (isTeacher ? AppColors.primary : AppColors.warning)
                        .withAlpha(60),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  isTeacher
                      ? Icons.cloud_upload_outlined
                      : Icons.hourglass_top_rounded,
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
                  color: (isTeacher ? AppColors.primary : AppColors.warning)
                      .withAlpha(15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: (isTeacher ? AppColors.primary : AppColors.warning)
                        .withAlpha(60),
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
              if (video?.description != null &&
                  video!.description!.isNotEmpty) ...[
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
    final isTeacher =
        authState is AuthAuthenticated && authState.user.isTeacher;

    final isNotFoundOrCoerce =
        state.code == 'VIDEO_NOT_FOUND' ||
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
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
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
                                context.l10n.remainingTime(
                                  _formatTime(remainingSecs),
                                ),
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
                            if (liveDur > 0 &&
                                _seekTo != null &&
                                barWidth > 0) {
                              final ratio =
                                  (details.localPosition.dx / barWidth).clamp(
                                    0.0,
                                    1.0,
                                  );
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
                                            color: AppColors.primary.withAlpha(
                                              90,
                                            ),
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

                    const SizedBox(height: AppSpacing.s12),

                    // Quick Academic Playback Control Bar
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // -10s
                          IconButton.filledTonal(
                            tooltip: context.l10n.seek10Seconds,
                            icon: const Icon(Icons.replay_10_rounded, size: 20),
                            onPressed: () {
                              final target = (livePos - 10).clamp(0, liveDur);
                              _seekTo?.call(target);
                            },
                          ),
                          const SizedBox(width: AppSpacing.s10),
                          // Play / Pause Toggle
                          ValueListenableBuilder<bool>(
                            valueListenable: _isPlayingNotifier,
                            builder: (context, isPlaying, _) {
                              return FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                ),
                                onPressed: () {
                                  if (_togglePlayPauseFn != null) {
                                    _togglePlayPauseFn!();
                                  } else if (_seekTo != null) {
                                    _seekTo!(livePos);
                                  }
                                },
                                icon: Icon(
                                  isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  context.l10n.playPauseAction,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: AppSpacing.s10),
                          // +10s
                          IconButton.filledTonal(
                            tooltip: context.l10n.seek10Seconds,
                            icon: const Icon(
                              Icons.forward_10_rounded,
                              size: 20,
                            ),
                            onPressed: () {
                              final target = (livePos + 10).clamp(0, liveDur);
                              _seekTo?.call(target);
                            },
                          ),
                        ],
                      ),
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
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
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
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
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
        final isVideoCompleted = _isTeacher || isInitiallyCompleted || _videoCompletedLocally || pct >= 90.0;
        final exam = _lessonExam;
        final actualExamTitle = exam?.title ?? _groupExamTitle ?? widget.associatedExamTitle ?? context.l10n.associatedExamBadge;
        final examId = exam?.id ?? _groupExamId ?? widget.associatedExamId;

        // Determine quiz attempt state
        final latestAttempt = exam?.myLatestAttempt;
        final passingScore = exam?.passingScore ?? 60;
        final isSubmitted = latestAttempt != null && latestAttempt.isSubmitted;
        final isPassed = isSubmitted && latestAttempt.isPassed(passingScore);
        final isFailed = isSubmitted && !isPassed;
        final scorePct = latestAttempt?.percentage?.toInt() ?? 
            (latestAttempt?.score != null && (exam?.maxScore ?? 100) > 0 
                ? ((latestAttempt!.score! / (exam?.maxScore ?? 100)) * 100).toInt() 
                : null);

        // Find next lesson if available
        LessonAssignmentEntity? nextLesson;
        int? nextLessonIndex;
        if (_courseLessons.isNotEmpty) {
          final cIdx = _courseLessons.indexWhere((l) => l.contentId == widget.videoId);
          if (cIdx >= 0 && cIdx < _courseLessons.length - 1) {
            nextLesson = _courseLessons[cIdx + 1];
            nextLessonIndex = cIdx + 2;
          }
        }

        Color themeColor;
        if (isPassed) {
          themeColor = AppColors.success;
        } else if (isFailed) {
          themeColor = AppColors.error;
        } else if (isVideoCompleted) {
          themeColor = AppColors.primary;
        } else {
          themeColor = AppColors.warning;
        }

        return AppCard(
          variant: AppCardVariant.elevated,
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Tag & Status Pill
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
                      context.l10n.lessonMaterialTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      border: Border.all(color: themeColor.withAlpha(60)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isPassed
                              ? Icons.check_circle_rounded
                              : isFailed
                                  ? Icons.cancel_rounded
                                  : isVideoCompleted
                                      ? Icons.quiz_rounded
                                      : Icons.lock_outline_rounded,
                          size: 11,
                          color: themeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isPassed
                              ? 'COMPLETED'
                              : isFailed
                                  ? 'FAILED'
                                  : isVideoCompleted
                                      ? 'QUIZ'
                                      : 'LOCKED',
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
              const SizedBox(height: 8),

              // Title and Description based on state
              if (isPassed) ...[
                Text(
                  '🎉 ${context.l10n.lessonCompletedCongrats}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scorePct != null
                      ? '${context.l10n.passedQuizNotice} (${context.l10n.examScoreLabel}: $scorePct% · ${context.l10n.passingScoreTitle}: $passingScore%)'
                      : context.l10n.passedQuizNotice,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (isFailed) ...[
                Text(
                  context.l10n.quizNotPassedTitle,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  scorePct != null
                      ? '${context.l10n.quizNotPassedDesc} (${context.l10n.examScoreLabel}: $scorePct% · ${context.l10n.passingScoreTitle}: $passingScore%)'
                      : context.l10n.quizNotPassedDesc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else if (isVideoCompleted) ...[
                Text(
                  '✓ ${context.l10n.videoCompletedTitle}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.lessonQuizReadyDesc,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ] else ...[
                Text(
                  context.l10n.completeVideoToUnlockQuiz,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s12),

              // Quiz detail box
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
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: Icon(
                        isPassed
                            ? Icons.verified_rounded
                            : isVideoCompleted
                                ? Icons.quiz_rounded
                                : Icons.lock_rounded,
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
                            actualExamTitle,
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
                            '${exam?.activeVersion?.questions.length ?? 10} Questions · Passing Score: $passingScore%',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s12),

              // Action Buttons
              if (isPassed) ...[
                if (nextLesson != null) ...[
                  Text(
                    context.l10n.nextLessonLabel(nextLesson.title),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(context.l10n.continueToNextLessonAction),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s12,
                        horizontal: AppSpacing.s16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                      ),
                    ),
                    onPressed: () => _openLesson(
                      nextLesson!,
                      nextLessonIndex ?? 2,
                      _courseLessons.length,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  icon: const Icon(Icons.replay_rounded, size: 16),
                  label: Text(context.l10n.reviewLessonAction),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s10,
                      horizontal: AppSpacing.s16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                    ),
                  ),
                  onPressed: () => _seekTo?.call(0),
                ),
              ] else if (isFailed) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                        label: Text(
                          context.l10n.reviewLessonAction,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onPressed: () => _seekTo?.call(0),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(
                          context.l10n.retryLessonQuizAction,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: examId != null
                            ? () => _startLessonQuiz(examId)
                            : null,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                ElevatedButton.icon(
                  icon: Icon(
                    isVideoCompleted
                        ? Icons.arrow_forward_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isVideoCompleted
                        ? context.l10n.takeLessonQuizAction
                        : context.l10n.completeVideoToUnlockQuiz,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isVideoCompleted
                        ? AppColors.primary
                        : AppColors.surfaceVariant,
                    foregroundColor: isVideoCompleted
                        ? Colors.white
                        : AppColors.textMuted,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.s12,
                      horizontal: AppSpacing.s16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                    ),
                  ),
                  onPressed: (isVideoCompleted && examId != null)
                      ? () => _startLessonQuiz(examId)
                      : null,
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachedMaterialCard(ThemeData theme, VideoEntity? video) {
    // 1. الأولوية للـ PDF الخاص بالمجموعة (إذا دخلنا من group course)
    final hasGroupPdf = _groupPdfStoragePath != null && _groupPdfFileName != null;
    
    // 2. الـ PDF الافتراضي المربوط بالفيديو نفسه
    final attachedFile = video?.attachedFile;
    
    if (!hasGroupPdf && attachedFile == null && !_isTeacher) {
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

          if (hasGroupPdf || attachedFile != null) ...[
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
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
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
                          hasGroupPdf ? _groupPdfFileName! : (attachedFile?.fileName ?? 'Study Material'),
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
                          hasGroupPdf 
                              ? 'PDF'
                              : '${attachedFile?.formattedFileSize ?? ''} • PDF',
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
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: Flexible(
                child: Text(
                  context.l10n.openPdfAction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
              onPressed: () {
                if (hasGroupPdf) {
                  // فتح PDF المجموعة
                  final contentWrapper = ContentEntity(
                    id: video!.contentId,
                    tenantId: '',
                    groupId: widget.groupId ?? '',
                    title: video.title ?? _groupPdfFileName!,
                    description: video.description,
                    type: ContentType.pdf,
                    status: ContentStatus.published,
                    createdAt: video.createdAt,
                    updatedAt: video.updatedAt,
                  );
                  final cubit = context.read<VideosCubit>();
                  MaterialViewerSheet.show(
                    context,
                    content: contentWrapper,
                    onGetSignedUrl: (_) => cubit.getSignedFileUrl(_groupPdfStoragePath!),
                  );
                } else {
                  _handleOpenAttachedMaterial(video!);
                }
              },
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
                label: Flexible(
                  child: Text(
                    context.l10n.attachPdfToLessonAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed: _isAttachingPdf
                    ? null
                    : () => _pickAndAttachPdf(video!),
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
                      onPressed: _isAttachingPdf
                          ? null
                          : () => _pickAndAttachPdf(video!),
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
              const Icon(
                Icons.verified_user_rounded,
                size: 14,
                color: AppColors.primary,
              ),
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
