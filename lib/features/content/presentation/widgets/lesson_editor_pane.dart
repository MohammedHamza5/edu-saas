import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/add_video_to_bank_dialog.dart';
import 'video_picker_sheet.dart';
import '../../../exams/presentation/pages/create_exam_page.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../../exams/presentation/cubit/exams_cubit.dart';
import '../../../../core/di/injection_container.dart';

/// The Right-side Pane for the Master-Detail Course Builder UX.
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
  ContentEntity? _selectedVideo;
  late final TextEditingController _titleController;
  late final TextEditingController _customScoreController;

  String? _currentFileId;
  String? _currentFileName;
  PlatformFile? _pickedFile;
  Uint8List? _pickedFileBytes;
  bool _removePdf = false;

  String? _selectedExamId;
  List<Map<String, dynamic>> _availableExams = [];
  bool _isLoadingExams = true;

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
    _currentFileId = widget.editingLesson?.file?.id;
    _currentFileName = widget.editingLesson?.file?.fileName;
    _selectedExamId = widget.editingLesson?.associatedExamId;
    _isPublished = widget.editingLesson?.isPublishedInGroup ?? true;

    _pickedFile = null;
    _pickedFileBytes = null;
    _removePdf = false;

    // We assume widget.editingLesson carries passingScore inside config, but
    // our entity doesn't map passingScoreOverride directly yet. We'll default.
    _useCustomScore = false;
    _customScoreController = TextEditingController(
      text: widget.defaultPassingScore.toString(),
    );

    _loadExams();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _customScoreController.dispose();
    super.dispose();
  }

  Future<void> _loadExams() async {
    try {
      setState(() => _isLoadingExams = true);
      final client = SupabaseService.client;
      final res = await client
          .from('exams')
          .select('id, title, content:content!exams_content_id_fkey(title)')
          // Fetch all exams for this tenant, so the teacher can reuse them across groups.
          // RLS automatically restricts this to the teacher's tenant.
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
    } catch (e) {
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

  Future<void> _pickVideoFromBank() async {
    final Set<String> alreadyAddedIds = {};
    final Set<String> alreadyAddedTitles = {};
    try {
      final cubit = context.read<ContentCubit>();
      if (cubit.state is ContentLoaded) {
        final items = (cubit.state as ContentLoaded).items;
        for (final item in items) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.editingLesson != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing
                        ? context.l10n.lessonEditorEditTitle
                        : context.l10n.lessonEditorAddTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isEditing && widget.onOpenFullPage != null) ...[
                  Tooltip(
                    message: context.l10n.openFullPage,
                    child: ElevatedButton.icon(
                      onPressed: widget.onOpenFullPage,
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: Text(
                        context.l10n.openFullPage,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: AppColors.primary,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                ],
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: widget.onClose ?? widget.onCancel,
                  tooltip: context.l10n.cancel,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Source Video Selection
                  Text(
                    context.l10n.lessonEditorSourceVideo,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  if (_selectedVideo != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.play_circle_fill_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedVideo!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (!isEditing)
                            IconButton(
                              icon: const Icon(
                                Icons.change_circle_outlined,
                                color: AppColors.primary,
                              ),
                              onPressed: _pickVideoFromBank,
                              tooltip: context.l10n.lessonEditorChangeVideo,
                            ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: context.l10n.lessonEditorSelectFromLibrary,
                            icon: Icons.video_library_rounded,
                            onPressed: _pickVideoFromBank,
                            variant: AppButtonVariant.outlined,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: AppButton(
                            text: context.l10n.lessonEditorUploadNew,
                            icon: Icons.cloud_upload_rounded,
                            onPressed: () async {
                              await AddVideoToBankDialog.show(
                                context,
                                onCreated: (created) {
                                  if (!mounted) return;
                                  setState(() {
                                    _selectedVideo = created;
                                    _titleController.text = created.title;
                                  });
                                },
                              );
                            },
                            variant: AppButtonVariant.outlined,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s24),

                  // 2. Lesson Title
                  Text(
                    context.l10n.lessonEditorLessonTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  AppTextField(
                    controller: _titleController,
                    hintText:
                        _selectedVideo?.title ??
                        context.l10n.lessonEditorLessonTitleHint,
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  // 3. Attach PDF
                  Text(
                    context.l10n.lessonEditorStudyMaterial,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  if (!_removePdf &&
                      (_pickedFile != null || _currentFileName != null)) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pickedFile?.name ?? _currentFileName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.orange,
                            ),
                            onPressed: () => setState(() {
                              _removePdf = true;
                              _pickedFile = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    AppButton(
                      text: context.l10n.lessonEditorUploadPdf,
                      icon: Icons.upload_file_rounded,
                      onPressed: _pickPdf,
                      variant: AppButtonVariant.outlined,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s24),

                  // 4. Attach Gatekeeper Quiz
                  Text(
                    context.l10n.gatekeeperQuizTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    context.l10n.gatekeeperQuizSubtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  if (_isLoadingExams)
                    const Center(child: CircularProgressIndicator())
                  else if (_selectedExamId != null) ...[
                    // Quiz selected card
                    Builder(
                      builder: (ctx) {
                        final selectedMap = _availableExams.firstWhere(
                          (e) => e['id'] == _selectedExamId,
                          orElse: () => {
                            'title': context.l10n.lessonEditorLessonQuiz,
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
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                      context.l10n.lessonEditorLessonQuiz,
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
                                tooltip: context.l10n.unlinkQuizAction,
                                onPressed: () =>
                                    setState(() => _selectedExamId = null),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    // No quiz selected yet: options to create or pick
                    Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            text: context.l10n.createInstantQuizAction,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              context.l10n.selectExistingQuizAction,
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
                          hintText: context.l10n.selectExistingQuizAction,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(context.l10n.lessonEditorNoQuiz),
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
                  const SizedBox(height: AppSpacing.s24),

                  // 5. Passing Score
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.l10n.lessonEditorPassingScoreReq,
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
                      label: context.l10n.lessonEditorCustomPassingScore,
                      suffixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Text('%', style: TextStyle(fontSize: 16))],
                        ),
                      ),
                    )
                  else
                    Text(
                      context.l10n.lessonEditorDefaultPassingScore(
                        widget.defaultPassingScore,
                      ),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),

                  // 6. Lesson Visibility (Draft vs Published)
                  const SizedBox(height: AppSpacing.s24),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: _isPublished
                          ? AppColors.success.withValues(alpha: 0.05)
                          : AppColors.warning.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _isPublished
                            ? AppColors.success.withValues(alpha: 0.25)
                            : AppColors.warning.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isPublished
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 20,
                              color: _isPublished
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Expanded(
                              child: Text(
                                context.l10n.lessonStatusLabel,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Switch(
                              value: _isPublished,
                              onChanged: (val) =>
                                  setState(() => _isPublished = val),
                              activeColor: AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s4),
                        Text(
                          _isPublished
                              ? context.l10n.lessonStatusPublishedDesc
                              : context.l10n.lessonStatusDraftDesc,
                          style: theme.textTheme.bodySmall?.copyWith(
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
                ],
              ),
            ),
          ),

          // Footer
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(context.l10n.cancel),
                ),
                const SizedBox(width: AppSpacing.s8),
                AppButton(
                  text: context.l10n.save,
                  isLoading: _isSaving,
                  onPressed: _handleSave,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
