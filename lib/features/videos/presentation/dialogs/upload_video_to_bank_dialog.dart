import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/video_bank_cubit.dart';
import '../cubit/video_bank_state.dart';

class UploadVideoToBankDialog extends StatefulWidget {
  final String? currentFolderName;

  const UploadVideoToBankDialog({super.key, this.currentFolderName});

  static Future<bool?> show(BuildContext context, {String? currentFolderName}) {
    final cubit = context.read<VideoBankCubit>();
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: cubit,
        child: UploadVideoToBankDialog(currentFolderName: currentFolderName),
      ),
    );
  }

  @override
  State<UploadVideoToBankDialog> createState() =>
      _UploadVideoToBankDialogState();
}

class _UploadVideoToBankDialogState extends State<UploadVideoToBankDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
  bool _isPicking = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideoFile() async {
    setState(() => _isPicking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final sizeMb = (file.size / (1024 * 1024)).toStringAsFixed(1);

        // Web browsers have a hard memory buffer limit (~1.5GB to 2GB)
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

        Uint8List? bytes = file.bytes;

        // If bytes are null on desktop/mobile, read from path
        if (!kIsWeb && bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        } else if (bytes == null && file.readStream != null) {
          final chunks = await file.readStream!.toList();
          final total = chunks.fold<int>(0, (sum, c) => sum + c.length);
          final buffer = Uint8List(total);
          int offset = 0;
          for (final c in chunks) {
            buffer.setRange(offset, offset + c.length, c);
            offset += c.length;
          }
          bytes = buffer;
        }

        if (bytes != null) {
          setState(() {
            _pickedFile = file;
            _fileBytes = bytes;
            if (_titleController.text.trim().isEmpty) {
              // Auto-fill title from file name without extension
              final name = file.name;
              final dotIndex = name.lastIndexOf('.');
              _titleController.text = dotIndex > 0
                  ? name.substring(0, dotIndex)
                  : name;
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
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _handleUpload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.selectVideoFile),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : null;
    final bytes = _fileBytes!;
    final l10n = context.l10n;

    // 1. Trigger background upload on the persistent VideoBankCubit
    unawaited(
      context.read<VideoBankCubit>().uploadVideo(
        title: title,
        description: description,
        videoBytes: bytes,
      ),
    );

    // 2. Dismiss dialog immediately so teacher is free to work
    if (mounted) {
      Navigator.of(context).pop(true);
    }

    // 3. Show smooth SnackBar feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.cloud_upload_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  l10n.uploadStartedInBackground,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return BlocConsumer<VideoBankCubit, VideoBankState>(
      listener: (context, state) {
        if (state is VideoBankError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isUploading = state is VideoBankLoaded && state.isUploading;
        final progress = (state is VideoBankLoaded)
            ? state.uploadProgress
            : null;

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
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
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.cloud_upload_rounded,
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
                                l10n.uploadToBank,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.currentFolderName != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.currentFolderName!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isUploading)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 20),
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // File picker area
                    if (_pickedFile == null) ...[
                      InkWell(
                        onTap: isUploading || _isPicking
                            ? null
                            : _pickVideoFile,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s24,
                            horizontal: AppSpacing.s16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            color: AppColors.surfaceVariant.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.video_file_outlined,
                                size: 44,
                                color: AppColors.primary.withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: AppSpacing.s8),
                              Text(
                                l10n.selectVideoFile,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.videoFileTypesHint,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
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
                          color: AppColors.primary.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.s10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _pickedFile!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${(_pickedFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isUploading)
                              TextButton(
                                onPressed: _pickVideoFile,
                                child: Text(l10n.changeVideo),
                              ),
                          ],
                        ),
                      ),
                    ],

                    // Tip banner for long lectures
                    Container(
                      margin: const EdgeInsets.only(top: AppSpacing.s10),
                      padding: const EdgeInsets.all(AppSpacing.s10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              l10n.longVideoExportTip,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s16),

                    // Title
                    AppTextField(
                      controller: _titleController,
                      label: l10n.videoTitleHint,
                      hintText: l10n.videoTitleHint,
                      enabled: !isUploading,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? l10n.fieldRequired
                          : null,
                    ),

                    const SizedBox(height: AppSpacing.s12),

                    // Description
                    AppTextField(
                      controller: _descriptionController,
                      label: l10n.contentDescriptionLabel,
                      hintText: l10n.contentDescriptionLabel,
                      maxLines: 2,
                      enabled: !isUploading,
                    ),

                    // Upload Progress Bar
                    if (isUploading && progress != null) ...[
                      const SizedBox(height: AppSpacing.s16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 8,
                          backgroundColor: AppColors.surfaceVariant,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.uploadingVideo,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: AppSpacing.s24),

                    // Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isUploading)
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(l10n.cancel),
                          ),
                        const SizedBox(width: AppSpacing.s8),
                        AppButton(
                          text: isUploading
                              ? l10n.uploadingVideo
                              : l10n.uploadToBank,
                          icon: isUploading
                              ? null
                              : Icons.cloud_upload_outlined,
                          isLoading: isUploading,
                          onPressed: isUploading || _fileBytes == null
                              ? null
                              : _handleUpload,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
