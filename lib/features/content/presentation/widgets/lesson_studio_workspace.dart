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
import '../../domain/entities/library_material_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/select_material_from_library_dialog.dart';
import '../../../notifications/domain/services/notification_dispatcher.dart';

class _StudioAttachedExam {
  final String examId;
  String examTitle;
  bool isRequired;

  _StudioAttachedExam({
    required this.examId,
    required this.examTitle,
    this.isRequired = true,
  });

  Map<String, dynamic> toJson({int sortOrder = 0}) => {
    'exam_id': examId,
    'sort_order': sortOrder,
    'is_required': isRequired,
  };
}

class _StagedLecture {
  final LibraryVideoEntity video;
  final TextEditingController titleController;
  String? chapterId;
  PlatformFile? pdfFile;
  Uint8List? pdfBytes;
  LibraryMaterialEntity? libraryMaterial;
  bool isPublished;
  final List<_StudioAttachedExam> attachedExams = [];
  int? customPassingScore;

  bool get hasPdf => libraryMaterial != null || pdfFile != null;
  String get pdfDisplayName =>
      libraryMaterial != null ? libraryMaterial!.title : (pdfFile?.name ?? '');
  int? get pdfSize =>
      libraryMaterial != null ? libraryMaterial!.fileSize : (pdfFile?.size);

