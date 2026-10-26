import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../cubit/videos_state.dart';
import 'video_upload_dialog.dart';

/// Screen displayed when video playback fails or encounters an error state.
class VideoPlaybackErrorView extends StatelessWidget {
  const VideoPlaybackErrorView({
    super.key,
    required this.state,
    required this.videoId,
    required this.onUploadSuccess,
    required this.onRetry,
  });

  final VideosError state;
  final String videoId;
  final VoidCallback onUploadSuccess;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthCubit>().state;
    final isTeacher =
        authState is AuthAuthenticated && authState.user.isTeacher;

    final isNotFoundOrCoerce =
        state.code == 'VIDEO_NOT_FOUND' ||
        state.message.contains('Cannot coerce') ||
        state.message.contains('not found');

    final isProcessing = state.code == 'VIDEO_NOT_READY' ||
        state.code == 'VIDEO_PROCESSING' ||
        state.message.toLowerCase().contains('processing') ||
        state.message.toLowerCase().contains('transcoding');

    final String title;
    final String message;
    final String? hint;
    final IconData icon;
    final Color iconColor;

    if (isProcessing) {
      title = context.l10n.errorVideoProcessingTitle;
      message = context.l10n.errorVideoProcessingMessage;
      hint = context.l10n.errorVideoProcessingHint;
      icon = Icons.hourglass_top_rounded;
      iconColor = AppColors.warning;
    } else if (isNotFoundOrCoerce) {
      title = isTeacher
          ? context.l10n.teacherVideoNotUploadedBadge
          : context.l10n.defaultLessonTitle;
      message = isTeacher
          ? context.l10n.teacherVideoNotUploadedDesc
          : context.l10n.videoNotFoundMessage;
      hint = null;
      icon = Icons.video_camera_back_outlined;
      iconColor = AppColors.textMuted;
    } else {
      final resolved = ErrorMapper.resolve(state.message);
      title = resolved.title(context);
      message = resolved.message(context);
      hint = resolved.hint(context);
      icon = Icons.info_outline_rounded;
      iconColor = AppColors.error;
    }

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
              Icon(
                icon,
                size: 56,
                color: iconColor,
              ),
              const SizedBox(height: AppSpacing.s16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (hint != null && hint.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant.withAlpha(50),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(color: AppColors.border.withAlpha(50)),
                  ),
                  child: Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.s20),
              if (isTeacher && !isProcessing) ...[
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
                      contentId: videoId,
                      onUploadSuccess: onUploadSuccess,
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
                    onPressed: onRetry,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
