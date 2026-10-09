import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../../videos/domain/entities/video_folder_entity.dart';
import '../../../videos/domain/repositories/video_bank_repository.dart';
import '../../../videos/presentation/dialogs/upload_video_to_bank_dialog.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';

class _StagedLecture {
  final LibraryVideoEntity video;
  final TextEditingController titleController;
  String? chapterId;
  PlatformFile? pdfFile;
  Uint8List? pdfBytes;
  bool isPublished;
  String? examId;
  int? customPassingScore;

  _StagedLecture({
    required this.video,
    required String initialTitle,
    this.chapterId,
    this.isPublished = true,
  }) : titleController = TextEditingController(text: initialTitle);

  void dispose() {
    titleController.dispose();
  }
}

class LessonStudioWorkspace extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String? initialChapterId;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const LessonStudioWorkspace({
    super.key,
    required this.groupId,
    required this.groupName,
    this.initialChapterId,
    required this.onSaved,
    required this.onCancel,
  });

  @override
  State<LessonStudioWorkspace> createState() => _LessonStudioWorkspaceState();
}

class _LessonStudioWorkspaceState extends State<LessonStudioWorkspace> {
  final VideoBankRepository _videoRepo = InjectionContainer.videoBankRepository;
  final ContentRepository _contentRepo = InjectionContainer.contentRepository;

  // Tree & Library State
  bool _isLoadingLibrary = true;
  List<VideoFolderEntity> _allFolders = [];
  final Map<String?, List<LibraryVideoEntity>> _folderVideosCache = {};
  final Set<String> _loadingFolderIds = {};
  final Set<String> _expandedFolderIds = {};

  // Selection & Search State
  final Map<String, LibraryVideoEntity> _selectedVideos = {};
  final Map<String, _StagedLecture> _stagedLectures = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showOnlyUnused = false;
  bool _isSidebarCollapsed = false;

  // Single Mode State
  final _singleTitleController = TextEditingController();
  PlatformFile? _singlePdfFile;
  Uint8List? _singlePdfBytes;
  String? _singleExamId;
  bool _singleIsPublished = true;
  String? _selectedChapterId;

  // Global Batch Controls
  String? _batchGlobalChapterId;
  bool _batchGlobalPublished = true;

  // Available Chapters & Exams Cache
  List<ChapterEntity> _chapters = [];
  List<Map<String, dynamic>> _availableExams = [];

  // Saving State
  bool _isSaving = false;
  String? _savingProgressMessage;

