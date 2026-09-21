import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';

/// Compact, high-aesthetic Student Lesson Tile & Roadmap Station.
///
/// Follows the LMS course mental model:
/// Sequence number, clear lesson title, authoritative states:
/// (Completed, In Progress, Quiz Ready, Quiz Failed, Available, Locked),
/// and direct access to PDF study material and lesson quiz.
class StudentLessonTile extends StatefulWidget {
  final LessonAssignmentEntity? lesson;
  final ContentEntity content;
  final int index;
  final bool isLast;
  final bool isRoadmapMode;
  final VoidCallback onTap;
  final VoidCallback? onOpenHandout;
  final VoidCallback? onTakeQuiz;

  const StudentLessonTile({
    super.key,
    this.lesson,
    required this.content,
    required this.index,
    this.isLast = false,
    this.isRoadmapMode = true,
    required this.onTap,
    this.onOpenHandout,
    this.onTakeQuiz,
  });

  @override
  State<StudentLessonTile> createState() => _StudentLessonTileState();
}

class _StudentLessonTileState extends State<StudentLessonTile> {
  bool _isHovered = false;

  ContentEntity get content => widget.content;
  LessonAssignmentEntity? get lesson => widget.lesson;

  bool get isLocked => lesson?.isLocked ?? content.isLocked;

  bool get isCompleted =>
      (lesson != null)
          ? lesson!.progress == LessonProgress.completed
          : content.isCompleted;

  bool get isQuizFailed =>
      lesson?.progress == LessonProgress.quizFailed;

  bool get isQuizReady =>
      lesson?.progress == LessonProgress.quizAvailable ||
      lesson?.progress == LessonProgress.videoCompleted;

  bool get isInProgress =>
      (lesson != null)
          ? lesson!.progress == LessonProgress.inProgress
          : (content.videoProgressPercentage > 0 && !isCompleted);

  bool get isAvailable =>
      (lesson != null)
          ? (lesson!.access == LessonAccess.unlocked &&
              !isCompleted &&
              !isQuizReady &&
              !isQuizFailed &&
              !isInProgress)
          : (!isLocked && !isCompleted && !isInProgress);

