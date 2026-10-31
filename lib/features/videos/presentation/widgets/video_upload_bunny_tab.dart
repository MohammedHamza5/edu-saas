import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/videos_cubit.dart';
import '../cubit/videos_state.dart';

class VideoUploadBunnyTab extends StatefulWidget {
  final String contentId;
  final bool isUploading;
  final VideosState state;

  const VideoUploadBunnyTab({
    super.key,
    required this.contentId,
    required this.isUploading,
    required this.state,
  });

  @override
  State<VideoUploadBunnyTab> createState() => _VideoUploadBunnyTabState();
}

class _VideoUploadBunnyTabState extends State<VideoUploadBunnyTab> {
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
        final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(1);

        if (kIsWeb && file.size > 2000 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.videoFileTooLargeForWeb(sizeMb)),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 8),
              ),
            );
          }
          return;
        }

        final bytes = file.bytes;
        if (bytes != null) {
          setState(() {
            _selectedFile = file;
            _fileBytes = bytes;
            if (_titleController.text.trim().isEmpty) {
              final cleanName = file.name
                  .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                  .replaceAll(RegExp(r'[_-]'), ' ')
                  .trim();
              _titleController.text = cleanName;
            }
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.videoFileMemoryError(sizeMb)),
                backgroundColor: AppColors.error,
                duration: const Duration(seconds: 8),
              ),
            );
          }
        }
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
    final isUploading = widget.isUploading;
    final state = widget.state;
    final uploadProgress = state is VideoUploading ? state.progress : 0.0;
    final uploadPercentage = state is VideoUploading ? state.percentage : 0;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                      _isSelecting
                          ? context.l10n.openingDocuments
                          : context.l10n.clickToPickVideo,
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
                    child: Icon(
                      Icons.movie_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
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
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.primary,
                      ),
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
            validator: (val) => val == null || val.trim().isEmpty
                ? context.l10n.lessonTitleRequired
                : null,
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
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(
                  color: AppColors.warning.withAlpha(80),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: AppColors.warning,
                  ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '$uploadPercentage%${(state is VideoUploading && state.totalBytes > 0) ? " (${(state.sentBytes / (1024 * 1024)).toStringAsFixed(1)} / ${(state.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB)" : ""}',
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
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
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
    );
  }
}
