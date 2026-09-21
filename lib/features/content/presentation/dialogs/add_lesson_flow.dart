import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import 'add_video_to_bank_dialog.dart';
import 'lesson_setup_sheet.dart';
import '../widgets/video_picker_sheet.dart';

/// Two-step flow for adding a lesson to a course from the Course Builder.
///
/// Step 1 — Choose source:
///   a) Use Existing Video → VideoPickerSheet → LessonSetupSheet
///   b) Add New Video → AddVideoToBankDialog → LessonSetupSheet
///
/// Launched from Course Builder "+ Add Lesson" button.
class AddLessonFlow extends StatelessWidget {
  final String groupId;
  final String groupName;
  final int defaultPassingScore;

  const AddLessonFlow({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.defaultPassingScore,
  });

  static Future<bool> show(
    BuildContext context, {
    required String groupId,
    required String groupName,
    required int defaultPassingScore,
  }) async {
    final contentCubit = context.read<ContentCubit>();
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => BlocProvider.value(
        value: contentCubit,
        child: AddLessonFlow(
          groupId: groupId,
          groupName: groupName,
          defaultPassingScore: defaultPassingScore,
        ),
      ),
    );
    return result == true;
  }

  Future<bool> _saveLesson(
    BuildContext context, {
    required ContentEntity video,
    required String? lessonTitle,
    required String? fileId,
    required String? examId,
    required int? passingScoreOverride,
  }) {
    final cubit = context.read<ContentCubit>();
    return cubit.assignContentToGroups(
      contentId: video.id,
      groupIds: [groupId],
      groupConfigs: [
        {
          'group_id': groupId,
          if (fileId != null) 'file_id': fileId,
          if (examId != null) 'associated_exam_id': examId,
          if (passingScoreOverride != null)
            'passing_score_override': passingScoreOverride,
        }
      ],
    );
  }

  Future<void> _useExistingVideo(BuildContext context) async {
    Navigator.of(context).pop(); // close choice dialog

    // Step 2a: Pick video from library
    final video = await VideoPickerSheet.show(context);
    if (video == null || !context.mounted) return;

    // Step 3: Lesson setup
    final saved = await LessonSetupSheet.show(
      context,
      video: video,
      groupId: groupId,
      groupName: groupName,
      defaultPassingScore: defaultPassingScore,
      onSave: ({
        required contentId,
        required groupId,
        required lessonTitle,
        required fileId,
        required examId,
        required passingScoreOverride,
      }) =>
          _saveLesson(
        context,
        video: video,
        lessonTitle: lessonTitle,
        fileId: fileId,
        examId: examId,
        passingScoreOverride: passingScoreOverride,
      ),
    );

    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(context.l10n.lessonAddedToCourse(groupName)),
        ),
      );
    }
  }

  Future<void> _addNewVideo(BuildContext context) async {
    Navigator.of(context).pop(); // close choice dialog

    // Step 2b: Create new video in library
    ContentEntity? newVideo;

    await AddVideoToBankDialog.show(
      context,
      onCreated: (created) {
        newVideo = created;
      },
    );

    if (newVideo == null || !context.mounted) return;

    // Step 3: Lesson setup with the newly created video
    final saved = await LessonSetupSheet.show(
      context,
      video: newVideo!,
      groupId: groupId,
      groupName: groupName,
      defaultPassingScore: defaultPassingScore,
      onSave: ({
        required contentId,
        required groupId,
        required lessonTitle,
        required fileId,
        required examId,
        required passingScoreOverride,
      }) =>
          _saveLesson(
        context,
        video: newVideo!,
        lessonTitle: lessonTitle,
        fileId: fileId,
        examId: examId,
        passingScoreOverride: passingScoreOverride,
      ),
    );

    if (saved && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(context.l10n.lessonAddedToCourse(groupName)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
      elevation: 4,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
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
                          l10n.addLessonTitle,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          groupName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                l10n.addLessonSubtitle,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.s20),

              // Option A: Use Existing Video
              _OptionCard(
                icon: Icons.video_library_rounded,
                iconColor: AppColors.primary,
                title: l10n.useExistingVideo,
                subtitle: l10n.useExistingVideoSubtitle,
                onTap: () => _useExistingVideo(context),
              ),
              const SizedBox(height: AppSpacing.s12),

              // Option B: Add New Video
              _OptionCard(
                icon: Icons.add_circle_outline_rounded,
                iconColor: AppColors.success,
                title: l10n.addNewVideoToLesson,
                subtitle: l10n.addNewVideoToLessonSubtitle,
                onTap: () => _addNewVideo(context),
              ),
              const SizedBox(height: AppSpacing.s20),

              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel,
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.iconColor.withValues(alpha: 0.05)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: _isHovered
                  ? widget.iconColor.withValues(alpha: 0.4)
                  : AppColors.border,
              width: _isHovered ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Icon(widget.icon, color: widget.iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: _isHovered ? widget.iconColor : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
