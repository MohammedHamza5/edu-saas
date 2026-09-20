import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../exams/data/models/exam_question_model.dart';
import '../../../exams/data/models/question_option_model.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../domain/entities/content_entity.dart';

enum VideoSourceType { youtube, bunny, none }

class InlineQuizQuestionData {
  QuestionType type;
  final TextEditingController questionController = TextEditingController();
  final TextEditingController pointsController = TextEditingController(text: '1');

  // MCQ Options
  final TextEditingController optA = TextEditingController();
  final TextEditingController optB = TextEditingController();
  final TextEditingController optC = TextEditingController();
  final TextEditingController optD = TextEditingController();
  int correctIndex = 0; // 0: A, 1: B, 2: C, 3: D

  // True / False
  bool isTrueCorrect = true;

  InlineQuizQuestionData({this.type = QuestionType.multipleChoice});

  void dispose() {
    questionController.dispose();
    pointsController.dispose();
    optA.dispose();
    optB.dispose();
    optC.dispose();
    optD.dispose();
  }
}

class AllInOneLectureDialog extends StatefulWidget {
  final String groupId;
  final String? groupName;
  final int? nextSortOrder;

  const AllInOneLectureDialog({
    super.key,
    required this.groupId,
    this.groupName,
    this.nextSortOrder,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String groupId,
    String? groupName,
    int? nextSortOrder,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AllInOneLectureDialog(
        groupId: groupId,
        groupName: groupName,
        nextSortOrder: nextSortOrder,
      ),
    );
  }

  @override
  State<AllInOneLectureDialog> createState() => _AllInOneLectureDialogState();
}

