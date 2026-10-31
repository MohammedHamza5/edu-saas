import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/videos_cubit.dart';
import '../cubit/videos_state.dart';
import 'video_upload_bunny_tab.dart';
import 'video_upload_youtube_tab.dart';

class VideoUploadDialog extends StatefulWidget {
  final String contentId;
  final VoidCallback? onUploadSuccess;

  const VideoUploadDialog({
    super.key,
    required this.contentId,
    this.onUploadSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String contentId,
    VoidCallback? onUploadSuccess,
  }) {
    VideosCubit? cubit;
    try {
      cubit = context.read<VideosCubit>();
    } catch (_) {
      cubit = InjectionContainer.createVideosCubit();
    }

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: cubit!,
        child: VideoUploadDialog(
          contentId: contentId,
          onUploadSuccess: onUploadSuccess,
        ),
      ),
    );
  }

  @override
  State<VideoUploadDialog> createState() => _VideoUploadDialogState();
}

class _VideoUploadDialogState extends State<VideoUploadDialog> {
  int _selectedTabIndex = 0; // 0 = YouTube, 1 = Bunny Stream

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = AppConfig.isBunnyEnabled && !AppConfig.isYouTubeEnabled
        ? 1
        : 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<VideosCubit, VideosState>(
      listener: (context, state) {
        if (state is VideoUploadSuccess) {
          Navigator.of(context).pop();
          widget.onUploadSuccess?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(context.l10n.videoUploadSuccessToast),
            ),
          );
        } else if (state is VideosError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(state.message),
            ),
          );
        }
      },
      builder: (context, state) {
        final isUploading = state is VideoUploading;

        return PopScope(
          canPop: !isUploading,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                            ),
                            child: const Icon(
                              Icons.video_call_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.uploadNewLessonVideo,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedTabIndex == 0
                                      ? context.l10n.youtubeTabTitle
                                      : context.l10n.fastEncryptedCdnHosting,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isUploading)
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                        ],
                      ),

                      // Provider Selection Tabs
                      if (AppConfig.showBothProviders) ...[
                        const SizedBox(height: AppSpacing.s16),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withAlpha(80),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: isUploading
                                      ? null
                                      : () => setState(
                                          () => _selectedTabIndex = 0,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSmall,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 0
                                          ? AppColors.surface
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusSmall,
                                      ),
                                      boxShadow: _selectedTabIndex == 0
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(
                                                  15,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.play_circle_fill_rounded,
                                          size: 18,
                                          color: _selectedTabIndex == 0
                                              ? const Color(0xFFFF0000)
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          context.l10n.youtubeTabTitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _selectedTabIndex == 0
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: _selectedTabIndex == 0
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: InkWell(
                                  onTap: isUploading
                                      ? null
                                      : () => setState(
                                          () => _selectedTabIndex = 1,
                                        ),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSmall,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _selectedTabIndex == 1
                                          ? AppColors.surface
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusSmall,
                                      ),
                                      boxShadow: _selectedTabIndex == 1
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withAlpha(
                                                  15,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 1),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud_upload_rounded,
                                          size: 18,
                                          color: _selectedTabIndex == 1
                                              ? AppColors.primary
                                              : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          context.l10n.bunnyTabTitle,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: _selectedTabIndex == 1
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: _selectedTabIndex == 1
                                                ? AppColors.textPrimary
                                                : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.s16),

                      // Tabs view
                      if (_selectedTabIndex == 0)
                        VideoUploadYouTubeTab(
                          contentId: widget.contentId,
                          isUploading: isUploading,
                          onUploadSuccess: widget.onUploadSuccess,
                        )
                      else
                        VideoUploadBunnyTab(
                          contentId: widget.contentId,
                          isUploading: isUploading,
                          state: state,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
