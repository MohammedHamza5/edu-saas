import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
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

  PlatformFile? _selectedFile;
  Uint8List? _fileBytes;
  bool _isSelecting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
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
                                context.l10n.fastEncryptedCdnHosting,
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

                    const SizedBox(height: AppSpacing.s16),

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