  Color get _statusAccentColor {
    if (isCompleted) return AppColors.success;
    if (isQuizReady) return AppColors.primary;
    if (isQuizFailed) return AppColors.warning;
    if (isInProgress) return AppColors.primary;
    if (isLocked) return AppColors.textMuted;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final tileContent = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isLocked ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        margin: EdgeInsets.only(
          bottom: widget.isRoadmapMode ? AppSpacing.s12 : AppSpacing.s8,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s10,
        ),
        decoration: BoxDecoration(
          color: isLocked
              ? AppColors.surfaceVariant.withAlpha(40)
              : _isHovered
                  ? AppColors.surfaceVariant.withAlpha(80)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: isLocked
                ? AppColors.error.withAlpha(40)
                : _isHovered
                    ? AppColors.primary.withAlpha(120)
                    : isCompleted
                        ? AppColors.success.withAlpha(50)
                        : AppColors.border,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: _isHovered && !isLocked
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(20),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Station Avatar (Sequence Number / Checkmark / Lock)
              _buildStationAvatar(context),

              const SizedBox(width: AppSpacing.s12),

              // 2. Main Title and Interactive Chips
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title alone receives full width to prevent truncation
                    Text(
                      content.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isLocked
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s6),

                    // Meta Row: Type Pill, Status, PDF Chip, Quiz Chip (Zero Noise)
                    Wrap(
                      spacing: AppSpacing.s6,
                      runSpacing: AppSpacing.s4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildContentTypePill(context),

                        // Progress / Status Badge
                        _buildStatusBadge(context),

                        // Handout Chip (Instant PDF access)
                        if (content.file != null && widget.onOpenHandout != null)
                          InkWell(
                            onTap: widget.onOpenHandout,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEA580C).withAlpha(18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFEA580C).withAlpha(60),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    size: 11,
                                    color: Color(0xFFEA580C),
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      context.l10n.lessonHandoutChip,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFEA580C),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Quiz Chip (Instant quiz access)
                        if (content.associatedExamTitle != null)
                          InkWell(
                            onTap: widget.onTakeQuiz,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: (content.isExamPassed
                                        ? AppColors.success
                                        : AppColors.primary)
                                    .withAlpha(18),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: (content.isExamPassed
                                          ? AppColors.success
                                          : AppColors.primary)
                                      .withAlpha(60),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    content.isExamPassed
                                        ? Icons.check_circle_rounded
                                        : Icons.quiz_rounded,
                                    size: 11,
                                    color: content.isExamPassed
                                        ? AppColors.success
                                        : AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      content.isExamPassed
                                          ? '${context.l10n.lessonQuizChip} (${context.l10n.statusCompleted})'
                                          : context.l10n.lessonQuizChip,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: content.isExamPassed
                                            ? AppColors.success
                                            : AppColors.primary,
                                      ),
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
              ),

              const SizedBox(width: AppSpacing.s8),

              // 3. Fast Action Icon Button
              _buildActionButton(context),
            ],
          ),
        ),
      ),
    );

    if (!widget.isRoadmapMode) {
      return tileContent;
    }

    // Roadmap Mode: Adds continuous vertical line connector between stations
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline connector rail
          SizedBox(
            width: 28,
            child: Column(
              children: [
                // Upper gap
                Container(
                  width: 2,
                  height: 12,
                  color: widget.index == 1
                      ? Colors.transparent
                      : (isCompleted
                          ? AppColors.success.withAlpha(150)
                          : AppColors.border),
                ),
                // Node indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppColors.success
                        : isLocked
                            ? AppColors.error
                            : AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: _statusAccentColor.withAlpha(120),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                // Lower connecting line
                Expanded(
                  child: Container(
                    width: 2,
                    color: widget.isLast
                        ? Colors.transparent
                        : (isCompleted
                            ? AppColors.success.withAlpha(150)
                            : AppColors.border),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(child: tileContent),
        ],
      ),
    );
  }

  Widget _buildStationAvatar(BuildContext context) {
    if (isCompleted) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.success.withAlpha(25),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.success.withAlpha(90), width: 1.5),
        ),
        child: const Icon(
          Icons.check_rounded,
          color: AppColors.success,
          size: 20,
        ),
      );
    }

    if (isLocked) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(20),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.error.withAlpha(70), width: 1.5),
        ),
        child: const Icon(
          Icons.lock_rounded,
          color: AppColors.error,
          size: 18,
        ),
      );
    }

    // Active / Uncompleted lecture station
    final hasProgress = content.videoProgressPercentage > 0;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(hasProgress ? 25 : 12),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withAlpha(hasProgress ? 120 : 60),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          widget.index.toString().padLeft(2, '0'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildContentTypePill(BuildContext context) {
    final (label, icon, color) = switch (content.type) {
      ContentType.video => (
          context.l10n.contentTypeVideo,
          Icons.play_circle_outline_rounded,
          AppColors.primary,
        ),
      ContentType.assignment => (
          context.l10n.contentTypeAssignment,
          Icons.assignment_outlined,
          AppColors.warning,
        ),
      ContentType.exam => (
          context.l10n.contentTypeExam,
          Icons.quiz_outlined,
          AppColors.success,
        ),
      ContentType.pdf => (
          context.l10n.contentTypePdf,
          Icons.picture_as_pdf_outlined,
          const Color(0xFFEA580C),
        ),
      ContentType.image => (
          context.l10n.contentTypeImage,
          Icons.image_outlined,
          Colors.purple,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    if (isLocked) {
      final prevIndex = widget.index > 1 ? widget.index - 1 : 1;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 11, color: AppColors.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              context.l10n.completeLessonToUnlock(prevIndex),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      );
    }

    if (isCompleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 11, color: AppColors.success),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              context.l10n.statusCompleted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      );
    }

    if (isQuizFailed) {
      final best = lesson?.examBestScore?.toInt();
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 11, color: AppColors.warning),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              best != null
                  ? '${context.l10n.quizNotPassedTitle} ($best%)'
                  : context.l10n.quizNotPassedTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      );
    }

    if (isQuizReady) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 12, color: AppColors.primary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              context.l10n.lessonQuizReadyTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      );
    }

    final pct = (lesson?.watchedCoveragePercent ?? content.videoProgressPercentage).toInt();
    if (pct > 0) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timelapse_rounded, size: 11, color: AppColors.primary),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '$pct%',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      );
    }

    // Newly unlocked or manually unlocked (shows "Available" - Section 8 & 33)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.play_circle_outline_rounded, size: 11, color: AppColors.primary),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            context.l10n.availableStatus,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context) {
    if (isLocked) {
      return Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock_rounded, size: 15, color: AppColors.textMuted),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isCompleted
            ? AppColors.surfaceVariant
            : AppColors.primary.withAlpha(20),
        shape: BoxShape.circle,
        border: Border.all(
          color: isCompleted
              ? AppColors.border
              : AppColors.primary.withAlpha(70),
        ),
      ),
      child: Icon(
        isCompleted
            ? Icons.replay_rounded
            : isQuizReady
                ? Icons.quiz_rounded
                : Icons.play_arrow_rounded,
        size: isCompleted ? 16 : 18,
        color: isCompleted ? AppColors.textSecondary : AppColors.primary,
      ),
    );
  }
}
