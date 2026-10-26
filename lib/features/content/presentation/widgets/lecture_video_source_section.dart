import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../videos/domain/entities/library_video_entity.dart';

enum VideoSourceType { bank, bunny, youtube, none }

/// Video source selection section (Bank, Bunny upload, YouTube, None).
class LectureVideoSourceSection extends StatelessWidget {
  final VideoSourceType selectedSource;
  final ValueChanged<VideoSourceType> onSourceChanged;
  final LibraryVideoEntity? selectedBankVideo;
  final VoidCallback onSelectFromBank;
  final VoidCallback onChangeBankVideo;
  final TextEditingController youtubeUrlController;
  final String? extractedYouTubeId;
  final ValueChanged<String> onYouTubeUrlChanged;
  final PlatformFile? pickedBunnyFile;
  final VoidCallback onPickBunnyVideo;

  const LectureVideoSourceSection({
    super.key,
    required this.selectedSource,
    required this.onSourceChanged,
    required this.selectedBankVideo,
    required this.onSelectFromBank,
    required this.onChangeBankVideo,
    required this.youtubeUrlController,
    required this.extractedYouTubeId,
    required this.onYouTubeUrlChanged,
    required this.pickedBunnyFile,
    required this.onPickBunnyVideo,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.videocam_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                context.l10n.videoSourceLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          SegmentedButton<VideoSourceType>(
            segments: [
              ButtonSegment(
                value: VideoSourceType.bank,
                label: Text(context.l10n.videoBankCmsTitle),
                icon: const Icon(
                  Icons.video_library_rounded,
                  color: AppColors.primary,
                ),
              ),
              ButtonSegment(
                value: VideoSourceType.bunny,
                label: Text(context.l10n.videoSourceBunny),
                icon: const Icon(
                  Icons.cloud_upload_rounded,
                  color: AppColors.primary,
                ),
              ),
              ButtonSegment(
                value: VideoSourceType.youtube,
                label: Text(context.l10n.videoSourceYoutube),
                icon: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.red,
                ),
              ),
              ButtonSegment(
                value: VideoSourceType.none,
                label: Text(context.l10n.videoSourceNone),
                icon: const Icon(Icons.block_rounded),
              ),
            ],
            selected: {selectedSource},
            onSelectionChanged: (set) => onSourceChanged(set.first),
          ),
          const SizedBox(height: AppSpacing.s16),

          if (selectedSource == VideoSourceType.bank) ...[
            if (selectedBankVideo == null) ...[
              InkWell(
                onTap: onSelectFromBank,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s20,
                    horizontal: AppSpacing.s16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.video_library_outlined,
                        color: AppColors.primary,
                        size: 26,
                      ),
                      const SizedBox(width: AppSpacing.s10),
                      Text(
                        context.l10n.selectFromBank,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 90,
                        height: 52,
                        color: AppColors.surfaceVariant,
                        child: selectedBankVideo!.thumbnailUrl != null
                            ? CachedNetworkImage(
                                imageUrl: selectedBankVideo!.thumbnailUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(Icons.videocam_rounded),
                                ),
                              )
                            : const Center(child: Icon(Icons.videocam_rounded)),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  context.l10n.videoSelectedFromBank,
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                selectedBankVideo!.formattedDuration,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            selectedBankVideo!.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: Text(context.l10n.changeVideo),
                      onPressed: onChangeBankVideo,
                    ),
                  ],
                ),
              ),
            ],
          ] else if (selectedSource == VideoSourceType.youtube) ...[
            AppTextField(
              controller: youtubeUrlController,
              label: context.l10n.youtubeUrlLabel,
              hintText: context.l10n.youtubeUrlHint,
              onChanged: onYouTubeUrlChanged,
              validator: (v) {
                if (selectedSource == VideoSourceType.youtube) {
                  if (v == null || v.trim().isEmpty) {
                    return context.l10n.youtubeUrlRequired;
                  }
                }
                return null;
              },
            ),
            if (extractedYouTubeId != null) ...[
              const SizedBox(height: AppSpacing.s12),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withAlpha(50),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl:
                            'https://img.youtube.com/vi/$extractedYouTubeId/hqdefault.jpg',
                        width: 100,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 100,
                          height: 56,
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YouTube Video ID Validated',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            extractedYouTubeId!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (selectedSource == VideoSourceType.bunny) ...[
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_upload_outlined),
                  label: Text(
                    pickedBunnyFile != null
                        ? context.l10n.changeVideoFileAction
                        : context.l10n.selectVideoFileAction,
                  ),
                  onPressed: onPickBunnyVideo,
                ),
                const SizedBox(width: AppSpacing.s12),
                if (pickedBunnyFile != null)
                  Expanded(
                    child: Text(
                      '${pickedBunnyFile!.name} (${(pickedBunnyFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
