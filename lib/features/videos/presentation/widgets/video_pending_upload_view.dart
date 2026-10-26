import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/entities/video_entity.dart';
import 'video_upload_dialog.dart';

/// Screen displayed when a video is pending upload or awaiting processing.
class VideoPendingUploadView extends StatelessWidget {
  const VideoPendingUploadView({
    super.key,
    required this.video,
    required this.videoId,
    required this.onUploadSuccess,
    required this.onRetry,
  });

  final VideoEntity? video;
  final String videoId;
  final VoidCallback onUploadSuccess;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = context.read<AuthCubit>().state;
    final isTeacher =
        authState is AuthAuthenticated && authState.user.isTeacher;

    final currentVideo = video;

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
                currentVideo?.title ?? context.l10n.defaultLessonTitle,
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
              if (currentVideo?.description != null &&
                  currentVideo!.description!.isNotEmpty) ...[
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
                    currentVideo.description!,
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
                      contentId: currentVideo?.contentId ?? videoId,
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
