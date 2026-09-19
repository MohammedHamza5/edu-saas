import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/videos_cubit.dart';
import '../cubit/videos_state.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _youtubeUrlController = TextEditingController();

  int _selectedTabIndex = 0; // 0 = YouTube, 1 = Bunny Stream
  String? _extractedYouTubeId;
  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = AppConfig.isBunnyEnabled && !AppConfig.isYouTubeEnabled ? 1 : 0;
  }

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

  Future<void> _pickVideo() async {
    setState(() => _isSelecting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedFile = file;
          _fileBytes = file.bytes;
          if (_titleController.text.trim().isEmpty) {
            // Clean up filename into human readable title
            final cleanName = file.name
                .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                .replaceAll(RegExp(r'[_-]'), ' ')
                .trim();
            _titleController.text = cleanName;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.videoPickFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSelecting = false);
      }
    }
  }

  void _startUpload() {
    if (!_formKey.currentState!.validate()) return;
    if (_fileBytes == null || _selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.videoPleaseSelectFile)),
      );
      return;
    }

    context.read<VideosCubit>().uploadVideo(
          contentId: widget.contentId,
          title: _titleController.text.trim(),
          videoBytes: _fileBytes!,
          fileName: _selectedFile!.name,
        );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
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
        final uploadProgress = state is VideoUploading ? state.progress : 0.0;
        final uploadPercentage = state is VideoUploading ? state.percentage : 0;

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
              child: Form(
                key: _formKey,
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
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
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
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
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

                        // Provider Selection Tabs (only shown if provider is not fixed per tenant)
                        if (AppConfig.showBothProviders) ...[
                          const SizedBox(height: AppSpacing.s16),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant.withAlpha(80),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: isUploading
                                        ? null
                                        : () => setState(() => _selectedTabIndex = 0),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _selectedTabIndex == 0
                                            ? AppColors.surface
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                        boxShadow: _selectedTabIndex == 0
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
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
                                        : () => setState(() => _selectedTabIndex = 1),
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      decoration: BoxDecoration(
                                        color: _selectedTabIndex == 1
                                            ? AppColors.surface
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                                        boxShadow: _selectedTabIndex == 1
                                            ? [
                                                BoxShadow(
                                                  color: Colors.black.withAlpha(15),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
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

                        // TAB 0: YOUTUBE LINKING
                        if (_selectedTabIndex == 0) ...[
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
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: YouTubeUrlParser.getThumbnailUrl(_extractedYouTubeId!),
                                    height: 160,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      height: 160,
                                      color: AppColors.surfaceVariant,
                                      child: const Center(child: AppLoadingView.compact(size: 20)),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      height: 160,
                                      color: AppColors.surfaceVariant,
                                      child: const Center(
                                        child: Icon(Icons.broken_image_rounded, color: AppColors.textSecondary),
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
                                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                                  ),
                                  Positioned(
                                    bottom: 8,
                                    left: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                              border: Border.all(color: AppColors.primary.withAlpha(60)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.security_rounded, size: 18, color: AppColors.primary),
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
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? context.l10n.lessonTitleRequired : null,
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
                        ]

                        // TAB 1: BUNNY STREAM UPLOAD
                        else ...[
                          // File Picker Button / Info Card
                          if (_selectedFile == null)
                            InkWell(
                              onTap: isUploading || _isSelecting ? null : _pickVideo,
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.s24,
                                  horizontal: AppSpacing.s16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.primary.withAlpha(100),
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                  color: AppColors.primary.withAlpha(8),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 42,
                                      color: AppColors.primary.withAlpha(200),
                                    ),
                                    const SizedBox(height: AppSpacing.s8),
                                    Text(
                                      _isSelecting ? context.l10n.openingDocuments : context.l10n.clickToPickVideo,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.s4),
                                    Text(
                                      context.l10n.autoTranscodeHint,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            AppCard(
                              padding: const EdgeInsets.all(AppSpacing.s12),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.surfaceVariant,
                                    child: Icon(Icons.movie_rounded, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: AppSpacing.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedFile!.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _formatFileSize(_selectedFile!.size),
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
                                      icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                                      tooltip: context.l10n.changeFile,
                                      onPressed: _pickVideo,
                                    ),
                                ],
                              ),
                            ),

                          const SizedBox(height: AppSpacing.s16),

                          // Form Fields
                          AppTextField(
                            controller: _titleController,
                            labelText: context.l10n.lessonTitleLabel,
                            hintText: context.l10n.lessonTitleHint,
                            enabled: !isUploading,
                            validator: (val) =>
                                val == null || val.trim().isEmpty ? context.l10n.lessonTitleRequired : null,
                          ),

                          const SizedBox(height: AppSpacing.s12),

                          AppTextField(
                            controller: _descController,
                            labelText: context.l10n.lessonNotesLabel,
                            hintText: context.l10n.lessonNotesHint,
                            maxLines: 3,
                            enabled: !isUploading,
                          ),

                          const SizedBox(height: AppSpacing.s20),

                          // Live Upload Progress Bar
                          if (isUploading) ...[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.s12),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withAlpha(20),
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusSmall),
                                border: Border.all(color: AppColors.warning.withAlpha(80)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      size: 20, color: AppColors.warning),
                                  const SizedBox(width: AppSpacing.s10),
                                  Expanded(
                                    child: Text(
                                      context.l10n.videoUploadDoNotCloseWarning,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const AppLoadingView.compact(size: 14),
                                    const SizedBox(width: AppSpacing.s8),
                                    Text(
                                      context.l10n.uploadingVideoToCdn,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$uploadPercentage%${state.totalBytes > 0 ? " (${(state.sentBytes / (1024 * 1024)).toStringAsFixed(1)} / ${(state.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)" : ""}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                              child: LinearProgressIndicator(
                                value: uploadProgress,
                                minHeight: 8,
                                backgroundColor: AppColors.surfaceVariant,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s20),
                          ],

                          // Action Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (!isUploading)
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: Text(context.l10n.cancelAction),
                                ),
                              const SizedBox(width: AppSpacing.s8),
                              AppButton(
                                text: isUploading
                                    ? context.l10n.uploadingWithPercentage(uploadPercentage)
                                    : context.l10n.startUpload,
                                icon: isUploading ? null : Icons.file_upload_outlined,
                                isLoading: isUploading,
                                onPressed: isUploading ? null : _startUpload,
                              ),
                            ],
                          ),
                        ],
                      ],
                ),
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
