import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/library_material_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/quick_create_chapter_dialog.dart';
import '../dialogs/select_material_from_library_dialog.dart';
import 'lesson_editor_details_section.dart';
import 'video_picker_sheet.dart';
import '../../../exams/presentation/pages/create_exam_page.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../../exams/presentation/cubit/exams_cubit.dart';
import '../../../notifications/domain/services/notification_dispatcher.dart';
import 'lesson_editor_pdf_section.dart';
import 'lesson_editor_quiz_section.dart';
import 'lesson_editor_video_summary_card.dart';

/// Modern Dedicated Lesson Editor Workspace matching the Studio Card System.
///
/// Provides:
/// 1. Video Summary Card (thumbnail, duration, switch video).
/// 2. Lesson Title Card (customizable title with sync action).
/// 3. Target Academic Chapter Card (select chapter or quick-create new chapter).
/// 4. PDF Handout Attachment Card (view, upload, replace, remove).
/// 5. Gatekeeper Quiz Card (linked exam, quick instant quiz creator, passing score).
/// 6. Lecture Visibility Card (published vs draft switch).
typedef _AttachedExamItem = LessonEditorAttachedExam;

class LessonEditorPane extends StatefulWidget {
  final ContentEntity? editingLesson;
  final String groupId;
  final String groupName;
  final int defaultPassingScore;
  final VoidCallback onSaved;
  final VoidCallback onCancel;
  final VoidCallback? onOpenFullPage;
  final VoidCallback? onClose;

  const LessonEditorPane({
    super.key,
    required this.editingLesson,
    required this.groupId,
    required this.groupName,
    required this.defaultPassingScore,
    required this.onSaved,
    required this.onCancel,
    this.onOpenFullPage,
    this.onClose,
  });

  @override
  State<LessonEditorPane> createState() => _LessonEditorPaneState();
}

class _LessonEditorPaneState extends State<LessonEditorPane> {
  final ContentRepository _contentRepo = InjectionContainer.contentRepository;

  ContentEntity? _selectedVideo;
  late final TextEditingController _titleController;
  late final TextEditingController _customScoreController;

  // Chapter State
  String? _selectedChapterId;
  List<ChapterEntity> _chapters = [];
  bool _isLoadingChapters = true;

  // PDF Attachment State
  String? _currentFileId;
  String? _currentFileName;
  PlatformFile? _pickedFile;
  Uint8List? _pickedFileBytes;
  LibraryMaterialEntity? _selectedLibraryMaterial;
  bool _removePdf = false;

  // Quiz / Exam State
  List<_AttachedExamItem> _attachedExams = [];
  String? get _selectedExamId =>
      _attachedExams.isNotEmpty ? _attachedExams.first.examId : null;
  set _selectedExamId(String? id) {
    if (id == null) {
      _attachedExams.clear();
    } else {
      final match = _availableExams.firstWhere(
        (e) => e['id'] == id,
        orElse: () => {'title': ''},
      );
      _attachedExams = [
        _AttachedExamItem(
          examId: id,
          examTitle: (match['title'] as String?) ?? '',
          isRequired: true,
        ),
      ];
    }
  }
  List<Map<String, dynamic>> _availableExams = [];
  bool _isLoadingExams = true;

  // Passing Score & Visibility State
  bool _useCustomScore = false;
  bool _isSaving = false;
  bool _isPublished = true;

  @override
  void initState() {
    super.initState();
    _initFromProps();
  }

