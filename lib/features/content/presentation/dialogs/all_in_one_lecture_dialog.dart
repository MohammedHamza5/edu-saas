import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../../videos/presentation/dialogs/select_video_from_bank_dialog.dart';
import '../../domain/entities/library_material_entity.dart';
import '../widgets/all_in_one_basic_info_section.dart';
import '../widgets/inline_quiz_builder_section.dart';
import '../widgets/lecture_pdf_handout_section.dart';
import '../widgets/lecture_video_source_section.dart';
import 'all_in_one_lecture_orchestrator.dart';
import 'select_material_from_library_dialog.dart';

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
        final duplicate =
            await AllInOneLectureOrchestrator.checkHandoutDuplicate(file);

        if (duplicate != null && mounted) {
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

        setState(() {
          _selectedLibraryMaterial = null;
          _pickedHandoutFile = file;
          _handoutFileBytes = file.bytes;
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = context.l10n;

    final validationError = AllInOneLectureOrchestrator.validateSubmission(
      selectedSource: _selectedSource,
      youtubeUrl: _youtubeUrlController.text.trim(),
      selectedBankVideo: _selectedBankVideo,
      isQuizEnabled: _isQuizEnabled,
      questions: _questions,
      l10n: l10n,
    );

    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(validationError),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = l10n.creatingContent;
    });

    try {
      final passingScore =
          int.tryParse(_passingScoreController.text.trim()) ?? 60;

      final payload = AllInOneLecturePayload(
        groupId: widget.groupId,
        nextSortOrder: widget.nextSortOrder,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        selectedSource: _selectedSource,
        selectedBankVideo: _selectedBankVideo,
        youtubeUrl: _youtubeUrlController.text.trim(),
        pickedBunnyFile: _pickedBunnyFile,
        bunnyFileBytes: _bunnyFileBytes,
        selectedLibraryMaterial: _selectedLibraryMaterial,
        pickedHandoutFile: _pickedHandoutFile,
        handoutFileBytes: _handoutFileBytes,
        isQuizEnabled: _isQuizEnabled,
        questions: _questions,
        passingScore: passingScore,
      );

      await AllInOneLectureOrchestrator.createAndPublishLecture(
        payload: payload,
        l10n: l10n,
        onProgress: (msg) {
          if (mounted) setState(() => _loadingMessage = msg);
        },
      );

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
                    // Header
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

                    // Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.s24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Basic Info
                            AllInOneBasicInfoSection(
                              titleController: _titleController,
                              descriptionController: _descriptionController,
                            ),
                            const SizedBox(height: AppSpacing.s20),

                            // 2. Video Source
                            LectureVideoSourceSection(
                              selectedSource: _selectedSource,
                              onSourceChanged: (src) =>
                                  setState(() => _selectedSource = src),
                              selectedBankVideo: _selectedBankVideo,
                              onSelectFromBank: () async {
                                final picked =
                                    await SelectVideoFromBankDialog.show(
                                  context,
                                );
                                if (picked != null) {
                                  setState(() {
                                    _selectedBankVideo = picked;
                                    if (_titleController.text.trim().isEmpty) {
                                      _titleController.text = picked.title;
                                    }
                                    if (_descriptionController.text
                                            .trim()
                                            .isEmpty &&
                                        picked.description != null) {
                                      _descriptionController.text =
                                          picked.description!;
                                    }
                                  });
                                }
                              },
                              onChangeBankVideo: () async {
                                final picked =
                                    await SelectVideoFromBankDialog.show(
                                  context,
                                );
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
                              onPickFromMaterialsLibrary:
                                  _pickFromMaterialsLibrary,
                              onPickHandoutPdf: _pickHandoutPdf,
                              onClearLibraryMaterial: () => setState(
                                () => _selectedLibraryMaterial = null,
                              ),
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

                    // Footer
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
}
