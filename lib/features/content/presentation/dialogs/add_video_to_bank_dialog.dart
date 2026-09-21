import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../videos/presentation/cubit/videos_cubit.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';

class AddVideoToBankDialog extends StatefulWidget {
  /// Optional callback invoked with the newly created [ContentEntity] before
  /// the dialog closes. Used by [AddLessonFlow] to auto-proceed to lesson setup.
  final void Function(ContentEntity created)? onCreated;

  const AddVideoToBankDialog({super.key, this.onCreated});

  static Future<bool?> show(
    BuildContext context, {
    void Function(ContentEntity created)? onCreated,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        VideosCubit? videosCubit;
        try {
          videosCubit = context.read<VideosCubit>();
        } catch (_) {
          videosCubit = InjectionContainer.createVideosCubit();
        }

        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<ContentCubit>()),
            BlocProvider.value(value: videosCubit),
          ],
          child: AddVideoToBankDialog(onCreated: onCreated),
        );
      },
    );
  }

  @override
  State<AddVideoToBankDialog> createState() => _AddVideoToBankDialogState();
}

class _AddVideoToBankDialogState extends State<AddVideoToBankDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  String? _extractedVideoId;
  PlatformFile? _selectedPdfFile;
  Uint8List? _pdfBytes;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onUrlChanged(String value) {
    setState(() {
      _extractedVideoId = YouTubeUrlParser.extractVideoId(value);
    });
  }

  Future<void> _pickPdfHandout() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _selectedPdfFile = file;
          _pdfBytes = file.bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    if (_extractedVideoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(context.l10n.invalidYoutubeUrl),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final contentCubit = context.read<ContentCubit>();
      final videosCubit = context.read<VideosCubit>();

      // 1. Create content in bank (groupId null)
      String? storagePath;
      if (_selectedPdfFile != null && _pdfBytes != null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final sanitizedName = _selectedPdfFile!.name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
        storagePath = 'bank_handouts/${timestamp}_$sanitizedName';
      }

      final repo = InjectionContainer.contentRepository;
      final createResult = await repo.createContent(
        groupId: null,
        title: _titleController.text.trim(),
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        type: ContentType.video,
        status: ContentStatus.published,
        fileName: _selectedPdfFile?.name,
        storagePath: storagePath,
        mimeType: _selectedPdfFile != null ? 'application/pdf' : null,
        fileSize: _selectedPdfFile?.size,
        fileBytes: _pdfBytes,
      );

      final createdContent = createResult.dataOrNull;
      if (createdContent == null) {
        throw Exception(createResult.failureOrNull?.message ?? 'Failed to create content');
      }

      // 2. Link YouTube Video
      final url = _urlController.text.trim();
      final videoSuccess = await videosCubit.linkYouTubeVideo(
        contentId: createdContent.id,
        youtubeUrl: url,
        title: _titleController.text.trim(),
      );

      if (!videoSuccess) {
        throw Exception('Failed to link YouTube video record');
      }

      // 3. Reload bank so library is up-to-date
      await contentCubit.loadCentralVideoBank(forceRefresh: true);

      if (!mounted) return;
      setState(() => _isSaving = false);

      // Notify parent flow (e.g. AddLessonFlow) before closing
      widget.onCreated?.call(createdContent);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.videoAddedToLibrary),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFFFF0000),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.addVideoToBankAction,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            l10n.noVideosInBankDesc,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.s8),

                // Form Scrollable Fields
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // YouTube URL Field
                        AppTextField(
                          controller: _urlController,
                          labelText: l10n.youtubeUrlLabel,
                          hintText: l10n.youtubeUrlHint,
                          prefixIcon: const Icon(Icons.link_rounded),
                          onChanged: _onUrlChanged,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return l10n.invalidYoutubeUrl;
                            }
                            if (_extractedVideoId == null) {
                              return l10n.invalidYoutubeUrl;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          l10n.youtubeUnlistedNotice,
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),

                        // Thumbnail Preview if valid URL
                        if (_extractedVideoId != null) ...[
                          const SizedBox(height: AppSpacing.s8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: CachedNetworkImage(
                                    imageUrl: 'https://img.youtube.com/vi/$_extractedVideoId/hqdefault.jpg',
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: AppColors.surfaceVariant,
                                      child: const Center(
                                        child: CircularProgressIndicator.adaptive(),
                                      ),
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: AppColors.surfaceVariant,
                                      child: const Icon(Icons.broken_image, size: 40),
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: AppSpacing.s16),

                        // Title Field
                        AppTextField(
                          controller: _titleController,
                          labelText: l10n.lessonTitleLabel,
                          hintText: l10n.lessonTitleHint,
                          prefixIcon: const Icon(Icons.title_rounded),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return l10n.lessonTitleRequired;
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppSpacing.s8),

                        // Description Field
                        AppTextField(
                          controller: _descController,
                          labelText: l10n.lessonNotesLabel,
                          hintText: l10n.lessonNotesHint,
                          prefixIcon: const Icon(Icons.description_outlined),
                          maxLines: 2,
                        ),

                        const SizedBox(height: AppSpacing.s16),

                        // Attached PDF Handout (Material)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.picture_as_pdf_rounded,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.s4),
                                  Text(
                                    l10n.materialAttachmentTitle,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: _isSaving ? null : _pickPdfHandout,
                                    icon: const Icon(Icons.attach_file, size: 16),
                                    label: Text(
                                      _selectedPdfFile == null
                                          ? l10n.chooseMaterialFile
                                          : l10n.changePdfFileAction,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedPdfFile != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _selectedPdfFile!.name,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.clear, size: 16),
                                      onPressed: () {
                                        setState(() {
                                          _selectedPdfFile = null;
                                          _pdfBytes = null;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.s16),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.s16),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    AppButton(
                      text: l10n.addVideo,
                      isLoading: _isSaving,
                      icon: Icons.add_rounded,
                      onPressed: _isSaving ? null : _handleSave,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
