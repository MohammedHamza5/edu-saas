import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../../videos/presentation/dialogs/select_video_from_bank_dialog.dart';
import 'package:crypto/crypto.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/library_material_entity.dart';
import 'select_material_from_library_dialog.dart';

import '../widgets/inline_quiz_builder_section.dart';
import '../widgets/lecture_pdf_handout_section.dart';
import '../widgets/lecture_video_source_section.dart';

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

  VideoSourceType _selectedSource = VideoSourceType.bank;
  LibraryVideoEntity? _selectedBankVideo;
  String? _extractedYouTubeId;

  // Bunny File
  PlatformFile? _pickedBunnyFile;
  Uint8List? _bunnyFileBytes;

  // Handout PDF (Library selection or Device upload)
  LibraryMaterialEntity? _selectedLibraryMaterial;
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

  Future<void> _pickFromMaterialsLibrary() async {
    final selected = await SelectMaterialFromLibraryDialog.show(context);
    if (selected != null && mounted) {
      setState(() {
        _selectedLibraryMaterial = selected;
        _pickedHandoutFile = null;
        _handoutFileBytes = null;
      });
    }
  }

  Future<void> _pickHandoutPdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (res != null && res.files.isNotEmpty) {
        final file = res.files.first;
        final bytes = file.bytes;

        if (bytes != null) {
          // 1. Calculate SHA-256 Hash for smart deduplication check
          final computedHash = sha256.convert(bytes).toString();

          // 2. Check if this exact file is already present in teacher's library
          final dupRes = await InjectionContainer.materialsLibraryRepository
              .checkDuplicate(
            fileHash: computedHash,
            fileName: file.name,
            fileSize: file.size,
          );

          final duplicate = dupRes.dataOrNull;
          if (duplicate != null && mounted) {
            // Smart deduplication: reuse existing library file directly!
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text(context.l10n.materialDuplicateNotice),
                duration: const Duration(seconds: 4),
              ),
            );
            setState(() {
              _selectedLibraryMaterial = duplicate;
              _pickedHandoutFile = null;
              _handoutFileBytes = null;
            });
            return;
          }
        }

        setState(() {
          _selectedLibraryMaterial = null;
          _pickedHandoutFile = file;
          _handoutFileBytes = bytes;
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

    if (_selectedSource == VideoSourceType.bank && _selectedBankVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(context.l10n.selectFromBank),
        ),
      );
      return;
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
      final contentRes = await InjectionContainer.contentRepository
          .createContent(
            groupId: widget.groupId,
            title: title,
            description: description.isNotEmpty ? description : null,
            type: hasVideo ? ContentType.video : ContentType.pdf,
            status: ContentStatus.published,
            sortOrder: widget.nextSortOrder,
          );

      if (!contentRes.isSuccess || contentRes.dataOrNull == null) {
        throw Exception(
          contentRes.failureOrNull?.message ?? 'Failed to create lecture',
        );
      }

      final content = contentRes.dataOrNull!;
      final contentId = content.id;

      // 2. Video linking
      if (_selectedSource == VideoSourceType.bank && _selectedBankVideo != null) {
        setState(() => _loadingMessage = context.l10n.savingChanges);
        final bankRes = await InjectionContainer.videoBankRepository
            .linkToLectureContent(
              libraryVideoId: _selectedBankVideo!.id,
              contentId: contentId,
              title: title,
            );
        if (!bankRes.isSuccess) {
          throw Exception(
            bankRes.failureOrNull?.message ?? 'Failed to link video from bank',
          );
        }
      } else if (_selectedSource == VideoSourceType.youtube) {
        setState(() => _loadingMessage = context.l10n.linkingYoutubeVideo);
        final yRes = await InjectionContainer.videosRepository.linkYouTubeVideo(
          contentId: contentId,
          youtubeUrl: _youtubeUrlController.text.trim(),
          title: title,
        );
        if (!yRes.isSuccess) {
          throw Exception(
            yRes.failureOrNull?.message ?? 'Failed to link YouTube video',
          );
        }
      } else if (_selectedSource == VideoSourceType.bunny &&
          _bunnyFileBytes != null) {
        setState(() => _loadingMessage = context.l10n.uploadingVideoNotice);
        final bRes = await InjectionContainer.videosRepository
            .createAndUploadVideo(
              contentId: contentId,
              title: title,
              videoBytes: _bunnyFileBytes!,
              fileName: _pickedBunnyFile?.name ?? 'video.mp4',
            );
        if (!bRes.isSuccess) {
          throw Exception(
            bRes.failureOrNull?.message ?? 'Failed to upload video',
          );
        }
      }

      // 3. PDF Handout Linking / Upload
      if (_selectedLibraryMaterial != null) {
        setState(() => _loadingMessage = context.l10n.savingChanges);
        final linkRes = await InjectionContainer.materialsLibraryRepository
            .linkToLecture(
          libraryMaterialId: _selectedLibraryMaterial!.id,
          contentId: contentId,
          tenantId: content.tenantId,
        );
        if (!linkRes.isSuccess) {
          throw Exception(
            linkRes.failureOrNull?.message ?? 'Failed to link handout from library',
          );
        }
      } else if (_pickedHandoutFile != null && _handoutFileBytes != null) {
        setState(() => _loadingMessage = context.l10n.uploadingMaterialNotice);
        final cleanTitle = _pickedHandoutFile!.name.replaceAll(
          RegExp(r'\.pdf$', caseSensitive: false),
          '',
        );

        final uploadRes = await InjectionContainer.materialsLibraryRepository
            .uploadMaterial(
          title: cleanTitle,
          fileName: _pickedHandoutFile!.name,
          fileBytes: _handoutFileBytes!,
          mimeType: 'application/pdf',
        );

        if (!uploadRes.isSuccess || uploadRes.dataOrNull == null) {
          throw Exception(
            uploadRes.failureOrNull?.message ?? 'Failed to upload handout',
          );
        }

        final uploadedMat = uploadRes.dataOrNull!;
        final linkRes = await InjectionContainer.materialsLibraryRepository
            .linkToLecture(
          libraryMaterialId: uploadedMat.id,
          contentId: contentId,
          tenantId: content.tenantId,
        );

        if (!linkRes.isSuccess) {
          throw Exception(
            linkRes.failureOrNull?.message ?? 'Failed to link uploaded handout',
          );
        }
      }

      // 4. Create and Link Inline Quiz
      if (_isQuizEnabled && _questions.isNotEmpty) {
        setState(() => _loadingMessage = context.l10n.creatingExam);

        final questionsPayload = <ExamQuestionEntity>[];
        for (int i = 0; i < _questions.length; i++) {
          final q = _questions[i];
          final pts = int.tryParse(q.pointsController.text.trim()) ?? 1;

          if (q.type == QuestionType.multipleChoice) {
            questionsPayload.add(
              ExamQuestionEntity(
                id: '',
                examVersionId: '',
                questionText: q.questionController.text.trim(),
                questionType: QuestionType.multipleChoice,
                points: pts,
                sortOrder: i + 1,
                options: [
                  QuestionOptionEntity(
                    id: '',
                    questionId: '',
                    optionText: q.optA.text.trim(),
                    sortOrder: 1,
                    isCorrect: q.correctIndex == 0,
                  ),
                  QuestionOptionEntity(
                    id: '',
                    questionId: '',
                    optionText: q.optB.text.trim(),
                    sortOrder: 2,
                    isCorrect: q.correctIndex == 1,
                  ),
                  QuestionOptionEntity(
                    id: '',
                    questionId: '',
                    optionText: q.optC.text.trim(),
                    sortOrder: 3,
                    isCorrect: q.correctIndex == 2,
                  ),
                  QuestionOptionEntity(
                    id: '',
                    questionId: '',
                    optionText: q.optD.text.trim(),
                    sortOrder: 4,
                    isCorrect: q.correctIndex == 3,
                  ),
                ],
              ),
            );
          } else {
            questionsPayload.add(
              ExamQuestionEntity(
                id: '',
                examVersionId: '',
                questionText: q.questionController.text.trim(),
                questionType: QuestionType.trueFalse,
                points: pts,
                sortOrder: i + 1,
                options: [
                  QuestionOptionEntity(
                    id: '',
                    questionId: '',
                    optionText: 'True',
                    sortOrder: 1,
                    isCorrect: q.isTrueCorrect,
                  ),
                  QuestionOptionEntity(
                    id: '',
                    questionId: '',
                    optionText: 'False',
                    sortOrder: 2,
                    isCorrect: !q.isTrueCorrect,
                  ),
                ],
              ),
            );
          }
        }

        final totalScore = questionsPayload.fold<int>(
          0,
          (sum, q) => sum + q.points,
        );
        final passingScore =
            int.tryParse(_passingScoreController.text.trim()) ?? 60;

        final examRes = await InjectionContainer.examsRepository.createExam(
          groupId: widget.groupId,
          title: '$title Quiz',
          durationMinutes: 30,
          maxScore: totalScore > 0 ? totalScore : 100,
          passingScore: passingScore,
          allowRetake: true,
          showResult: true,
          isPublished: true,
          initialQuestions: questionsPayload,
        );

        if (examRes.isSuccess && examRes.dataOrNull != null) {
          final examId = examRes.dataOrNull!.id;
          await InjectionContainer.contentRepository.linkLessonExam(
            contentId: contentId,
            examId: examId,
          );
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
    final media = MediaQuery.of(context);
    final adaptiveMaxHeight = math.min(850.0, media.size.height * 0.92);
    final adaptiveMaxWidth = math.min(820.0, media.size.width * 0.95);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: adaptiveMaxWidth,
          maxHeight: adaptiveMaxHeight,
        ),
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
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
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
                            LectureVideoSourceSection(
                              selectedSource: _selectedSource,
                              onSourceChanged: (src) =>
                                  setState(() => _selectedSource = src),
                              selectedBankVideo: _selectedBankVideo,
                              onSelectFromBank: () async {
                                final picked =
                                    await SelectVideoFromBankDialog.show(context);
                                if (picked != null) {
                                  setState(() {
                                    _selectedBankVideo = picked;
                                    if (_titleController.text.trim().isEmpty) {
                                      _titleController.text = picked.title;
                                    }
                                    if (_descriptionController.text.trim().isEmpty &&
                                        picked.description != null) {
                                      _descriptionController.text =
                                          picked.description!;
                                    }
                                  });
                                }
                              },
                              onChangeBankVideo: () async {
                                final picked =
                                    await SelectVideoFromBankDialog.show(context);
                                if (picked != null) {
                                  setState(() => _selectedBankVideo = picked);
                                }
                              },
                              youtubeUrlController: _youtubeUrlController,
                              extractedYouTubeId: _extractedYouTubeId,
                              onYouTubeUrlChanged: _onYouTubeUrlChanged,
                              pickedBunnyFile: _pickedBunnyFile,
                              onPickBunnyVideo: _pickBunnyVideo,
                            ),
                            const SizedBox(height: AppSpacing.s20),

                            // 3. PDF Handout
                            LecturePdfHandoutSection(
                              selectedLibraryMaterial: _selectedLibraryMaterial,
                              pickedHandoutFile: _pickedHandoutFile,
                              onPickFromMaterialsLibrary: _pickFromMaterialsLibrary,
                              onPickHandoutPdf: _pickHandoutPdf,
                              onClearLibraryMaterial: () =>
                                  setState(() => _selectedLibraryMaterial = null),
                              onClearPickedHandoutFile: () => setState(() {
                                _pickedHandoutFile = null;
                                _handoutFileBytes = null;
                              }),
                            ),
                            const SizedBox(height: AppSpacing.s20),

                            // 4. Inline Quiz Builder
                            InlineQuizBuilderSection(
                              isQuizEnabled: _isQuizEnabled,
                              onQuizEnabledChanged: (v) =>
                                  setState(() => _isQuizEnabled = v),
                              passingScoreController: _passingScoreController,
                              questions: _questions,
                              onAddMcq: () =>
                                  _addQuestion(QuestionType.multipleChoice),
                              onAddTrueFalse: () =>
                                  _addQuestion(QuestionType.trueFalse),
                              onRemoveQuestion: _removeQuestion,
                              onStateChanged: () => setState(() {}),
                            ),
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
                        border: Border(
                          top: BorderSide(color: AppColors.border),
                        ),
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
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                context.l10n.lectureDetailsSection,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
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
}
