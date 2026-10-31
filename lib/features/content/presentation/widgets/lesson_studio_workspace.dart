import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../../videos/domain/entities/video_folder_entity.dart';
import '../../../videos/domain/repositories/video_bank_repository.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../models/lesson_studio_models.dart';
import '../utils/lesson_studio_data_loader.dart';
import '../utils/lesson_studio_prepopulator.dart';
import '../utils/lesson_studio_save_coordinator.dart';
import 'lesson_studio_deck_coordinator.dart';
import 'lesson_studio_header.dart';
import 'lesson_studio_library_sidebar.dart';
import 'lesson_studio_progress_overlay.dart';

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
  final Map<String, StagedLecture> _stagedLectures = {};
  final List<String> _stagedOrder = [];
  bool _isSidebarCollapsed = false;

  // Instant O(1) Video In Course Cache
  final Set<String> _courseVideoIds = {};
  final Set<String> _courseVideoProviderIds = {};

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
    _batchGlobalChapterId = widget.initialChapterId;
    _initCourseVideoSet();
    _loadLibraryData();
    _loadExams();
    _loadChapters();
  }

  void _initCourseVideoSet() {
    LessonStudioDataLoader.populateCourseVideoIds(
      context: context,
      courseVideoIds: _courseVideoIds,
      courseVideoProviderIds: _courseVideoProviderIds,
    );
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
      final initial =
          await LessonStudioDataLoader.loadInitialLibrary(_videoRepo);
      if (mounted) {
        setState(() {
          _allFolders = initial.folders;
          _folderVideosCache[null] = initial.rootVideos;
          _isLoadingLibrary = false;
        });
      }
      if (_allFolders.isNotEmpty) {
        unawaited(
          Future.wait(
            _allFolders.map((f) async {
              final videos = await LessonStudioDataLoader.loadVideosForFolder(
                repo: _videoRepo,
                folderId: f.id,
              );
              _folderVideosCache[f.id] = videos;
            }),
          ).then((_) {
            if (mounted) setState(() {});
          }),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLibrary = false);
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
      final videos = await LessonStudioDataLoader.loadVideosForFolder(
        repo: _videoRepo,
        folderId: folderId,
      );
      if (mounted) {
        setState(() {
          _folderVideosCache[folderId] = videos;
          _loadingFolderIds.remove(loadingKey);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFolderIds.remove(loadingKey));
    }
  }

  bool _isVideoAlreadyInCourse(LibraryVideoEntity video) {
    return LessonStudioDataLoader.isVideoAlreadyInCourse(
      video: video,
      groupName: widget.groupName,
      courseVideoIds: _courseVideoIds,
      courseVideoProviderIds: _courseVideoProviderIds,
    );
  }

  void _toggleVideoSelection(LibraryVideoEntity video) {
    setState(() {
      if (_selectedVideos.containsKey(video.id)) {
        _selectedVideos.remove(video.id);
        _stagedLectures.remove(video.id)?.dispose();
        _stagedOrder.remove(video.id);
      } else {
        _selectedVideos[video.id] = video;
        _stagedOrder.add(video.id);

        final cubit = context.read<ContentCubit>();
        final existingItems = cubit.state is ContentLoaded
            ? (cubit.state as ContentLoaded).items
            : <ContentEntity>[];

        _stagedLectures[video.id] = LessonStudioPrepopulator.createStagedLecture(
          video: video,
          existingItems: existingItems,
          defaultChapterId: _batchGlobalChapterId ?? widget.initialChapterId,
          defaultPublished: _batchGlobalPublished,
        );
      }
    });
  }

  void _toggleFolderSelection(VideoFolderEntity folder) {
    final videos = _folderVideosCache[folder.id] ?? [];
    setState(() {
      LessonStudioDataLoader.toggleFolderSelection(
        videos: videos,
        selectedVideos: _selectedVideos,
        stagedLectures: _stagedLectures,
        stagedOrder: _stagedOrder,
        batchGlobalChapterId: _batchGlobalChapterId ?? widget.initialChapterId,
        batchGlobalPublished: _batchGlobalPublished,
      );
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
    final createdChapter =
        await LessonStudioDataLoader.showQuickCreateChapterDialog(
      context,
      widget.groupId,
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
    }
  }

  Future<void> _pickPdf(StagedLecture staged) async {
    await LessonStudioDataLoader.pickPdf(staged);
    if (mounted) setState(() {});
  }

  Future<void> _pickFromLibrary(StagedLecture staged) async {
    await LessonStudioDataLoader.pickMaterialFromLibrary(context, staged);
    if (mounted) setState(() {});
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
    final isDesktop = MediaQuery.of(context).size.width >= 960;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Studio Command Header
            LessonStudioHeader(
              groupName: widget.groupName,
              selectedVideosCount: _selectedVideos.length,
              isSaving: _isSaving,
              onCancel: widget.onCancel,
              onSave: _handleSaveUnified,
            ),

            // Main Workspace Body: Split View
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Panel: Collapsible Video Bank Tree
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

                  // Right Panel: Lecture Staging / Configuration Deck
                  Expanded(
                    child: Container(
                      color: AppColors.background,
                      child: LessonStudioDeckCoordinator(
                        chapters: _getEffectiveChapters(context),
                        stagedOrder: _stagedOrder,
                        stagedLectures: _stagedLectures,
                        batchGlobalChapterId: _batchGlobalChapterId,
                        batchGlobalPublished: _batchGlobalPublished,
                        isSaving: _isSaving,
                        hasFolders: _allFolders.isNotEmpty,
                        availableExams: _availableExams,
                        onSelectFirstFolder: () {
                          if (_allFolders.isNotEmpty) {
                            _toggleFolderSelection(_allFolders.first);
                          }
                        },
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
                        onQuickCreateChapter: () =>
                            _showQuickCreateChapterDialog(context),
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
                        onRemoveVideo: (staged) =>
                            _toggleVideoSelection(staged.video),
                        onPickFromLibrary: _pickFromLibrary,
                        onPickPdf: _pickPdf,
                        onChapterChanged: (staged, val) =>
                            setState(() => staged.chapterId = val),
                        onPublishChanged: (staged, val) =>
                            setState(() => staged.isPublished = val),
                        onAddExam: (staged, examId, examTitle) {
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
                        onRemoveExam: (staged, examIndex) {
                          setState(() {
                            staged.attachedExams.removeAt(examIndex);
                          });
                        },
                        onRemovePdf: (staged) {
                          setState(() {
                            staged.libraryMaterial = null;
                            staged.pdfFile = null;
                            staged.pdfBytes = null;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // Progress Modal Overlay when saving
        LessonStudioProgressOverlay(
          isSaving: _isSaving,
          savingProgressMessage: _savingProgressMessage,
        ),
      ],
    );
  }
}
