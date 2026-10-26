import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/video_entity.dart';
import '../../domain/entities/video_progress_entity.dart';

class VideoAcademicStatsCard extends StatelessWidget {
  final VideoEntity? video;
  final VideoProgressEntity? progress;
  final bool isCompleted;
  final ValueNotifier<int> livePositionSecs;
  final ValueNotifier<int> liveDurationSecs;
  final ValueNotifier<bool> isPlayingNotifier;
  final bool isTeacher;
  final bool videoCompletedLocally;
  final void Function(int seconds)? onSeekTo;

  const VideoAcademicStatsCard({
    super.key,
    required this.video,
    required this.progress,
    required this.isCompleted,
    required this.livePositionSecs,
    required this.liveDurationSecs,
    required this.isPlayingNotifier,
    required this.isTeacher,
    required this.videoCompletedLocally,
    this.onSeekTo,
  });

  String _formatTime(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final minutes =
        (totalSeconds ~/ 60).remainder(60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    final hours = totalSeconds ~/ 3600;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localVideo = video;
    return AnimatedBuilder(
      animation: Listenable.merge([livePositionSecs, liveDurationSecs]),
      builder: (context, _) {
        final liveDur = liveDurationSecs.value > 0
            ? liveDurationSecs.value
            : ((localVideo?.duration != null && localVideo!.duration > 0)
                  ? localVideo.duration
                  : (progress?.durationSeconds ?? 0));
        final livePos = livePositionSecs.value;
        final effectivePos =
            (livePositionSecs.value == 0 &&
                (progress?.progressSeconds ?? 0) > 0 &&
                !isPlayingNotifier.value)
            ? progress!.progressSeconds
            : livePos;
        final pct = liveDur > 0
            ? ((effectivePos / liveDur) * 100).clamp(0.0, 100.0)
            : (progress?.percentage ?? 0.0);
        final completed = isCompleted || pct >= 90.0 || videoCompletedLocally;
        final remainingSecs = liveDur > 0
            ? (liveDur - effectivePos).clamp(0, liveDur)
            : 0;

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
                      color: isTeacher
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
                        color: isTeacher
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
                          isTeacher
                              ? Icons.sensors_rounded
                              : completed
                              ? Icons.check_circle_rounded
                              : pct > 0
                              ? Icons.timelapse_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 11,
                          color: isTeacher
                              ? AppColors.primary
                              : completed
                              ? AppColors.success
                              : pct > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isTeacher
                              ? context.l10n.teacherPreviewMode
                              : completed
                              ? context.l10n.statusCompleted
                              : pct > 0
                              ? context.l10n.statusInProgress
                              : context.l10n.statusNotStarted,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isTeacher
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
                                '${_formatTime(effectivePos)} / ${_formatTime(liveDur)}',
                                textDirection: TextDirection.ltr,
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
                              onTap: () {
                                onSeekTo?.call(0);
                                livePositionSecs.value = 0;
                              },
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
                                onSeekTo != null &&
                                barWidth > 0) {
                              final ratio =
                                  (details.localPosition.dx / barWidth).clamp(
                                    0.0,
                                    1.0,
                                  );
                              final targetSecs = (ratio * liveDur).round();
                              onSeekTo?.call(targetSecs);
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


}
