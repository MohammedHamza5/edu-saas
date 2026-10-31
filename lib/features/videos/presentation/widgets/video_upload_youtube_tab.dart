import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/videos_cubit.dart';

class VideoUploadYouTubeTab extends StatefulWidget {
  final String contentId;
  final bool isUploading;
  final VoidCallback? onUploadSuccess;

  const VideoUploadYouTubeTab({
    super.key,
    required this.contentId,
    required this.isUploading,
    this.onUploadSuccess,
  });

  @override
  State<VideoUploadYouTubeTab> createState() => _VideoUploadYouTubeTabState();
}

class _VideoUploadYouTubeTabState extends State<VideoUploadYouTubeTab> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _youtubeUrlController = TextEditingController();
  String? _extractedYouTubeId;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _youtubeUrlController.dispose();
    super.dispose();
  }

  void _onYouTubeUrlChanged(String value) {
    setState(() {
      _extractedYouTubeId = YouTubeUrlParser.extractVideoId(value);
    });
  }

  Future<void> _linkYouTubeVideo() async {
    if (!_formKey.currentState!.validate()) return;
    final url = _youtubeUrlController.text.trim();
    final videoId = YouTubeUrlParser.extractVideoId(url);
    if (videoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(context.l10n.invalidYoutubeUrl),
        ),
      );
      return;
    }

    final success = await context.read<VideosCubit>().linkYouTubeVideo(
      contentId: widget.contentId,
      youtubeUrl: url,
      title: _titleController.text.trim().isNotEmpty
          ? _titleController.text.trim()
          : null,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      widget.onUploadSuccess?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(context.l10n.videoLinkedSuccessToast),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUploading = widget.isUploading;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // YouTube URL field
          AppTextField(
            controller: _youtubeUrlController,
            labelText: context.l10n.youtubeUrlLabel,
            hintText: context.l10n.youtubeUrlHint,
            prefixIcon: const Icon(
              Icons.link_rounded,
              color: Color(0xFFFF0000),
            ),
            enabled: !isUploading,
            onChanged: _onYouTubeUrlChanged,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return context.l10n.invalidYoutubeUrl;
              }
              if (YouTubeUrlParser.extractVideoId(val.trim()) == null) {
                return context.l10n.invalidYoutubeUrl;
              }
              return null;
            },
          ),

          const SizedBox(height: AppSpacing.s12),

          // Thumbnail Preview if valid URL entered
          if (_extractedYouTubeId != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(
                AppSpacing.radiusSmall,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CachedNetworkImage(
                    imageUrl: YouTubeUrlParser.getThumbnailUrl(
                      _extractedYouTubeId!,
                    ),
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 160,
                      color: AppColors.surfaceVariant,
                      child: const Center(
                        child: AppLoadingView.compact(size: 20),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      height: 160,
                      color: AppColors.surfaceVariant,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.black.withAlpha(50),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF0000),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(180),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'ID: $_extractedYouTubeId',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
          ],

          // Security Advice Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(
                AppSpacing.radiusSmall,
              ),
              border: Border.all(
                color: AppColors.primary.withAlpha(60),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.security_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    context.l10n.youtubeUnlistedAdvice,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.s12),

          // Lesson Title
          AppTextField(
            controller: _titleController,
            labelText: context.l10n.lessonTitleLabel,
            hintText: context.l10n.lessonTitleHint,
            enabled: !isUploading,
            validator: (val) => val == null || val.trim().isEmpty
                ? context.l10n.lessonTitleRequired
                : null,
          ),

          const SizedBox(height: AppSpacing.s12),

          // Lesson Notes
          AppTextField(
            controller: _descController,
            labelText: context.l10n.lessonNotesLabel,
            hintText: context.l10n.lessonNotesHint,
            maxLines: 2,
            enabled: !isUploading,
          ),

          const SizedBox(height: AppSpacing.s20),

          // Action Buttons for YouTube
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.cancelAction),
              ),
              const SizedBox(width: AppSpacing.s8),
              AppButton(
                text: context.l10n.linkVideoAction,
                icon: Icons.check_circle_outline_rounded,
                onPressed: _linkYouTubeVideo,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