  @override
  void initState() {
    super.initState();
    _selectedChapterId = widget.initialChapterId;
    _batchGlobalChapterId = widget.initialChapterId;
    _loadLibraryData();
    _loadExams();
    _loadChapters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _singleTitleController.dispose();
    for (final staged in _stagedLectures.values) {
      staged.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExams() async {
    try {
      final client = InjectionContainer.supabaseClient;
      final res = await client
          .from('exams')
          .select('id, content:content!exams_content_id_fkey(title)')
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _availableExams = (res as List).map((e) {
            final contentMap = e['content'] as Map<String, dynamic>?;
            final title = contentMap?['title'] as String? ?? 'بدون عنوان';
            return {
              'id': e['id'] as String,
              'title': title,
            };
          }).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadChapters() async {
    try {
      final res = await _contentRepo.getGroupChapters(widget.groupId);
      if (res is Success<List<ChapterEntity>> && mounted) {
        setState(() {
          _chapters = res.data;
          if (widget.initialChapterId != null &&
              _chapters.any((c) => c.id == widget.initialChapterId)) {
            _selectedChapterId = widget.initialChapterId;
            _batchGlobalChapterId = widget.initialChapterId;
            for (final s in _stagedLectures.values) {
              s.chapterId = widget.initialChapterId;
            }
          }
        });
      }
    } catch (_) {}
  }

  List<ChapterEntity> _getEffectiveChapters(BuildContext context) {
    final cubit = context.watch<ContentCubit>();
    final cubitChapters = cubit.state is ContentLoaded
        ? (cubit.state as ContentLoaded).chapters
        : <ChapterEntity>[];
    if (cubitChapters.isNotEmpty) return cubitChapters;
    return _chapters;
  }

  Future<void> _loadLibraryData() async {
    setState(() => _isLoadingLibrary = true);
    try {
      final foldersRes = await _videoRepo.getAllFolders();
      if (foldersRes.isSuccess) {
        _allFolders = foldersRes.data;
      }
      // Pre-load root / unassigned videos
      final rootVideosRes = await _videoRepo.getVideos(folderId: null);
      if (rootVideosRes.isSuccess) {
        _folderVideosCache[null] = rootVideosRes.data;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingLibrary = false);
    }
  }

  Future<void> _loadVideosForFolder(String folderId) async {
    if (_folderVideosCache.containsKey(folderId) ||
        _loadingFolderIds.contains(folderId)) {
      return;
    }
    setState(() => _loadingFolderIds.add(folderId));
    try {
      final res = await _videoRepo.getVideos(folderId: folderId);
      if (res.isSuccess && mounted) {
        setState(() {
          _folderVideosCache[folderId] = res.data;
          _loadingFolderIds.remove(folderId);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFolderIds.remove(folderId));
    }
  }

  bool _isVideoAlreadyInCourse(LibraryVideoEntity video) {
    if (video.assignedGroupNames.any(
      (name) =>
          name.trim().toLowerCase() == widget.groupName.trim().toLowerCase(),
    )) {
      return true;
    }
    final cubit = context.read<ContentCubit>();
    if (cubit.state is ContentLoaded) {
      final items = (cubit.state as ContentLoaded).items;
      return items.any(
        (item) =>
            item.id == video.id ||
            item.videoId == video.id ||
            item.videoProviderId == video.providerVideoId,
      );
    }
    return false;
  }

  void _toggleVideoSelection(LibraryVideoEntity video) {
    setState(() {
      if (_selectedVideos.containsKey(video.id)) {
        _selectedVideos.remove(video.id);
        _stagedLectures.remove(video.id)?.dispose();
      } else {
        _selectedVideos[video.id] = video;
        _stagedLectures[video.id] = _StagedLecture(
          video: video,
          initialTitle: video.title,
          chapterId: _batchGlobalChapterId ??
              _selectedChapterId ??
              widget.initialChapterId,
          isPublished: _batchGlobalPublished,
        );
      }

      // Sync single mode inputs if 1 video selected
      if (_selectedVideos.length == 1) {
        final single = _selectedVideos.values.first;
        _singleTitleController.text = single.title;
        _singleIsPublished = true;
      }
    });
  }

  void _toggleFolderSelection(VideoFolderEntity folder) {
    final videos = _folderVideosCache[folder.id] ?? [];
    if (videos.isEmpty) return;

    final allSelected = videos.every((v) => _selectedVideos.containsKey(v.id));

    setState(() {
      if (allSelected) {
        // Deselect all
        for (final v in videos) {
          _selectedVideos.remove(v.id);
          _stagedLectures.remove(v.id)?.dispose();
        }
      } else {
        // Select all in folder
        for (final v in videos) {
          if (!_selectedVideos.containsKey(v.id)) {
            _selectedVideos[v.id] = v;
            _stagedLectures[v.id] = _StagedLecture(
              video: v,
              initialTitle: v.title,
              chapterId: _batchGlobalChapterId ??
                  _selectedChapterId ??
                  widget.initialChapterId,
              isPublished: _batchGlobalPublished,
            );
          }
        }
      }

      if (_selectedVideos.length == 1) {
        _singleTitleController.text = _selectedVideos.values.first.title;
      }
    });
  }

  bool? _getFolderCheckboxState(VideoFolderEntity folder) {
    final videos = _folderVideosCache[folder.id];
    if (videos == null || videos.isEmpty) return false;
    final selectedCount = videos
        .where((v) => _selectedVideos.containsKey(v.id))
        .length;
    if (selectedCount == 0) return false;
    if (selectedCount == videos.length) return true;
    return null; // Indeterminate
  }

  Future<void> _showQuickCreateChapterDialog(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final titleController = TextEditingController();
    bool isPublished = true;
    bool isSubmitting = false;

    final createdChapter = await showDialog<ChapterEntity>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.create_new_folder_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Text(l10n.newChapterDialogTitle),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: titleController,
                labelText: l10n.chapterTitleLabel,
                hintText: l10n.chapterTitleHint,
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.s16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPublished
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: isPublished
                          ? AppColors.success
                          : AppColors.warning,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.lecturePublishStatus,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            isPublished
                                ? l10n.chapterVisibilityPublished
                                : l10n.chapterVisibilityDraft,
                            style: TextStyle(
                              fontSize: 11,
                              color: isPublished
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: isPublished,
                      activeColor: AppColors.success,
                      onChanged: (val) =>
                          setDialogState(() => isPublished = val),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            AppButton(
              text: l10n.save,
              isLoading: isSubmitting,
              onPressed: () async {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                setDialogState(() => isSubmitting = true);
                final chapter = await context
                    .read<ContentCubit>()
                    .createChapter(
                      groupId: widget.groupId,
                      title: title,
                      isPublished: isPublished,
                    );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop(chapter);
                }
              },
            ),
          ],
        ),
      ),
    );

    if (createdChapter != null && mounted) {
      setState(() {
        if (!_chapters.any((c) => c.id == createdChapter.id)) {
          _chapters.add(createdChapter);
        }
        _selectedChapterId = createdChapter.id;
        _batchGlobalChapterId = createdChapter.id;
        for (final staged in _stagedLectures.values) {
          staged.chapterId = createdChapter.id;
        }
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.chapterCreatedSuccess),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _pickSinglePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _singlePdfFile = result.files.first;
        _singlePdfBytes = result.files.first.bytes;
      });
    }
  }

  Future<void> _pickBatchPdf(_StagedLecture staged) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        staged.pdfFile = result.files.first;
        staged.pdfBytes = result.files.first.bytes;
      });
    }
  }

  Future<String?> _uploadPdfForVideo({
    required LibraryVideoEntity video,
    required PlatformFile file,
    required Uint8List bytes,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = file.name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_.-]'),
      '_',
    );
    final storagePath = 'groups/${widget.groupId}/${timestamp}_$safeName';

    final cubit = context.read<ContentCubit>();
    return await cubit.uploadAndCreateFileRecord(
      tenantId: video.tenantId,
      contentId: video.id,
      fileName: file.name,
      mimeType: 'application/pdf',
      fileBytes: bytes,
      storagePath: storagePath,
    );
  }

  Future<void> _handleSaveSingle() async {
    if (_selectedVideos.isEmpty) return;
    final video = _selectedVideos.values.first;

    final cubit = context.read<ContentCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    setState(() {
      _isSaving = true;
      _savingProgressMessage = l10n.savingChanges;
    });

    try {
      String? fileId;
      if (_singlePdfFile != null && _singlePdfBytes != null) {
        fileId = await _uploadPdfForVideo(
          video: video,
          file: _singlePdfFile!,
          bytes: _singlePdfBytes!,
        );
      }

      final title = _singleTitleController.text.trim().isNotEmpty
          ? _singleTitleController.text.trim()
          : video.title;

        final singleChapter = _selectedChapterId ??
            _batchGlobalChapterId ??
            widget.initialChapterId;

        final success = await cubit.assignContentToGroups(
          contentId: video.id,
          groupIds: [widget.groupId],
          groupConfigs: [
            {
              'group_id': widget.groupId,
              'is_published': _singleIsPublished,
              'custom_title': title,
              if (fileId != null) 'file_id': fileId,
              if (_singleExamId != null) 'associated_exam_id': _singleExamId,
              if (singleChapter != null) 'chapter_id': singleChapter,
            },
          ],
        );

        if (success && mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.contentUpdatedToast),
              backgroundColor: AppColors.success,
            ),
          );
          widget.onSaved();
        }
      } catch (_) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(l10n.lessonEditorErrorSaving),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }

    Future<void> _handleSaveBatch() async {
      final list = _stagedLectures.values.toList();
      if (list.isEmpty) return;

      final cubit = context.read<ContentCubit>();
      final messenger = ScaffoldMessenger.of(context);
      final l10n = context.l10n;

      setState(() {
        _isSaving = true;
        _savingProgressMessage = l10n.savingChanges;
      });

      try {
        final items = <Map<String, dynamic>>[];

        for (final staged in list) {
          String? fileId;
          if (staged.pdfFile != null && staged.pdfBytes != null) {
            fileId = await _uploadPdfForVideo(
              video: staged.video,
              file: staged.pdfFile!,
              bytes: staged.pdfBytes!,
            );
          }

          final title = staged.titleController.text.trim().isNotEmpty
              ? staged.titleController.text.trim()
              : staged.video.title;

          final chapter = staged.chapterId ??
              _batchGlobalChapterId ??
              _selectedChapterId ??
              widget.initialChapterId;

          items.add({
            'content_id': staged.video.id,
            'custom_title': title,
            if (chapter != null) 'chapter_id': chapter,
            'is_published': staged.isPublished,
            if (staged.examId != null) 'associated_exam_id': staged.examId,
            if (fileId != null) 'file_id': fileId,
          });
        }

      final success = await cubit.assignBatchContentToGroup(
        groupId: widget.groupId,
        items: items,
      );

      if (success && mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.batchAddSuccessToast(items.length)),
            backgroundColor: AppColors.success,
          ),
        );
        widget.onSaved();
      }
    } catch (_) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.lessonEditorErrorSaving),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isDesktop = MediaQuery.of(context).size.width >= 960;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Studio Command Header ──────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: AppSpacing.s12,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(l10n.backToCourse),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.lessonStudioTitle,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Text(
                                widget.groupName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.lessonStudioSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Selection Counter Pill
                  if (_selectedVideos.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _selectedVideos.length == 1
                                ? l10n.singleLectureSetup
                                : l10n.batchModeTitle(_selectedVideos.length),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                  ],

                  // Action Buttons in Header
                  TextButton(
                    onPressed: widget.onCancel,
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  AppButton(
                    text: _selectedVideos.length > 1
                        ? l10n.addBatchLecturesButton(_selectedVideos.length)
                        : l10n.saveLectureButton,
                    icon: _selectedVideos.length > 1
                        ? Icons.rocket_launch_rounded
                        : Icons.save_rounded,
                    isLoading: _isSaving,
                    onPressed: _selectedVideos.isEmpty
                        ? null
                        : (_selectedVideos.length > 1
                              ? _handleSaveBatch
                              : _handleSaveSingle),
                  ),
                ],
              ),
            ),

            // ── Main Workspace Body: Split View ────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Left 1/3 Panel: Collapsible Video Bank Tree ───────────
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    width: _isSidebarCollapsed ? 48 : (isDesktop ? 360 : 300),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      border: Border(
                        left: BorderSide(color: AppColors.border),
                        right: BorderSide(color: AppColors.border),
                      ),
                    ),
                    child: _isSidebarCollapsed
                        ? _buildCollapsedSidebar(context)
                        : _buildExpandedSidebar(context),
                  ),

                  // ── Right 2/3 Panel: Lecture Staging / Configuration Deck ─
                  Expanded(
                    child: Container(
                      color: AppColors.background,
                      child: _buildRightWorkspace(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Progress Modal Overlay when saving
        if (_isSaving)
          Container(
            color: Colors.black.withValues(alpha: 0.6),
            child: Center(
              child: AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLoadingView.signature(),
                      const SizedBox(height: AppSpacing.s20),
                      Text(
                        _savingProgressMessage ?? l10n.savingChanges,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Collapsed Sidebar View ───────────────────────────────────────────────
  Widget _buildCollapsedSidebar(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.s12),
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: context.l10n.expandSidebar,
          onPressed: () => setState(() => _isSidebarCollapsed = false),
        ),
        const Divider(),
        RotatedBox(
          quarterTurns: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              context.l10n.videoBankSidebarTitle,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Expanded Sidebar View (Full Video Tree) ──────────────────────────────
  Widget _buildExpandedSidebar(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      children: [
        // Sidebar Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              const Icon(
                Icons.video_library_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.videoBankSidebarTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: l10n.collapseSidebar,
                onPressed: () => setState(() => _isSidebarCollapsed = true),
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: _searchController,
            onChanged: (v) =>
                setState(() => _searchQuery = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: l10n.searchVideosAndFoldersHint,
              hintStyle: const TextStyle(fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // Filter & Batch Selection Shortcuts
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              // Filter chip: Unused only
              FilterChip(
                selected: _showOnlyUnused,
                onSelected: (val) => setState(() => _showOnlyUnused = val),
                label: Text(
                  l10n.unusedVideosFilter,
                  style: const TextStyle(fontSize: 11),
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              if (_selectedVideos.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    _selectedVideos.clear();
                    for (final s in _stagedLectures.values) {
                      s.dispose();
                    }
                    _stagedLectures.clear();
                  }),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    l10n.clearSelection,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tree Content List
        Expanded(
          child: _isLoadingLibrary
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadLibraryData,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      // Folders List
                      for (final folder in _allFolders)
                        _buildFolderTreeItem(context, folder),

                      // Root / General Videos (No Folder)
                      _buildRootVideosItem(context),
                    ],
                  ),
                ),
        ),

        // Bottom Upload Direct Action
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: OutlinedButton.icon(
            onPressed: () async {
              final uploaded = await UploadVideoToBankDialog.show(context);
              if (uploaded == true) {
                await _loadLibraryData();
              }
            },
            icon: const Icon(Icons.cloud_upload_outlined, size: 16),
            label: Text(
              l10n.uploadNewVideoShort,
              style: const TextStyle(fontSize: 12),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(36),
            ),
          ),
        ),
      ],
    );
  }

  // ── Folder Accordion Item ────────────────────────────────────────────────
  Widget _buildFolderTreeItem(BuildContext context, VideoFolderEntity folder) {
    final l10n = context.l10n;
    final isExpanded = _expandedFolderIds.contains(folder.id);
    final isLoading = _loadingFolderIds.contains(folder.id);
    final videos = _folderVideosCache[folder.id] ?? [];

    final filteredVideos = videos.where((v) {
      if (_searchQuery.isNotEmpty &&
          !v.title.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_showOnlyUnused && _isVideoAlreadyInCourse(v)) {
        return false;
      }
      return true;
    }).toList();

    // If search active and matches folder name, or has filtered videos
    if (_searchQuery.isNotEmpty &&
        filteredVideos.isEmpty &&
        !folder.name.toLowerCase().contains(_searchQuery)) {
      return const SizedBox.shrink();
    }

    final triState = _getFolderCheckboxState(folder);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedFolderIds.remove(folder.id);
              } else {
                _expandedFolderIds.add(folder.id);
                unawaited(_loadVideosForFolder(folder.id));
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // Expand Icon
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),

                // Folder Tri-State Checkbox
                Checkbox(
                  value: triState,
                  tristate: true,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) {
                    if (!_folderVideosCache.containsKey(folder.id)) {
                      _loadVideosForFolder(folder.id).then((_) {
                        _toggleFolderSelection(folder);
                      });
                    } else {
                      _toggleFolderSelection(folder);
                    }
                  },
                ),
                const SizedBox(width: 4),

                // Folder Color Dot / Icon
                Icon(
                  Icons.folder_rounded,
                  size: 18,
                  color: folder.color != null
                      ? Color(
                          int.parse(folder.color!.replaceFirst('#', '0xFF')),
                        )
                      : AppColors.primary,
                ),
                const SizedBox(width: 8),

                // Folder Name & Count
                Expanded(
                  child: Text(
                    folder.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Badge of item count
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    videos.isNotEmpty
                        ? videos.length.toString()
                        : folder.videoCount.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded Videos List
        if (isExpanded) ...[
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (filteredVideos.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 4, 16, 8),
              child: Text(
                l10n.emptyChapterPlaceholder,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Column(
                children: [
                  for (final video in filteredVideos)
                    _buildVideoRow(context, video),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // ── Root Videos List Item ────────────────────────────────────────────────
  Widget _buildRootVideosItem(BuildContext context) {
    final l10n = context.l10n;
    final videos = _folderVideosCache[null] ?? [];
    final filteredVideos = videos.where((v) {
      if (_searchQuery.isNotEmpty &&
          !v.title.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_showOnlyUnused && _isVideoAlreadyInCourse(v)) {
        return false;
      }
      return true;
    }).toList();

    if (filteredVideos.isEmpty && videos.isEmpty) {
      return const SizedBox.shrink();
    }

    final isExpanded = _expandedFolderIds.contains('__root__');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedFolderIds.remove('__root__');
              } else {
                _expandedFolderIds.add('__root__');
              }
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.snippet_folder_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.unassignedFolderVideos,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    filteredVideos.length.toString(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Column(
              children: [
                for (final video in filteredVideos)
                  _buildVideoRow(context, video),
              ],
            ),
          ),
      ],
    );
  }

  // ── Individual Video Row in the Tree ─────────────────────────────────────
  Widget _buildVideoRow(BuildContext context, LibraryVideoEntity video) {
    final isSelected = _selectedVideos.containsKey(video.id);
    final isAlreadyAdded = _isVideoAlreadyInCourse(video);

    return InkWell(
      onTap: () => _toggleVideoSelection(video),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Checkbox(
              value: isSelected,
              visualDensity: VisualDensity.compact,
              onChanged: (_) => _toggleVideoSelection(video),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                video.formattedDuration,
                style: const TextStyle(
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (isAlreadyAdded)
                    Text(
                      context.l10n.alreadyAddedBadge,
                      style: const TextStyle(
                        fontSize: 9.5,
                        color: AppColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Right Workspace Builder ──────────────────────────────────────────────
  Widget _buildRightWorkspace(BuildContext context) {
    if (_selectedVideos.isEmpty) {
      return _buildNoVideosPlaceholder(context);
    }
    if (_selectedVideos.length == 1) {
      return _buildSingleLectureDeck(context, _selectedVideos.values.first);
    }
    return _buildBatchLecturesDeck(context);
  }

  // ── Placeholder when 0 videos selected ───────────────────────────────────
  Widget _buildNoVideosPlaceholder(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.video_library_rounded,
                size: 38,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.s20),
            Text(
              l10n.noVideosSelectedTitle,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s8),
            Text(
              l10n.noVideosSelectedSubtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_allFolders.isNotEmpty)
                  AppButton(
                    text: l10n.selectAll,
                    icon: Icons.checklist_rounded,
                    variant: AppButtonVariant.outlined,
                    onPressed: () {
                      if (_allFolders.isNotEmpty) {
                        _toggleFolderSelection(_allFolders.first);
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Single Lecture Configuration Deck ────────────────────────────────────
  Widget _buildSingleLectureDeck(
    BuildContext context,
    LibraryVideoEntity video,
  ) {
    final l10n = context.l10n;
    final chapters = _getEffectiveChapters(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Video Summary Header Card
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Row(
                    children: [
                      Container(
                        width: 90,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                          image: video.thumbnailUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(video.thumbnailUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 28,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    video.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    video.formattedDuration,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _singleTitleController.text = video.title;
                                });
                              },
                              icon: const Icon(Icons.sync_rounded, size: 14),
                              label: Text(
                                l10n.useVideoTitleAction,
                                style: const TextStyle(fontSize: 11),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Title Field
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.lessonTitleLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      AppTextField(
                        controller: _singleTitleController,
                        hintText: l10n.lessonTitleHint,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Academic Chapter Selector
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.targetChapterLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _showQuickCreateChapterDialog(context),
                            icon: const Icon(Icons.add_rounded, size: 14),
                            label: Text(
                              l10n.quickCreateChapter,
                              style: const TextStyle(fontSize: 11),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s10),
                      DropdownButtonFormField<String?>(
                        value: chapters.any((c) => c.id == _selectedChapterId)
                            ? _selectedChapterId
                            : null,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(l10n.noChapterOption),
                          ),
                          for (final ch in chapters)
                            DropdownMenuItem<String?>(
                              value: ch.id,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.folder_rounded,
                                    size: 16,
                                    color: ch.isPublished
                                        ? AppColors.primary
                                        : AppColors.warning,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(ch.title),
                                  if (!ch.isPublished) ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${l10n.chapterVisibilityDraft})',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedChapterId = val;
                            _batchGlobalChapterId = val;
                            for (final s in _stagedLectures.values) {
                              s.chapterId = val;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // PDF Handout Attachment
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pdfHandoutSection,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s10),
                      if (_singlePdfFile == null)
                        OutlinedButton.icon(
                          onPressed: _pickSinglePdf,
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 16,
                          ),
                          label: Text(l10n.uploadPdfHandout),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_rounded,
                                color: Color(0xFFEA580C),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _singlePdfFile!.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${(_singlePdfFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: AppColors.error,
                                tooltip: l10n.removePdfHandout,
                                onPressed: () {
                                  setState(() {
                                    _singlePdfFile = null;
                                    _singlePdfBytes = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Mandatory Exam / Quiz
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.mandatoryQuizSection,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s10),
                      DropdownButtonFormField<String?>(
                        value: _singleExamId,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(l10n.noQuizAttached),
                          ),
                          for (final exam in _availableExams)
                            DropdownMenuItem<String?>(
                              value: exam['id'] as String?,
                              child: Text(exam['title'] as String? ?? ''),
                            ),
                        ],
                        onChanged: (val) => setState(() => _singleExamId = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Publishing Status Toggle
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Row(
                    children: [
                      Icon(
                        _singleIsPublished
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: _singleIsPublished
                            ? AppColors.success
                            : AppColors.warning,
                        size: 24,
                      ),
                      const SizedBox(width: AppSpacing.s14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.lecturePublishStatus,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _singleIsPublished
                                  ? l10n.lecturePublishedDescription
                                  : l10n.lectureDraftDescription,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _singleIsPublished,
                        activeColor: AppColors.success,
                        onChanged: (val) =>
                            setState(() => _singleIsPublished = val),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s32),

              // Bottom Save Button
              AppButton(
                text: l10n.saveLectureButton,
                icon: Icons.save_rounded,
                isLoading: _isSaving,
                onPressed: _handleSaveSingle,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Batch Lectures Orchestration Deck ────────────────────────────────────
  Widget _buildBatchLecturesDeck(BuildContext context) {
    final l10n = context.l10n;
    final chapters = _getEffectiveChapters(context);

    final stagedList = _stagedLectures.values.toList();

    return Column(
      children: [
        // Batch Header & Global Toolbar Card
        Container(
          padding: const EdgeInsets.all(AppSpacing.s20),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
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
                          l10n.batchModeTitle(stagedList.length),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          l10n.batchModeSubtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Global Bulk Assignment Bar
              Row(
                children: [
                  // Global Chapter Selector
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: chapters.any((c) => c.id == _batchGlobalChapterId)
                                ? _batchGlobalChapterId
                                : null,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: l10n.applyChapterToAll,
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.surfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(l10n.noChapterOption),
                              ),
                              for (final ch in chapters)
                                DropdownMenuItem<String?>(
                                  value: ch.id,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.folder_rounded,
                                        size: 16,
                                        color: ch.isPublished
                                            ? AppColors.primary
                                            : AppColors.warning,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          ch.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (!ch.isPublished) ...[
                                        const SizedBox(width: 6),
                                        Text(
                                          '(${l10n.chapterVisibilityDraft})',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _batchGlobalChapterId = val;
                                _selectedChapterId = val;
                                for (final s in _stagedLectures.values) {
                                  s.chapterId = val;
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        IconButton(
                          icon: const Icon(Icons.add_rounded),
                          tooltip: l10n.quickCreateChapter,
                          onPressed: () =>
                              _showQuickCreateChapterDialog(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s16),

                  // Global Publish / Draft Switch
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _batchGlobalPublished
                              ? l10n.publishAllBatch
                              : l10n.draftAllBatch,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _batchGlobalPublished
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _batchGlobalPublished,
                          activeColor: AppColors.success,
                          onChanged: (val) {
                            setState(() {
                              _batchGlobalPublished = val;
                              for (final s in stagedList) {
                                s.isPublished = val;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Staging List of Selected Lectures
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.s20),
            itemCount: stagedList.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
            itemBuilder: (ctx, index) {
              final staged = stagedList[index];
              return _buildBatchLectureCard(ctx, staged, index + 1, chapters);
            },
          ),
        ),

        // Master Add Button Bottom Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Text(
                '${stagedList.length} ${l10n.lessonStudioTitle}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              AppButton(
                text: l10n.addBatchLecturesButton(stagedList.length),
                icon: Icons.rocket_launch_rounded,
                isLoading: _isSaving,
                onPressed: _handleSaveBatch,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Individual Card in Batch Staging Queue ───────────────────────────────
  Widget _buildBatchLectureCard(
    BuildContext context,
    _StagedLecture staged,
    int index,
    List<ChapterEntity> chapters,
  ) {
    final l10n = context.l10n;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Index, Duration Badge, Lecture Title, Delete Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Index Avatar
                CircleAvatar(
                  radius: 13,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    index.toString(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s10),

                // Duration Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        staged.video.formattedDuration,
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),

                // Editable Title
                Expanded(
                  child: AppTextField(
                    controller: staged.titleController,
                    labelText: l10n.lessonTitleLabel,
                    hintText: staged.video.title,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),

                // Remove from batch button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.error,
                  tooltip: l10n.deleteAction,
                  onPressed: () {
                    setState(() {
                      _selectedVideos.remove(staged.video.id);
                      _stagedLectures.remove(staged.video.id)?.dispose();
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s12),

            // Row 2: Chapter Selector, Quiz Selector, PDF Handout, Publish Switch
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                return Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // 1. Chapter Dropdown
                    SizedBox(
                      width: isNarrow ? double.infinity : 200,
                      child: DropdownButtonFormField<String?>(
                        value: chapters.any((c) => c.id == staged.chapterId)
                            ? staged.chapterId
                            : null,
                        isDense: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.folder_outlined, size: 16),
                          labelText: l10n.targetChapterLabel,
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              l10n.noChapterOption,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                          for (final ch in chapters)
                            DropdownMenuItem<String?>(
                              value: ch.id,
                              child: Text(
                                ch.title,
                                style: const TextStyle(fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (val) => setState(() => staged.chapterId = val),
                      ),
                    ),

                    // 2. Quiz / Exam Dropdown
                    SizedBox(
                      width: isNarrow ? double.infinity : 220,
                      child: DropdownButtonFormField<String?>(
                        value: staged.examId,
                        isDense: true,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.quiz_outlined, size: 16, color: AppColors.primary),
                          labelText: l10n.mandatoryQuizSection,
                          isDense: true,
                          filled: true,
                          fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              l10n.noQuizAttached,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                          ),
                          for (final exam in _availableExams)
                            DropdownMenuItem<String?>(
                              value: exam['id'] as String?,
                              child: Text(
                                exam['title'] as String? ?? '',
                                style: const TextStyle(fontSize: 11.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (val) => setState(() => staged.examId = val),
                      ),
                    ),

                    // 3. PDF Handout Action Button or File Chip
                    if (staged.pdfFile == null)
                      OutlinedButton.icon(
                        onPressed: () => _pickBatchPdf(staged),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: Color(0xFFEA580C)),
                        label: Text(
                          l10n.uploadPdfHandout,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFFEA580C)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: const Color(0xFFEA580C).withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          border: Border.all(color: const Color(0xFFEA580C).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Color(0xFFEA580C)),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 140),
                              child: Text(
                                staged.pdfFile!.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEA580C),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () => setState(() {
                                staged.pdfFile = null;
                                staged.pdfBytes = null;
                              }),
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(Icons.close_rounded, size: 14, color: Color(0xFFEA580C)),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 4. Publish Toggle Switch
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: staged.isPublished
                            ? AppColors.success.withValues(alpha: 0.08)
                            : AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                        border: Border.all(
                          color: staged.isPublished
                              ? AppColors.success.withValues(alpha: 0.3)
                              : AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            staged.isPublished
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                            size: 16,
                            color: staged.isPublished ? AppColors.success : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            staged.isPublished ? l10n.statusPublished : l10n.statusDraft,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: staged.isPublished ? AppColors.success : AppColors.warning,
                            ),
                          ),
                          Switch(
                            value: staged.isPublished,
                            activeColor: AppColors.success,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) => setState(() => staged.isPublished = val),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
