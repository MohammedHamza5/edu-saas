import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
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

  const VideoPlayerPage({
    super.key,
    required this.videoId,
    this.studentId,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final String _activeStudentId;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthCubit>().state;
    final authUser = authState is AuthAuthenticated ? authState.user : null;
    _activeStudentId = widget.studentId ?? authUser?.id ?? '';
    _loadVideo();
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

    return Scaffold(
      appBar: AppBar(
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
                const Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  context.l10n.secureCdnBadge,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
        leading: BackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocBuilder<VideosCubit, VideosState>(
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

            return Center(
              child: ResponsiveContainer(
                maxWidth: ResponsiveBreakpoints.maxWideContentWidth,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktopTheater = constraints.maxWidth >= 960;

                    final videoPlayerWidget = AppVideoPlayer(
                      streamUrl: playbackUrl,
                      initialProgressSeconds: initialSeconds,
                      videoTitle: video?.title,
                      onMetricsProgress: (currentSeconds, totalSeconds, actualWatch, isSkipped) {
                        if (_activeStudentId.isNotEmpty) {
                          context.read<VideosCubit>().updateProgress(
                                videoId: widget.videoId,
                                studentId: _activeStudentId,
                                progressSeconds: currentSeconds,
                                durationSeconds: totalSeconds,
                                actualWatchSeconds: actualWatch,
                                isSkipped: isSkipped,
                              );
                        }
                      },
                      onCompleted: () {
                        if (_activeStudentId.isNotEmpty && video != null) {
                          context.read<VideosCubit>().updateProgress(
                                videoId: widget.videoId,
                                studentId: _activeStudentId,
                                progressSeconds: video.duration,
                                durationSeconds: video.duration,
                                force: true,
                              );
                          StudentActivityTracker.instance.recordActivity(
                            eventType: 'video_completed',
                            contentId: video.contentId,
                          );
                        }
                      },
                    );

                    if (isDesktopTheater) {
                      // ── Wide Desktop Academic Theater Layout ─────────────
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.s24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left Main Column: Player & Shortcuts
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  videoPlayerWidget,
                                  const SizedBox(height: AppSpacing.s12),
                                  _buildKeyboardShortcutsBar(theme),
                                ],
                              ),
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

  Widget _buildKeyboardShortcutsBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withAlpha(80),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        border: Border.all(color: AppColors.border.withAlpha(60)),
      ),
      child: Wrap(
        spacing: AppSpacing.s16,
        runSpacing: AppSpacing.s8,
        alignment: WrapAlignment.spaceBetween,
        children: [
          _buildShortcutPill(context.l10n.keySpace, context.l10n.playPauseAction),
          _buildShortcutPill('◀ / ▶', context.l10n.seek10Seconds),
          _buildShortcutPill('F', context.l10n.fullscreenAction),
        ],
      ),
    );
  }

  Widget _buildShortcutPill(String key, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            key,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicStatsCard(
    ThemeData theme,
    VideoEntity? video,
    VideoProgressEntity? progress,
    bool isCompleted,
  ) {
    final percentage = progress?.percentage ?? 0.0;
    final progressSeconds = progress?.progressSeconds ?? 0;
    final durationSeconds = video?.duration ?? progress?.durationSeconds ?? 0;

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              if (isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(color: AppColors.success.withAlpha(80)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.statusCompleted,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s10,
                    vertical: AppSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(color: AppColors.primary.withAlpha(60)),
                  ),
                  child: Text(
                    percentage > 0 ? context.l10n.statusInProgress : context.l10n.statusNotStarted,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),

          // Percentage & Duration Stats
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.completionPercentage(percentage.toInt()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                context.l10n.minutesRatio(progressSeconds ~/ 60, durationSeconds ~/ 60),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),

          // Linear Mathematical Progress
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? AppColors.success : AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.s12),

          // Milestone Checkpoints (25%, 50%, 75%, 100%)
          Text(
            context.l10n.academicMilestonesTitle,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          _buildMilestoneRow(
            percent: 25,
            title: context.l10n.milestoneConcepts,
            isAchieved: percentage >= 25,
          ),
          const SizedBox(height: 6),
          _buildMilestoneRow(
            percent: 50,
            title: context.l10n.milestoneExamples,
            isAchieved: percentage >= 50,
          ),
          const SizedBox(height: 6),
          _buildMilestoneRow(
            percent: 75,
            title: context.l10n.milestoneAdvanced,
            isAchieved: percentage >= 75,
          ),
          const SizedBox(height: 6),
          _buildMilestoneRow(
            percent: 100,
            title: context.l10n.milestoneCompletion,
            isAchieved: isCompleted,
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneRow({
    required int percent,
    required String title,
    required bool isAchieved,
  }) {
    return Row(
      children: [
        Icon(
          isAchieved ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 16,
          color: isAchieved ? AppColors.success : AppColors.textSecondary.withAlpha(100),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isAchieved ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isAchieved ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isAchieved ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ],
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
