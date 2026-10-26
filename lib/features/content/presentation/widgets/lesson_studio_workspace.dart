import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../../videos/domain/entities/video_folder_entity.dart';
import '../../../videos/domain/repositories/video_bank_repository.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/library_material_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/select_material_from_library_dialog.dart';
import '../dialogs/quick_create_chapter_dialog.dart';
import '../models/lesson_studio_models.dart';
import '../utils/lesson_studio_save_coordinator.dart';
import 'lesson_studio_header.dart';
import 'lesson_studio_lecture_card.dart';
import 'lesson_studio_no_videos_placeholder.dart';
import 'lesson_studio_staging_deck.dart';
import 'lesson_studio_library_sidebar.dart';

typedef _StudioAttachedExam = StudioAttachedExam;
typedef _StagedLecture = StagedLecture;

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

  // Selection & Search State (Unified Single Source of Truth)
  final Map<String, LibraryVideoEntity> _selectedVideos = {};
  final Map<String, _StagedLecture> _stagedLectures = {};
  final List<String> _stagedOrder = [];
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
    for (final staged in _stagedLectures.values) {
      staged.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExams() async {
    try {
      final exams = await context
          .read<ContentCubit>()
          .getAvailableExamsSummary();
      if (mounted) {
        setState(() {
          _availableExams = exams;
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

  Future<void> _loadVideosForFolder(String? folderId) async {
    final loadingKey = folderId ?? '__root__';
    if (_folderVideosCache.containsKey(folderId) ||
        _loadingFolderIds.contains(loadingKey)) {
      return;
    }
    setState(() => _loadingFolderIds.add(loadingKey));
    try {
      final res = await _videoRepo.getVideos(folderId: folderId);
      if (res.isSuccess && mounted) {
        setState(() {
          _folderVideosCache[folderId] = res.data;
          _loadingFolderIds.remove(loadingKey);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFolderIds.remove(loadingKey));
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
        String? initialChapter =
            _batchGlobalChapterId ?? widget.initialChapterId;
        bool isPublished = _batchGlobalPublished;
        LibraryMaterialEntity? initialMaterial;
        List<_StudioAttachedExam>? initialExams;

        final cubit = context.read<ContentCubit>();
        if (cubit.state is ContentLoaded) {
          final items = (cubit.state as ContentLoaded).items;
          final existing = items
              .where(
                (item) =>
                    item.id == video.id ||
                    item.videoId == video.id ||
                    item.videoProviderId == video.providerVideoId,
              )
              .firstOrNull;
          if (existing != null) {
            initialTitle = existing.title;
            isPublished = existing.isPublishedInGroup;
            if (existing.chapterId != null) {
              initialChapter = existing.chapterId;
            }
            if (existing.attachedExams.isNotEmpty) {
              initialExams = existing.attachedExams
                  .map(
                    (e) => _StudioAttachedExam(
                      examId: e.examId,
                      examTitle: e.examTitle,
                      isRequired: e.isRequired,
                    ),
                  )
                  .toList();
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

  Future<void> _showQuickCreateChapterDialog(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final createdChapter = await QuickCreateChapterDialog.show(
      context,
      groupId: widget.groupId,
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
      final success = await LessonStudioSaveCoordinator.saveUnifiedBatch(
        cubit: cubit,
        groupId: widget.groupId,
        stagedLectures: list,
        batchGlobalChapterId: _batchGlobalChapterId,
        initialChapterId: widget.initialChapterId,
      );

      if (success && mounted) {
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
    final isDesktop = MediaQuery.of(context).size.width >= 960;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Studio Command Header ──────────────────────────────────
            LessonStudioHeader(
              groupName: widget.groupName,
              selectedVideosCount: _selectedVideos.length,
              isSaving: _isSaving,
              onCancel: widget.onCancel,
              onSave: _handleSaveUnified,
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
                    child: LessonStudioLibrarySidebar(
                      isCollapsed: _isSidebarCollapsed,
                      onToggleCollapse: () => setState(
                        () => _isSidebarCollapsed = !_isSidebarCollapsed,
                      ),
                      isLoadingLibrary: _isLoadingLibrary,
                      onRefreshLibrary: _loadLibraryData,
                      allFolders: _allFolders,
                      folderVideosCache: _folderVideosCache,
                      loadingFolderIds: _loadingFolderIds,
                      selectedVideos: _selectedVideos,
                      stagedLectures: _stagedLectures,
                      isVideoAlreadyInCourse: _isVideoAlreadyInCourse,
                      onLoadVideosForFolder: _loadVideosForFolder,
                      onToggleFolderSelection: _toggleFolderSelection,
                      onToggleVideoSelection: _toggleVideoSelection,
                      onClearSelection: () => setState(() {
                        _selectedVideos.clear();
                        for (final s in _stagedLectures.values) {
                          s.dispose();
                        }
                        _stagedLectures.clear();
                      }),
                    ),
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
  Widget _buildRightWorkspace(BuildContext context) {
    if (_stagedOrder.isEmpty) {
      return _buildNoVideosPlaceholder(context);
    }
    return _buildUnifiedStagingDeck(context);
  }

  // ── Placeholder when 0 videos selected ───────────────────────────────────
  Widget _buildNoVideosPlaceholder(BuildContext context) {
    return LessonStudioNoVideosPlaceholder(
      hasFolders: _allFolders.isNotEmpty,
      onSelectFirstFolder: () {
        if (_allFolders.isNotEmpty) {
          _toggleFolderSelection(_allFolders.first);
        }
      },
    );
  }

  // ── Unified Staging Deck ────────────────────────────────────────────────
  Widget _buildUnifiedStagingDeck(BuildContext context) {
    return LessonStudioStagingDeck(
      chapters: _getEffectiveChapters(context),
      stagedOrder: _stagedOrder,
      stagedLectures: _stagedLectures,
      batchGlobalChapterId: _batchGlobalChapterId,
      batchGlobalPublished: _batchGlobalPublished,
      isSaving: _isSaving,
      onClearSelection: () {
        setState(() {
          for (final s in _stagedLectures.values) {
            s.dispose();
          }
          _stagedLectures.clear();
          _stagedOrder.clear();
          _selectedVideos.clear();
        });
      },
      onBatchChapterChanged: (val) {
        setState(() {
          _batchGlobalChapterId = val;
          for (final s in _stagedLectures.values) {
            s.chapterId = val;
          }
        });
      },
      onQuickCreateChapter: () => _showQuickCreateChapterDialog(context),
      onBatchPublishChanged: (val) {
        setState(() {
          _batchGlobalPublished = val;
          for (final s in _stagedLectures.values) {
            s.isPublished = val;
          }
        });
      },
      onReorder: _onReorder,
      onSaveUnified: _handleSaveUnified,
      cardBuilder: (ctx, staged, index, isOnlyOne) => _buildUnifiedLectureCard(
        ctx,
        staged,
        index,
        _getEffectiveChapters(context),
        isOnlyOne: isOnlyOne,
      ),
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
    return LessonStudioLectureCard(
      staged: staged,
      index: index,
      chapters: chapters,
      isOnlyOne: isOnlyOne,
      availableExams: _availableExams,
      onRemoveVideo: () => _toggleVideoSelection(staged.video),
      onPickFromLibrary: () => _pickFromLibrary(staged),
      onPickPdf: () => _pickPdf(staged),
      onChapterChanged: (val) => setState(() => staged.chapterId = val),
      onPublishChanged: (val) => setState(() => staged.isPublished = val),
      onAddExam: (examId, examTitle) {
        setState(() {
          staged.attachedExams.add(
            StudioAttachedExam(
              examId: examId,
              examTitle: examTitle,
              isRequired: true,
            ),
          );
        });
      },
      onRemoveExam: (examIndex) {
        setState(() {
          staged.attachedExams.removeAt(examIndex);
        });
      },
      onRemovePdf: () {
        setState(() {
          staged.libraryMaterial = null;
          staged.pdfFile = null;
          staged.pdfBytes = null;
        });
      },
    );
  }
}
