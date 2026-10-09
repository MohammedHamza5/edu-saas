import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/chapter_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import 'video_picker_sheet.dart';
import '../../../exams/presentation/pages/create_exam_page.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../../exams/presentation/cubit/exams_cubit.dart';

/// Modern Dedicated Lesson Editor Workspace matching the Studio Card System.
///
/// Provides:
/// 1. Video Summary Card (thumbnail, duration, switch video).
/// 2. Lesson Title Card (customizable title with sync action).
/// 3. Target Academic Chapter Card (select chapter or quick-create new chapter).
/// 4. PDF Handout Attachment Card (view, upload, replace, remove).
/// 5. Gatekeeper Quiz Card (linked exam, quick instant quiz creator, passing score).
/// 6. Lecture Visibility Card (published vs draft switch).
/// 7. Bottom action buttons (Save changes with loading state, Cancel).
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
  bool _removePdf = false;

  // Quiz / Exam State
  String? _selectedExamId;
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
    _selectedExamId = widget.editingLesson?.associatedExamId;
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
      final client = SupabaseService.client;
      final res = await client
          .from('exams')
          .select('id, title, content:content!exams_content_id_fkey(title)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _availableExams = (res as List).map((e) {
            final contentMap = e['content'] as Map<String, dynamic>?;
            final title = e['title'] as String? ??
                contentMap?['title'] as String? ??
                'بدون عنوان';
            return {
              'id': e['id'],
              'title': title,
            };
          }).toList();
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
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            isPublished
                                ? l10n.chapterVisibilityPublished
                                : l10n.chapterVisibilityDraft,
                            style: TextStyle(
                              fontSize: 10,
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
          _removePdf = false;
        });
      }
    } catch (_) {}
  }

  Future<String?> _uploadPdfIfNeeded() async {
    if (_removePdf) return null;
    if (_pickedFile == null || _pickedFileBytes == null) return _currentFileId;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName = _pickedFile!.name.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_.-]'),
      '_',
    );
    final storagePath = 'groups/${widget.groupId}/${timestamp}_$safeName';

    final cubit = context.read<ContentCubit>();
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
            if (passingScore != null) 'passing_score_override': passingScore,
            if (passingScore == null) 'passing_score_override': null,
            'chapter_id': _selectedChapterId,
          },
        ],
      );

      if (success) {
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
    final theme = Theme.of(context);

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
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Row(
                    children: [
                      Container(
                        width: 90,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            size: 30,
                            color: AppColors.primary,
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
                                    _selectedVideo?.title ??
                                        l10n.lessonEditorSourceVideo,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: AppSpacing.s8,
                              runSpacing: AppSpacing.s4,
                              children: [
                                if (_selectedVideo != null)
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _titleController.text =
                                            _selectedVideo!.title;
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
                                TextButton.icon(
                                  onPressed: _pickVideoFromBank,
                                  icon: const Icon(
                                    Icons.change_circle_outlined,
                                    size: 14,
                                  ),
                                  label: Text(
                                    l10n.lessonEditorChangeVideo,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // ── 2. Lesson Title Card ──────────────────────────────────────
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
                        controller: _titleController,
                        hintText: l10n.lessonTitleHint,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // ── 3. Academic Chapter Selector Card ──────────────────────────
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
                      if (_isLoadingChapters)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        )
                      else
                        DropdownButtonFormField<String?>(
                          value: _chapters.any((c) => c.id == _selectedChapterId)
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
                            for (final ch in _chapters)
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
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // ── 4. PDF Handout Attachment Card ─────────────────────────────
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
                      if (!_removePdf &&
                          (_pickedFile != null || _currentFileName != null))
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
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pickedFile?.name ?? _currentFileName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (_pickedFile != null)
                                      Text(
                                        '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB (جديد)',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 18,
                                ),
                                tooltip: 'استبدال الملف',
                                onPressed: _pickPdf,
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.error,
                                ),
                                tooltip: l10n.deleteAction,
                                onPressed: () {
                                  setState(() {
                                    _removePdf = true;
                                    _pickedFile = null;
                                    _pickedFileBytes = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: _pickPdf,
                          icon: const Icon(
                            Icons.picture_as_pdf_rounded,
                            size: 16,
                          ),
                          label: Text(l10n.uploadPdfHandout),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(42),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // ── 5. Gatekeeper Quiz Card ────────────────────────────────────
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.gatekeeperQuizTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.gatekeeperQuizSubtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      if (_isLoadingExams)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      else if (_selectedExamId != null) ...[
                        Builder(
                          builder: (ctx) {
                            final selectedMap = _availableExams.firstWhere(
                              (e) => e['id'] == _selectedExamId,
                              orElse: () => {
                                'title': l10n.lessonEditorLessonQuiz,
                              },
                            );
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusSmall,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.quiz_rounded,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.s12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          selectedMap['title'] as String? ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          l10n.lessonEditorLessonQuiz,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.link_off_rounded,
                                      color: AppColors.error,
                                      size: 20,
                                    ),
                                    tooltip: l10n.unlinkQuizAction,
                                    onPressed: () =>
                                        setState(() => _selectedExamId = null),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                text: l10n.createInstantQuizAction,
                                icon: Icons.add_task_rounded,
                                onPressed: _openCreateQuiz,
                                variant: AppButtonVariant.primary,
                              ),
                            ),
                          ],
                        ),
                        if (_availableExams.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s12),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  l10n.selectExistingQuizAction,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          DropdownButtonFormField<String?>(
                            value: _selectedExamId,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: AppColors.background,
                              hintText: l10n.selectExistingQuizAction,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n.lessonEditorNoQuiz),
                              ),
                              ..._availableExams.map(
                                (e) => DropdownMenuItem(
                                  value: e['id'] as String,
                                  child: Text(e['title'] as String),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedExamId = val;
                                if (val != null) {
                                  _useCustomScore = true;
                                }
                              });
                            },
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.s16),

                      // Passing Score Configuration
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              l10n.lessonEditorPassingScoreReq,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Switch(
                            value: _useCustomScore,
                            onChanged: (val) =>
                                setState(() => _useCustomScore = val),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      if (_useCustomScore)
                        AppTextField(
                          controller: _customScoreController,
                          keyboardType: TextInputType.number,
                          label: l10n.lessonEditorCustomPassingScore,
                          suffixIcon: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('%', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          l10n.lessonEditorDefaultPassingScore(
                            widget.defaultPassingScore,
                          ),
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // ── 6. Lesson Visibility Card ──────────────────────────────────
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (_isPublished
                                  ? AppColors.success
                                  : AppColors.warning)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _isPublished
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          color: _isPublished
                              ? AppColors.success
                              : AppColors.warning,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.lessonStatusLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isPublished
                                  ? l10n.lessonStatusPublishedDesc
                                  : l10n.lessonStatusDraftDesc,
                              style: TextStyle(
                                fontSize: 11,
                                color: _isPublished
                                    ? AppColors.textSecondary
                                    : AppColors.warning,
                                fontWeight: _isPublished
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isPublished,
                        onChanged: (val) => setState(() => _isPublished = val),
                        activeColor: AppColors.success,
                      ),
                    ],
                  ),
                ),
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