class _AllInOneLectureDialogState extends State<AllInOneLectureDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _youtubeUrlController = TextEditingController();
  final _passingScoreController = TextEditingController(text: '60');

  VideoSourceType _selectedSource = VideoSourceType.youtube;
  String? _extractedYouTubeId;

  // Bunny File
  PlatformFile? _pickedBunnyFile;
  Uint8List? _bunnyFileBytes;

  // Handout PDF
  PlatformFile? _pickedHandoutFile;
  Uint8List? _handoutFileBytes;

  // Inline Quiz
  bool _isQuizEnabled = true;
  final List<InlineQuizQuestionData> _questions = [];

  bool _isLoading = false;
  String _loadingMessage = '';

  @override
  void initState() {
    super.initState();
    // Start with 1 default question
    _addQuestion(QuestionType.multipleChoice);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _youtubeUrlController.dispose();
    _passingScoreController.dispose();
    for (final q in _questions) {
      q.dispose();
    }
    super.dispose();
  }

  void _addQuestion(QuestionType type) {
    setState(() {
      _questions.add(InlineQuizQuestionData(type: type));
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _questions[index].dispose();
      _questions.removeAt(index);
    });
  }

  void _onYouTubeUrlChanged(String value) {
    setState(() {
      _extractedYouTubeId = YouTubeUrlParser.extractVideoId(value);
    });
  }

  Future<void> _pickBunnyVideo() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _pickedBunnyFile = res.files.first;
          _bunnyFileBytes = res.files.first.bytes;
          if (_titleController.text.trim().isEmpty) {
            final cleanName = res.files.first.name
                .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
                .replaceAll(RegExp(r'[_-]'), ' ')
                .trim();
            _titleController.text = cleanName;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickHandoutPdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        setState(() {
          _pickedHandoutFile = res.files.first;
          _handoutFileBytes = res.files.first.bytes;
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSource == VideoSourceType.youtube) {
      final url = _youtubeUrlController.text.trim();
      final id = YouTubeUrlParser.extractVideoId(url);
      if (id == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(context.l10n.invalidYoutubeUrl),
          ),
        );
        return;
      }
    }

    if (_isQuizEnabled) {
      if (_questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(context.l10n.quizRulesAtLeastOneQuestion),
          ),
        );
        return;
      }
      for (int i = 0; i < _questions.length; i++) {
        final q = _questions[i];
        if (q.questionController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(context.l10n.questionTextRequired),
            ),
          );
          return;
        }
        if (q.type == QuestionType.multipleChoice) {
          if (q.optA.text.trim().isEmpty ||
              q.optB.text.trim().isEmpty ||
              q.optC.text.trim().isEmpty ||
              q.optD.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.error,
                content: Text(context.l10n.fillAllOptionsNotice),
              ),
            );
            return;
          }
        }
      }
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = context.l10n.creatingContent;
    });

    try {
      final title = _titleController.text.trim();
      final description = _descriptionController.text.trim();
      final hasVideo = _selectedSource != VideoSourceType.none;

      // 1. Create content record
      final contentRes = await InjectionContainer.contentRepository.createContent(
        groupId: widget.groupId,
        title: title,
        description: description.isNotEmpty ? description : null,
        type: hasVideo ? ContentType.video : ContentType.pdf,
        status: ContentStatus.published,
        sortOrder: widget.nextSortOrder,
      );

      if (!contentRes.isSuccess || contentRes.dataOrNull == null) {
        throw Exception(contentRes.failureOrNull?.message ?? 'Failed to create lecture');
      }

      final content = contentRes.dataOrNull!;
      final contentId = content.id;

      // 2. Video linking
      if (_selectedSource == VideoSourceType.youtube) {
        setState(() => _loadingMessage = context.l10n.linkingYoutubeVideo);
        final yRes = await InjectionContainer.videosRepository.linkYouTubeVideo(
          contentId: contentId,
          youtubeUrl: _youtubeUrlController.text.trim(),
          title: title,
        );
        if (!yRes.isSuccess) {
          throw Exception(yRes.failureOrNull?.message ?? 'Failed to link YouTube video');
        }
      } else if (_selectedSource == VideoSourceType.bunny && _bunnyFileBytes != null) {
        setState(() => _loadingMessage = context.l10n.uploadingVideoNotice);
        final bRes = await InjectionContainer.videosRepository.createAndUploadVideo(
          contentId: contentId,
          title: title,
          videoBytes: _bunnyFileBytes!,
          fileName: _pickedBunnyFile?.name ?? 'video.mp4',
        );
        if (!bRes.isSuccess) {
          throw Exception(bRes.failureOrNull?.message ?? 'Failed to upload video');
        }
      }

      // 3. PDF Handout Upload
      if (_pickedHandoutFile != null && _handoutFileBytes != null) {
        setState(() => _loadingMessage = context.l10n.uploadingNotice);
        final safeName = _pickedHandoutFile!.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
        final storagePath = 'groups/${widget.groupId}/$contentId/$safeName';

        await SupabaseService.client.storage
            .from('group-content')
            .uploadBinary(
              storagePath,
              _handoutFileBytes!,
              fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
            );

        await SupabaseService.client.from('files').insert({
          'tenant_id': content.tenantId,
          'content_id': contentId,
          'storage_path': storagePath,
          'file_name': _pickedHandoutFile!.name,
          'mime_type': 'application/pdf',
          'file_size': _pickedHandoutFile!.size,
        });
      }

      // 4. Create and Link Inline Quiz
      if (_isQuizEnabled && _questions.isNotEmpty) {
        setState(() => _loadingMessage = context.l10n.creatingExam);

        final questionsPayload = <ExamQuestionModel>[];
        for (int i = 0; i < _questions.length; i++) {
          final q = _questions[i];
          final pts = int.tryParse(q.pointsController.text.trim()) ?? 1;

          if (q.type == QuestionType.multipleChoice) {
            questionsPayload.add(ExamQuestionModel(
              id: '',
              examVersionId: '',
              questionText: q.questionController.text.trim(),
              questionType: QuestionType.multipleChoice,
              points: pts,
              sortOrder: i + 1,
              options: [
                QuestionOptionModel(id: '', questionId: '', optionText: q.optA.text.trim(), sortOrder: 1, isCorrect: q.correctIndex == 0),
                QuestionOptionModel(id: '', questionId: '', optionText: q.optB.text.trim(), sortOrder: 2, isCorrect: q.correctIndex == 1),
                QuestionOptionModel(id: '', questionId: '', optionText: q.optC.text.trim(), sortOrder: 3, isCorrect: q.correctIndex == 2),
                QuestionOptionModel(id: '', questionId: '', optionText: q.optD.text.trim(), sortOrder: 4, isCorrect: q.correctIndex == 3),
              ],
            ));
          } else {
            questionsPayload.add(ExamQuestionModel(
              id: '',
              examVersionId: '',
              questionText: q.questionController.text.trim(),
              questionType: QuestionType.trueFalse,
              points: pts,
              sortOrder: i + 1,
              options: [
                QuestionOptionModel(id: '', questionId: '', optionText: 'True', sortOrder: 1, isCorrect: q.isTrueCorrect),
                QuestionOptionModel(id: '', questionId: '', optionText: 'False', sortOrder: 2, isCorrect: !q.isTrueCorrect),
              ],
            ));
          }
        }

        final totalScore = questionsPayload.fold<int>(0, (sum, q) => sum + q.points);
        final passingScore = int.tryParse(_passingScoreController.text.trim()) ?? 60;

        final examRes = await InjectionContainer.examsRepository.createExam(
          groupId: widget.groupId,
          title: '$title Quiz',
          durationMinutes: 30,
          maxScore: totalScore > 0 ? totalScore : 100,
          passingScore: passingScore,
          allowRetake: true,
          showResult: true,
          initialQuestions: questionsPayload,
        );

        if (examRes.isSuccess && examRes.dataOrNull != null) {
          final examId = examRes.dataOrNull!.id;
          await SupabaseService.client
              .from('content')
              .update({'associated_exam_id': examId})
              .eq('id', contentId);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 850),
        child: _isLoading
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.s32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const AppLoadingView.signature(),
                      const SizedBox(height: AppSpacing.s20),
                      Text(
                        _loadingMessage,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    // ── Header ─────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s24,
                        vertical: AppSpacing.s16,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(bottom: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                            ),
                            child: const Icon(
                              Icons.auto_stories_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.allInOneStudioTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  context.l10n.allInOneStudioSubtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            tooltip: context.l10n.cancelAction,
                            onPressed: () => Navigator.of(context).pop(false),
                          ),
                        ],
                      ),
                    ),

                    // ── Body ───────────────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.s24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Basic Info
                            _buildBasicInfoSection(),
                            const SizedBox(height: AppSpacing.s20),

                            // 2. Video Source
                            _buildVideoSourceSection(),
                            const SizedBox(height: AppSpacing.s20),

                            // 3. PDF Handout
                            _buildPdfHandoutSection(),
                            const SizedBox(height: AppSpacing.s20),

                            // 4. Inline Quiz Builder
                            _buildInlineQuizSection(),
                          ],
                        ),
                      ),
                    ),

                    // ── Footer ─────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s24,
                        vertical: AppSpacing.s16,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(context.l10n.cancelAction),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          AppButton(
                            text: context.l10n.publishAndApproveAction,
                            variant: AppButtonVariant.primary,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBasicInfoSection() {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s8),
              Text(
                context.l10n.lectureDetailsSection,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          AppTextField(
            controller: _titleController,
            label: context.l10n.lectureTitleLabel,
            hintText: context.l10n.lectureTitleHint,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return context.l10n.contentTitleRequired;
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.s12),
          AppTextField(
            controller: _descriptionController,
            label: context.l10n.lectureDescLabel,
            hintText: context.l10n.lectureDescHint,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildVideoSourceSection() {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s8),
              Text(
                context.l10n.videoSourceLabel,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          SegmentedButton<VideoSourceType>(
            segments: [
              ButtonSegment(
                value: VideoSourceType.youtube,
                label: Text(context.l10n.videoSourceYoutube),
                icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.red),
              ),
              ButtonSegment(
                value: VideoSourceType.bunny,
                label: Text(context.l10n.videoSourceBunny),
                icon: const Icon(Icons.cloud_upload_rounded, color: AppColors.primary),
              ),
              ButtonSegment(
                value: VideoSourceType.none,
                label: Text(context.l10n.videoSourceNone),
                icon: const Icon(Icons.block_rounded),
              ),
            ],
            selected: {_selectedSource},
            onSelectionChanged: (set) {
              setState(() => _selectedSource = set.first);
            },
          ),
          const SizedBox(height: AppSpacing.s16),

          if (_selectedSource == VideoSourceType.youtube) ...[
            AppTextField(
              controller: _youtubeUrlController,
              label: context.l10n.youtubeUrlLabel,
              hintText: context.l10n.youtubeUrlHint,
              onChanged: _onYouTubeUrlChanged,
              validator: (v) {
                if (_selectedSource == VideoSourceType.youtube) {
                  if (v == null || v.trim().isEmpty) {
                    return context.l10n.youtubeUrlRequired;
                  }
                }
                return null;
              },
            ),
            if (_extractedYouTubeId != null) ...[
              const SizedBox(height: AppSpacing.s12),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withAlpha(50),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CachedNetworkImage(
                        imageUrl: 'https://img.youtube.com/vi/$_extractedYouTubeId/hqdefault.jpg',
                        width: 100,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 100,
                          height: 56,
                          color: Colors.black12,
                          child: const Icon(Icons.broken_image, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YouTube Video ID Validated',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.success,
                            ),
                          ),
                          Text(
                            _extractedYouTubeId!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (_selectedSource == VideoSourceType.bunny) ...[
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_upload_outlined),
                  label: Text(_pickedBunnyFile != null
                      ? context.l10n.changeVideoFileAction
                      : context.l10n.selectVideoFileAction),
                  onPressed: _pickBunnyVideo,
                ),
                const SizedBox(width: AppSpacing.s12),
                if (_pickedBunnyFile != null)
                  Expanded(
                    child: Text(
                      '${_pickedBunnyFile!.name} (${(_pickedBunnyFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPdfHandoutSection() {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf_outlined, size: 18, color: Colors.redAccent),
              const SizedBox(width: AppSpacing.s8),
              Text(
                context.l10n.handoutAttachmentSection,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (_pickedHandoutFile == null) ...[
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file_rounded),
              label: Text(context.l10n.attachHandoutPdf),
              onPressed: _pickHandoutPdf,
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: Colors.red.withAlpha(40)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      '${_pickedHandoutFile!.name} (${(_pickedHandoutFile!.size / 1024).toStringAsFixed(1)} KB)',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      setState(() {
                        _pickedHandoutFile = null;
                        _handoutFileBytes = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInlineQuizSection() {
    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Switch
          Row(
            children: [
              const Icon(Icons.quiz_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  context.l10n.inlineQuizSection,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Switch(
                value: _isQuizEnabled,
                onChanged: (v) => setState(() => _isQuizEnabled = v),
              ),
            ],
          ),

          if (_isQuizEnabled) ...[
            const SizedBox(height: AppSpacing.s12),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(15),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.success.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_open_rounded, color: AppColors.success, size: 18),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      context.l10n.enableInlineQuiz,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s14),

            // Passing score percentage
            SizedBox(
              width: 250,
              child: AppTextField(
                controller: _passingScoreController,
                label: context.l10n.examPassingScoreLabel,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Questions list
            ..._questions.asMap().entries.map((entry) {
              final idx = entry.key;
              final q = entry.value;
              return _buildQuestionCard(idx, q);
            }),

            const SizedBox(height: AppSpacing.s12),
            // Add Question Actions
            Wrap(
              spacing: AppSpacing.s8,
              runSpacing: AppSpacing.s8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: Text(context.l10n.addMcqQuestionAction),
                  onPressed: () => _addQuestion(QuestionType.multipleChoice),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text(context.l10n.addTrueFalseQuestionAction),
                  onPressed: () => _addQuestion(QuestionType.trueFalse),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard(int index, InlineQuizQuestionData q) {
    final isMcq = q.type == QuestionType.multipleChoice;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withAlpha(30),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                isMcq ? context.l10n.questionTypeMcq : context.l10n.questionTypeTrueFalse,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              SizedBox(
                width: 70,
                child: AppTextField(
                  controller: q.pointsController,
                  label: context.l10n.questionPointsLabel,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              if (_questions.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  tooltip: context.l10n.removeQuestionTooltip,
                  onPressed: () => _removeQuestion(index),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          AppTextField(
            controller: q.questionController,
            label: context.l10n.questionTextLabel,
          ),
          const SizedBox(height: AppSpacing.s12),

          if (isMcq) ...[
            _buildMcqOptionRow(q, 0, 'A', q.optA),
            const SizedBox(height: AppSpacing.s8),
            _buildMcqOptionRow(q, 1, 'B', q.optB),
            const SizedBox(height: AppSpacing.s8),
            _buildMcqOptionRow(q, 2, 'C', q.optC),
            const SizedBox(height: AppSpacing.s8),
            _buildMcqOptionRow(q, 3, 'D', q.optD),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    value: true,
                    groupValue: q.isTrueCorrect,
                    title: Text(context.l10n.trueOptionLabel),
                    onChanged: (v) => setState(() => q.isTrueCorrect = v!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    value: false,
                    groupValue: q.isTrueCorrect,
                    title: Text(context.l10n.falseOptionLabel),
                    onChanged: (v) => setState(() => q.isTrueCorrect = v!),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMcqOptionRow(
    InlineQuizQuestionData q,
    int optionIndex,
    String letter,
    TextEditingController controller,
  ) {
    final isSelected = q.correctIndex == optionIndex;

    return Row(
      children: [
        Radio<int>(
          value: optionIndex,
          groupValue: q.correctIndex,
          onChanged: (v) {
            setState(() => q.correctIndex = v!);
          },
        ),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.success : AppColors.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: AppTextField(
            controller: controller,
            hintText: context.l10n.optionLabel(optionIndex + 1),
          ),
        ),
      ],
    );
  }
}