  String? get formattedPdfSize {
    final size = pdfSize;
    if (size == null) return null;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get hasExam => attachedExams.isNotEmpty;

  String? get examId =>
      attachedExams.isNotEmpty ? attachedExams.first.examId : null;
  set examId(String? id) {
    attachedExams.clear();
    if (id != null) {
      attachedExams.add(_StudioAttachedExam(examId: id, examTitle: ''));
    }
  }

  _StagedLecture({
    required this.video,
    required String initialTitle,
    this.chapterId,
    this.isPublished = true,
    List<_StudioAttachedExam>? initialExams,
    this.libraryMaterial,
  }) : titleController = TextEditingController(text: initialTitle) {
    if (initialExams != null) {
      attachedExams.addAll(initialExams);
    }
  }

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

  // Selection & Search State (Unified Single Source of Truth)
  final Map<String, LibraryVideoEntity> _selectedVideos = {};
  final Map<String, _StagedLecture> _stagedLectures = {};
  final List<String> _stagedOrder = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showOnlyUnused = false;
  bool _isSidebarCollapsed = false;

  // Instant O(1) Video In Course Cache
  final Set<String> _courseVideoIds = {};
  final Set<String> _courseVideoProviderIds = {};

  // Global Batch Controls
  String? _batchGlobalChapterId;
  bool _batchGlobalPublished = true;

  // Active Inspecting Target for Detail Drawer
  _StagedLecture? _inspectingLecture;

  // Available Chapters & Exams Cache
  List<ChapterEntity> _chapters = [];
  List<Map<String, dynamic>> _availableExams = [];

  // Saving State
  bool _isSaving = false;
  String? _savingProgressMessage;

  @override
  void initState() {
    super.initState();
    _batchGlobalChapterId = widget.initialChapterId;
    _initCourseVideoSet();
    _loadLibraryData();
    _loadExams();
    _loadChapters();
  }

  void _initCourseVideoSet() {
    _courseVideoIds.clear();
    _courseVideoProviderIds.clear();
    final cubit = context.read<ContentCubit>();
    if (cubit.state is ContentLoaded) {
      for (final item in (cubit.state as ContentLoaded).items) {
        if (item.id.isNotEmpty) _courseVideoIds.add(item.id);
        if (item.videoId != null) _courseVideoIds.add(item.videoId!);
        if (item.videoProviderId != null) {
          _courseVideoProviderIds.add(item.videoProviderId!);
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      if (mounted) {
        setState(() => _isLoadingLibrary = false);
      }
      // Immediately prefetch all folder videos in parallel in the background!
      // This ensures expanding any folder is 0ms instant without any network lag!
      if (_allFolders.isNotEmpty) {
        unawaited(
          Future.wait(
            _allFolders.map((f) async {
              final res = await _videoRepo.getVideos(folderId: f.id);
              if (res.isSuccess) {
                _folderVideosCache[f.id] = res.data;
              }
            }),
          ).then((_) {
            if (mounted) setState(() {});
          }),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingLibrary = false);
      }
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
    if (_courseVideoIds.contains(video.id) ||
        (video.providerVideoId != null &&
            _courseVideoProviderIds.contains(video.providerVideoId))) {
      return true;
    }
    for (final name in video.assignedGroupNames) {
      if (name.trim().toLowerCase() == widget.groupName.trim().toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  void _toggleVideoSelection(LibraryVideoEntity video) {
    setState(() {
      if (_selectedVideos.containsKey(video.id)) {
        _selectedVideos.remove(video.id);
        _stagedLectures.remove(video.id)?.dispose();
        _stagedOrder.remove(video.id);
        if (_inspectingLecture?.video.id == video.id) {
          _inspectingLecture = null;
        }
      } else {
        _selectedVideos[video.id] = video;
        _stagedOrder.add(video.id);

        // Pre-fill existing configuration if video is already part of this course
        String initialTitle = video.title;
        String? initialChapter = _batchGlobalChapterId ?? widget.initialChapterId;
        bool isPublished = _batchGlobalPublished;
        LibraryMaterialEntity? initialMaterial;
        List<_StudioAttachedExam>? initialExams;

        final cubit = context.read<ContentCubit>();
        if (cubit.state is ContentLoaded) {
          final items = (cubit.state as ContentLoaded).items;
          final existing = items.where(
            (item) =>
                item.id == video.id ||
                item.videoId == video.id ||
                item.videoProviderId == video.providerVideoId,
          ).firstOrNull;
          if (existing != null) {
            initialTitle = existing.title;
            isPublished = existing.isPublishedInGroup;
            if (existing.chapterId != null) {
              initialChapter = existing.chapterId;
            }
            if (existing.attachedExams.isNotEmpty) {
              initialExams = existing.attachedExams.map(
                (e) => _StudioAttachedExam(
                  examId: e.examId,
                  examTitle: e.examTitle,
                  isRequired: e.isRequired,
                ),
              ).toList();
            }
            if (existing.file != null) {
              final f = existing.file!;
              initialMaterial = LibraryMaterialEntity(
                id: f.id,
                tenantId: f.tenantId,
                title: f.fileName.replaceAll(
                  RegExp(r'\.pdf$', caseSensitive: false),
                  '',
                ),
                fileName: f.fileName,
                storagePath: f.storagePath,
                fileSize: f.fileSize,
                mimeType: f.mimeType,
                storageProvider: f.storageProvider,
                createdAt: f.createdAt,
                updatedAt: f.createdAt,
              );
            }
          }
        }

        _stagedLectures[video.id] = _StagedLecture(
          video: video,
          initialTitle: initialTitle,
          chapterId: initialChapter,
          isPublished: isPublished,
          initialExams: initialExams,
          libraryMaterial: initialMaterial,
        );
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
          _stagedOrder.remove(v.id);
          if (_inspectingLecture?.video.id == v.id) {
            _inspectingLecture = null;
          }
        }
      } else {
        // Select all in folder
        for (final v in videos) {
          if (!_selectedVideos.containsKey(v.id)) {
            _selectedVideos[v.id] = v;
            _stagedOrder.add(v.id);
            _stagedLectures[v.id] = _StagedLecture(
              video: v,
              initialTitle: v.title,
              chapterId: _batchGlobalChapterId ?? widget.initialChapterId,
              isPublished: _batchGlobalPublished,
            );
          }
        }
      }
    });
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _stagedOrder.removeAt(oldIndex);
      _stagedOrder.insert(newIndex, item);
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

  Future<void> _pickPdf(_StagedLecture staged) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        staged.pdfFile = result.files.first;
        staged.pdfBytes = result.files.first.bytes;
        staged.libraryMaterial = null;
      });
    }
  }

  Future<void> _pickFromLibrary(_StagedLecture staged) async {
    final selected = await SelectMaterialFromLibraryDialog.show(context);
    if (selected != null && mounted) {
      setState(() {
        staged.libraryMaterial = selected;
        staged.pdfFile = null;
        staged.pdfBytes = null;
      });
    }
  }

  Future<String?> _resolveOrUploadFileForLecture({
    required String contentId,
    required String tenantId,
    LibraryMaterialEntity? libraryMaterial,
    PlatformFile? uploadedFile,
    Uint8List? uploadedBytes,
  }) async {
    // 1. If chosen from materials library: link directly without re-uploading
    if (libraryMaterial != null) {
      final linkRes = await InjectionContainer.materialsLibraryRepository.linkToLecture(
        libraryMaterialId: libraryMaterial.id,
        contentId: contentId,
        tenantId: tenantId,
      );
      if (linkRes.isSuccess && linkRes.dataOrNull != null) {
        return linkRes.dataOrNull;
      }
    }

    // 2. If uploaded from device: upload to teacher's Materials Library first so it is preserved!
    if (uploadedFile != null && uploadedBytes != null) {
      final cleanTitle = uploadedFile.name.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );

      final uploadRes = await InjectionContainer.materialsLibraryRepository.uploadMaterial(
        title: cleanTitle,
        fileName: uploadedFile.name,
        fileBytes: uploadedBytes,
        mimeType: 'application/pdf',
      );

      if (uploadRes.isSuccess && uploadRes.dataOrNull != null) {
        final newMaterial = uploadRes.dataOrNull!;
        final linkRes = await InjectionContainer.materialsLibraryRepository.linkToLecture(
          libraryMaterialId: newMaterial.id,
          contentId: contentId,
          tenantId: tenantId,
        );
        if (linkRes.isSuccess && linkRes.dataOrNull != null) {
          return linkRes.dataOrNull;
        }
      }

      // Fallback: direct storage upload if library upload fails
      return await _uploadPdfForVideo(
        tenantId: tenantId,
        contentId: contentId,
        file: uploadedFile,
        bytes: uploadedBytes,
      );
    }

    return null;
  }

  Future<String?> _uploadPdfForVideo({
    required String tenantId,
    required String contentId,
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
      tenantId: tenantId,
      contentId: contentId,
      fileName: file.name,
      mimeType: 'application/pdf',
      fileBytes: bytes,
      storagePath: storagePath,
    );
  }

  Future<void> _handleSaveUnified() async {
    final list = _stagedOrder.map((id) => _stagedLectures[id]!).toList();
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
        final title = staged.titleController.text.trim().isNotEmpty
            ? staged.titleController.text.trim()
            : staged.video.title;

        // 1. Resolve or create true content_id before file linking
        final actualContentId = await cubit.resolveOrCreateLectureContent(
          videoId: staged.video.id,
          groupId: widget.groupId,
          title: title,
          tenantId: staged.video.tenantId,
        ) ?? staged.video.id;

        // 2. Upload / link file using the true actualContentId
        final fileId = await _resolveOrUploadFileForLecture(
          contentId: actualContentId,
          tenantId: staged.video.tenantId,
          libraryMaterial: staged.libraryMaterial,
          uploadedFile: staged.pdfFile,
          uploadedBytes: staged.pdfBytes,
        );

        final chapter = staged.chapterId ??
            _batchGlobalChapterId ??
            widget.initialChapterId;

        items.add({
          'content_id': actualContentId,
          'custom_title': title,
          if (chapter != null) 'chapter_id': chapter,
          'is_published': staged.isPublished,
          if (staged.attachedExams.isNotEmpty)
            'associated_exam_id': staged.attachedExams.first.examId,
          if (staged.attachedExams.isNotEmpty)
            'attached_exams': staged.attachedExams
                .asMap()
                .entries
                .map((e) => e.value.toJson(sortOrder: e.key))
                .toList(),
          if (staged.attachedExams.isEmpty) 'associated_exam_id': null,
          if (staged.attachedExams.isEmpty)
            'attached_exams': <Map<String, dynamic>>[],
          if (fileId != null) 'file_id': fileId,
        });
      }

      final success = await cubit.assignBatchContentToGroup(
        groupId: widget.groupId,
        items: items,
      );

      if (success && mounted) {
        for (final staged in list) {
          if (staged.isPublished) {
            final title = staged.titleController.text.trim().isNotEmpty
                ? staged.titleController.text.trim()
                : staged.video.title;
            unawaited(
              NotificationDispatcher.notifyNewLecture(
                title: title,
                groupId: widget.groupId,
                contentId: staged.video.id,
                contentType: 'video',
              ),
            );
          }
        }
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              list.length == 1
                  ? l10n.contentUpdatedToast
                  : l10n.batchAddSuccessToast(list.length),
            ),
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
                    onPressed: _selectedVideos.isEmpty ? null : _handleSaveUnified,
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
    final staged = _stagedLectures[video.id];
    final hasPdf = staged != null && staged.hasPdf;
    final hasExam = staged != null && staged.hasExam;

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
                  Row(
                    children: [
                      if (isAlreadyAdded) ...[
                        Text(
                          context.l10n.alreadyAddedBadge,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (hasPdf) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFEA580C).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 9,
                                color: Color(0xFFEA580C),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                context.l10n.smartBadgePdf,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if (hasExam) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.quiz_rounded,
                                size: 9,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                context.l10n.smartBadgeExam,
                                style: const TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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
    if (_stagedOrder.isEmpty) {
      return _buildNoVideosPlaceholder(context);
    }
    return _buildUnifiedStagingDeck(context);
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

  // ── Unified Staging Deck ────────────────────────────────────────────────
  Widget _buildUnifiedStagingDeck(BuildContext context) {
    final l10n = context.l10n;
    final chapters = _getEffectiveChapters(context);
    final count = _stagedOrder.length;

    return Column(
      children: [
        // Global Toolbar & Header
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
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
                      Icons.video_library_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              count == 1
                                  ? l10n.lessonStudioTitle
                                  : l10n.batchModeTitle(count),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                count == 1
                                    ? l10n.singleVideoModeBadge
                                    : l10n.selectedVideosBadge(count),
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
                          count > 1
                              ? l10n.reorderLecturesHint
                              : l10n.lessonStudioSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Clear all selections
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final s in _stagedLectures.values) {
                          s.dispose();
                        }
                        _stagedLectures.clear();
                        _stagedOrder.clear();
                        _selectedVideos.clear();
                      });
                    },
                    icon: const Icon(Icons.clear_all_rounded, size: 16),
                    label: Text(l10n.clearSelection),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s14),

              // Global Batch Assignment Bar (Chapter & Publish)
              Row(
                children: [
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
                              labelText: count > 1
                                  ? l10n.applyChapterToAll
                                  : l10n.targetChapterLabel,
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
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
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
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          maxWidth: 200,
                                        ),
                                        child: Text(
                                          ch.title,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _batchGlobalChapterId = val;
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
                      mainAxisSize: MainAxisSize.min,
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
                              for (final s in _stagedLectures.values) {
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

        // Staging List with Drag & Drop Reordering
        Expanded(
          child: count == 1
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: _buildUnifiedLectureCard(
                        context,
                        _stagedLectures[_stagedOrder.first]!,
                        0,
                        chapters,
                        isOnlyOne: true,
                      ),
                    ),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  itemCount: _stagedOrder.length,
                  onReorder: _onReorder,
                  itemBuilder: (ctx, index) {
                    final videoId = _stagedOrder[index];
                    final staged = _stagedLectures[videoId];
                    if (staged == null) {
                      return SizedBox.shrink(key: ValueKey('empty_$videoId'));
                    }
                    return KeyedSubtree(
                      key: ValueKey(videoId),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s12),
                        child: _buildUnifiedLectureCard(
                          ctx,
                          staged,
                          index,
                          chapters,
                          isOnlyOne: false,
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Bottom Unified Action Bar
        Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Text(
                count == 1
                    ? l10n.singleVideoModeBadge
                    : l10n.selectedVideosBadge(count),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              AppButton(
                text: count == 1
                    ? l10n.saveLectureButton
                    : l10n.addBatchLecturesButton(count),
                icon: count == 1 ? Icons.save_rounded : Icons.rocket_launch_rounded,
                isLoading: _isSaving,
                onPressed: _handleSaveUnified,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Unified Lecture Card (Single & Multi Mode) ───────────────────────────
  Widget _buildUnifiedLectureCard(
    BuildContext context,
    _StagedLecture staged,
    int index,
    List<ChapterEntity> chapters, {
    required bool isOnlyOne,
  }) {
    final l10n = context.l10n;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Drag handle, Index, Thumbnail, Editable Title, Duration badge, Close
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!isOnlyOne) ...[
                  ReorderableDragStartListener(
                    index: index,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                ],

                // Thumbnail
                Container(
                  width: 72,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                    image: staged.video.thumbnailUrl != null
                        ? DecorationImage(
                            image: NetworkImage(staged.video.thumbnailUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 20,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),

                // Editable Title Field
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: staged.titleController,
                              labelText: l10n.lessonTitleLabel,
                              hintText: staged.video.title,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Duration badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              staged.video.formattedDuration,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),

                // Remove video button
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: AppColors.error,
                  tooltip: l10n.cancel,
                  onPressed: () => _toggleVideoSelection(staged.video),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.s12),

            // Row 2: Target Chapter, Quiz Section, PDF Handout, Publish Switch
            LayoutBuilder(
              builder: (ctx, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                return Wrap(
                  spacing: AppSpacing.s12,
                  runSpacing: AppSpacing.s10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // 1. Target Chapter Dropdown
                    SizedBox(
                      width: isNarrow ? double.infinity : 210,
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
                          fillColor: AppColors.surfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
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
                        onChanged: (val) =>
                            setState(() => staged.chapterId = val),
                      ),
                    ),

                    // 2. Quiz / Exam Section
                    SizedBox(
                      width: isNarrow ? double.infinity : 260,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (staged.attachedExams.isNotEmpty) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                for (int i = 0;
                                    i < staged.attachedExams.length;
                                    i++)
                                  InputChip(
                                    avatar: Icon(
                                      staged.attachedExams[i].isRequired
                                          ? Icons.lock_rounded
                                          : Icons.quiz_outlined,
                                      size: 13,
                                      color: AppColors.primary,
                                    ),
                                    label: Text(
                                      staged.attachedExams[i].examTitle.isNotEmpty
                                          ? staged.attachedExams[i].examTitle
                                          : 'اختبار #${i + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.close_rounded,
                                      size: 13,
                                    ),
                                    onDeleted: () {
                                      setState(() {
                                        staged.attachedExams.removeAt(i);
                                      });
                                    },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          Builder(
                            builder: (ctx) {
                              final unattached = _availableExams.where(
                                (e) => !staged.attachedExams.any(
                                  (a) => a.examId == e['id'],
                                ),
                              ).toList();

                              return DropdownButtonFormField<String?>(
                                value: null,
                                isDense: true,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.quiz_outlined,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  labelText: staged.attachedExams.isEmpty
                                      ? l10n.mandatoryQuizSection
                                      : '+ ${l10n.addQuizToLessonAction}',
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text(
                                      staged.attachedExams.isEmpty
                                          ? l10n.noQuizAttached
                                          : '+ ${l10n.addQuizToLessonAction}',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: staged.attachedExams.isEmpty
                                            ? AppColors.textMuted
                                            : AppColors.primary,
                                        fontWeight: staged.attachedExams.isEmpty
                                            ? FontWeight.normal
                                            : FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  ...unattached.map(
                                    (exam) => DropdownMenuItem<String?>(
                                      value: exam['id'] as String?,
                                      child: Text(
                                        exam['title'] as String? ?? '',
                                        style: const TextStyle(fontSize: 11.5),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    final match = _availableExams.firstWhere(
                                      (e) => e['id'] == val,
                                      orElse: () => {'title': ''},
                                    );
                                    setState(() {
                                      staged.attachedExams.add(
                                        _StudioAttachedExam(
                                          examId: val,
                                          examTitle:
                                              match['title'] as String? ?? '',
                                          isRequired: true,
                                        ),
                                      );
                                    });
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // 3. PDF Handout Section (Prominent Chip with Replace and Delete)
                    if (!staged.hasPdf)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickFromLibrary(staged),
                            icon: const Icon(
                              Icons.folder_shared_rounded,
                              size: 15,
                              color: Color(0xFFEA580C),
                            ),
                            label: Text(
                              l10n.selectFromMaterialsLibrary,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFEA580C),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: const Color(0xFFEA580C).withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          OutlinedButton.icon(
                            onPressed: () => _pickPdf(staged),
                            icon: const Icon(
                              Icons.upload_file_rounded,
                              size: 15,
                            ),
                            label: Text(
                              l10n.uploadFromDeviceAction,
                              style: const TextStyle(fontSize: 11.5),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMedium,
                          ),
                          border: Border.all(
                            color: const Color(0xFFEA580C).withValues(
                              alpha: 0.4,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 16,
                              color: Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    staged.pdfDisplayName,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFEA580C),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (staged.formattedPdfSize != null)
                                    Text(
                                      staged.formattedPdfSize!,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: const Color(
                                          0xFFEA580C,
                                        ).withValues(alpha: 0.8),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Quick Replace Menu
                            PopupMenuButton<String>(
                              tooltip: l10n.changeAction,
                              icon: const Icon(
                                Icons.swap_horiz_rounded,
                                size: 16,
                                color: Color(0xFFEA580C),
                              ),
                              onSelected: (val) {
                                if (val == 'library') {
                                  _pickFromLibrary(staged);
                                } else if (val == 'upload') {
                                  _pickPdf(staged);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'library',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.folder_shared_rounded,
                                        size: 16,
                                        color: Color(0xFFEA580C),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.selectFromMaterialsLibrary,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'upload',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.upload_file_rounded,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        l10n.uploadFromDeviceAction,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            // Remove Button
                            InkWell(
                              onTap: () => setState(() {
                                staged.libraryMaterial = null;
                                staged.pdfFile = null;
                                staged.pdfBytes = null;
                              }),
                              borderRadius: BorderRadius.circular(12),
                              child: const Padding(
                                padding: EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: Color(0xFFEA580C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 4. Publish Toggle Switch
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: staged.isPublished
                            ? AppColors.success.withValues(alpha: 0.08)
                            : AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
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
                            color: staged.isPublished
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            staged.isPublished
                                ? l10n.statusPublished
                                : l10n.statusDraft,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: staged.isPublished
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                          Switch(
                            value: staged.isPublished,
                            activeColor: AppColors.success,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) =>
                                setState(() => staged.isPublished = val),
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