  @override
  void didUpdateWidget(covariant LessonEditorPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editingLesson?.id != widget.editingLesson?.id) {
      _initFromProps();
    }
  }

  void _initFromProps() {
    _titleController = TextEditingController(
      text: widget.editingLesson?.title ?? '',
    );
    _selectedVideo = widget.editingLesson;
    _selectedChapterId = widget.editingLesson?.chapterId;
    _currentFileId = widget.editingLesson?.file?.id;
    _currentFileName = widget.editingLesson?.file?.fileName;
    if (widget.editingLesson?.attachedExams != null &&
        widget.editingLesson!.attachedExams.isNotEmpty) {
      _attachedExams = widget.editingLesson!.attachedExams
          .map(
            (e) => _AttachedExamItem(
              examId: e.examId,
              examTitle: e.examTitle,
              isRequired: e.isRequired,
              passingScore: e.passingScore,
            ),
          )
          .toList();
    } else if (widget.editingLesson?.associatedExamId != null) {
      _attachedExams = [
        _AttachedExamItem(
          examId: widget.editingLesson!.associatedExamId!,
          examTitle: widget.editingLesson!.associatedExamTitle ?? '',
          isRequired: true,
        ),
      ];
    } else {
      _attachedExams = [];
    }
    _isPublished = widget.editingLesson?.isPublishedInGroup ?? true;

    _pickedFile = null;
    _pickedFileBytes = null;
    _removePdf = false;

    _useCustomScore = false;
    _customScoreController = TextEditingController(
      text: widget.defaultPassingScore.toString(),
    );

    _loadExams();
    _loadChapters();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customScoreController.dispose();
    super.dispose();
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoadingChapters = true);
    final cubit = context.read<ContentCubit>();
    try {
      final res = await _contentRepo.getGroupChapters(widget.groupId);
      if (res.isSuccess && mounted) {
        setState(() {
          _chapters = res.data;
          _isLoadingChapters = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback from cubit state if available
    try {
      if (cubit.state is ContentLoaded) {
        final loadedChapters = (cubit.state as ContentLoaded).chapters;
        if (mounted && loadedChapters.isNotEmpty) {
          setState(() {
            _chapters = loadedChapters;
            _isLoadingChapters = false;
          });
          return;
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoadingChapters = false);
  }

  Future<void> _loadExams() async {
    try {
      setState(() => _isLoadingExams = true);
      final result = await _contentRepo.getAvailableExamsSummary();
      final exams = result.when(
        onSuccess: (data) => data,
        onFailure: (_) => <Map<String, dynamic>>[],
      );

      if (mounted) {
        setState(() {
          _availableExams = exams;
          _isLoadingExams = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingExams = false);
    }
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
          _chapters.insert(0, createdChapter);
        }
        _selectedChapterId = createdChapter.id;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.contentUpdatedToast),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Future<void> _openCreateQuiz() async {
    final lessonTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : (_selectedVideo?.title ?? '');
    final initialQuizTitle =
        lessonTitle.isNotEmpty ? 'كويز: $lessonTitle' : null;

    final created = await Navigator.push<ExamEntity?>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider<ExamsCubit>(
          create: (_) => ExamsCubit(
            repository: InjectionContainer.examsRepository,
          ),
          child: CreateExamPage(
            groupId: widget.groupId,
            groupName: widget.groupName,
            initialTitle: initialQuizTitle,
          ),
        ),
      ),
    );
    if (created != null && mounted) {
      setState(() {
        _availableExams.add({
          'id': created.id,
          'title': created.title,
        });
        _selectedExamId = created.id;
        _useCustomScore = true;
      });
    }
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pickedFile = file;
          _pickedFileBytes = file.bytes;
          _selectedLibraryMaterial = null;
          _removePdf = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _pickFromLibrary() async {
    final selected = await SelectMaterialFromLibraryDialog.show(context);
    if (selected != null && mounted) {
      setState(() {
        _selectedLibraryMaterial = selected;
        _pickedFile = null;
        _pickedFileBytes = null;
        _removePdf = false;
      });
    }
  }

  Future<String?> _uploadPdfIfNeeded() async {
    if (_removePdf) return null;
    final cubit = context.read<ContentCubit>();

    // 1. If chosen from materials library: link directly without re-uploading
    if (_selectedLibraryMaterial != null && _selectedVideo != null) {
      final targetContentId = widget.editingLesson?.id ?? _selectedVideo!.id;
      final linkRes = await InjectionContainer.materialsLibraryRepository.linkToLecture(
        libraryMaterialId: _selectedLibraryMaterial!.id,
        contentId: targetContentId,
        tenantId: _selectedVideo!.tenantId,
      );
      if (linkRes.isSuccess && linkRes.dataOrNull != null) {
        return linkRes.dataOrNull;
      }
    }

    if (_pickedFile == null || _pickedFileBytes == null) return _currentFileId;

    // 2. If uploaded from device: upload to teacher's Materials Library first so it is preserved!
    if (_selectedVideo != null) {
      final cleanTitle = _pickedFile!.name.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );

      final uploadRes = await InjectionContainer.materialsLibraryRepository.uploadMaterial(
        title: cleanTitle,
        fileName: _pickedFile!.name,
        fileBytes: _pickedFileBytes!,
        mimeType: 'application/pdf',
      );

      if (uploadRes.isSuccess && uploadRes.dataOrNull != null) {
        final newMat = uploadRes.dataOrNull!;
        final targetContentId = widget.editingLesson?.id ?? _selectedVideo!.id;
        final linkRes = await InjectionContainer.materialsLibraryRepository.linkToLecture(
          libraryMaterialId: newMat.id,
          contentId: targetContentId,
          tenantId: _selectedVideo!.tenantId,
        );
        if (linkRes.isSuccess && linkRes.dataOrNull != null) {
          return linkRes.dataOrNull;
        }
      }
    }

    // Fallback: direct storage upload
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _pickedFile!.name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_.-]'),
      '_',
    );
    final storagePath = 'groups/${widget.groupId}/${timestamp}_$safeName';

    return await cubit.uploadAndCreateFileRecord(
      tenantId: _selectedVideo!.tenantId,
      contentId: _selectedVideo!.id,
      fileName: _pickedFile!.name,
      mimeType: 'application/pdf',
      fileBytes: _pickedFileBytes!,
      storagePath: storagePath,
    );
  }

  Future<void> _pickVideoFromBank() async {
    final Set<String> alreadyAddedIds = {};
    final Set<String> alreadyAddedTitles = {};
    try {
      final cubit = context.read<ContentCubit>();
      if (cubit.state is ContentLoaded) {
        final items = (cubit.state as ContentLoaded).items;
        for (final item in items) {
          if (item.id != widget.editingLesson?.id) {
            alreadyAddedIds.add(item.id);
            if (item.videoId != null) alreadyAddedIds.add(item.videoId!);
            if (item.videoProviderId != null) {
              alreadyAddedIds.add(item.videoProviderId!);
            }
            if (item.title.trim().isNotEmpty) {
              alreadyAddedTitles.add(item.title.trim().toLowerCase());
            }
          }
        }
      }
    } catch (_) {}

    final video = await VideoPickerSheet.show(
      context,
      currentGroupId: widget.groupId,
      currentGroupName: widget.groupName,
      alreadyAddedVideoIds: alreadyAddedIds,
      alreadyAddedTitles: alreadyAddedTitles,
    );
    if (video != null && mounted) {
      setState(() {
        _selectedVideo = video;
        if (_titleController.text.isEmpty) {
          _titleController.text = video.title;
        }
      });
    }
  }

  Future<void> _handleSave() async {
    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.lessonEditorErrorSelectVideo)),
      );
      return;
    }

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final fileId = await _uploadPdfIfNeeded();
      final passingScore = _useCustomScore
          ? (int.tryParse(_customScoreController.text.trim()) ??
                widget.defaultPassingScore)
          : null;

      final lessonTitle =
          _titleController.text.trim().isEmpty ||
              _titleController.text.trim() == _selectedVideo!.title
          ? null
          : _titleController.text.trim();

      if (!mounted) return;
      final cubit = context.read<ContentCubit>();

      int? targetSortOrder;
      if (widget.editingLesson != null) {
        targetSortOrder = widget.editingLesson!.sortOrder;
      } else {
        if (cubit.state is! ContentLoaded) {
          await cubit.loadGroupContent(widget.groupId);
        }
        if (cubit.state is ContentLoaded) {
          final currentItems = (cubit.state as ContentLoaded).items;
          if (currentItems.isNotEmpty) {
            final maxOrder = currentItems
                .map((e) => e.sortOrder)
                .fold<int>(0, (prev, elem) => elem > prev ? elem : prev);
            targetSortOrder = maxOrder + 1;
          } else {
            targetSortOrder = 0;
          }
        } else {
          targetSortOrder = 0;
        }
      }

      final success = await cubit.assignContentToGroups(
        contentId: _selectedVideo!.id,
        groupIds: [widget.groupId],
        groupConfigs: [
          {
            'group_id': widget.groupId,
            'is_published': _isPublished,
            'sort_order': targetSortOrder,
            if (lessonTitle != null) 'custom_title': lessonTitle,
            if (fileId != null) 'file_id': fileId,
            if (fileId == null && _removePdf) 'file_id': null,
            if (_selectedExamId != null) 'associated_exam_id': _selectedExamId,
            if (_selectedExamId == null) 'associated_exam_id': null,
            'attached_exams': _attachedExams.asMap().entries.map((entry) => {
              'exam_id': entry.value.examId,
              'sort_order': entry.key,
              'is_required': entry.value.isRequired,
            }).toList(),
            if (passingScore != null) 'passing_score_override': passingScore,
            if (passingScore == null) 'passing_score_override': null,
            'chapter_id': _selectedChapterId,
          },
        ],
      );

      if (success) {
        if (_isPublished) {
          unawaited(
            NotificationDispatcher.notifyNewLecture(
              title: lessonTitle ?? _selectedVideo!.title,
              groupId: widget.groupId,
              contentId: _selectedVideo!.id,
              contentType: 'video',
            ),
          );
        }
        widget.onSaved();
      } else if (mounted) {
        final errorMsg = cubit.state is ContentError
            ? (cubit.state as ContentError).message
            : context.l10n.lessonEditorErrorSaving;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.lessonEditorErrorSaving),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s24,
        vertical: AppSpacing.s20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. Video Summary Header Card ──────────────────────────────
              LessonEditorVideoSummaryCard(
                selectedVideo: _selectedVideo,
                onUseVideoTitle: () {
                  setState(() {
                    _titleController.text = _selectedVideo!.title;
                  });
                },
                onPickVideoFromBank: _pickVideoFromBank,
              ),
              const SizedBox(height: AppSpacing.s16),
              // ── 2 & 3. Lesson Title & Academic Chapter Cards ───────────────
              LessonEditorTitleAndChapterCard(
                titleController: _titleController,
                chapters: _chapters,
                selectedChapterId: _selectedChapterId,
                isLoadingChapters: _isLoadingChapters,
                onChapterChanged: (val) {
                  setState(() {
                    _selectedChapterId = val;
                  });
                },
                onQuickCreateChapter: () =>
                    _showQuickCreateChapterDialog(context),
              ),
              const SizedBox(height: AppSpacing.s16),

              // ── 4. PDF Handout Attachment Card ─────────────────────────────
              LessonEditorPdfSection(
                removePdf: _removePdf,
                selectedLibraryMaterial: _selectedLibraryMaterial,
                pickedFile: _pickedFile,
                currentFileName: _currentFileName,
                onPickFromLibrary: _pickFromLibrary,
                onPickPdf: _pickPdf,
                onRemoveLibraryMaterial: () {
                  setState(() {
                    _selectedLibraryMaterial = null;
                    _removePdf = true;
                  });
                },
                onRemovePickedFile: () {
                  setState(() {
                    _removePdf = true;
                    _pickedFile = null;
                    _pickedFileBytes = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.s16),

              // ── 5. Gatekeeper Quiz Card ────────────────────────────────────
              LessonEditorQuizSection(
                attachedExams: _attachedExams,
                isLoadingExams: _isLoadingExams,
                availableExams: _availableExams,
                onOpenCreateQuiz: _openCreateQuiz,
                onAddExistingExam: (val) {
                  final selected = _availableExams.firstWhere((e) => e['id'] == val);
                  setState(() {
                    _attachedExams.add(
                      _AttachedExamItem(
                        examId: val,
                        examTitle: selected['title'] as String,
                        isRequired: true,
                      ),
                    );
                    _useCustomScore = true;
                  });
                },
                onRemoveExam: (idx) => setState(() => _attachedExams.removeAt(idx)),
                onToggleRequirement: (idx) => setState(() => _attachedExams[idx].isRequired = !_attachedExams[idx].isRequired),
                useCustomScore: _useCustomScore,
                onToggleCustomScore: (val) => setState(() => _useCustomScore = val),
                customScoreController: _customScoreController,
                defaultPassingScore: widget.defaultPassingScore,
              ),
              const SizedBox(height: AppSpacing.s16),
              // ── 6. Lesson Visibility Card ──────────────────────────────────
              LessonEditorVisibilityCard(
                isPublished: _isPublished,
                onPublishChanged: (val) => setState(() => _isPublished = val),
              ),
              const SizedBox(height: AppSpacing.s24),

              // ── 7. Bottom Actions Row ──────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  AppButton(
                    text: l10n.save,
                    icon: Icons.check_rounded,
                    isLoading: _isSaving,
                    onPressed: _handleSave,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s32),
            ],
          ),
        ),
      ),
    );
  }
}

