import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/utils/youtube_url_parser.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/library_material_entity.dart';
import '../widgets/inline_quiz_builder_section.dart';
import '../widgets/lecture_video_source_section.dart';

class AllInOneLecturePayload {
  final String groupId;
  final int? nextSortOrder;
  final String title;
  final String description;
  final VideoSourceType selectedSource;
  final LibraryVideoEntity? selectedBankVideo;
  final String youtubeUrl;
  final PlatformFile? pickedBunnyFile;
  final Uint8List? bunnyFileBytes;
  final LibraryMaterialEntity? selectedLibraryMaterial;
  final PlatformFile? pickedHandoutFile;
  final Uint8List? handoutFileBytes;
  final bool isQuizEnabled;
  final List<InlineQuizQuestionData> questions;
  final int passingScore;

  const AllInOneLecturePayload({
    required this.groupId,
    this.nextSortOrder,
    required this.title,
    required this.description,
    required this.selectedSource,
    this.selectedBankVideo,
    required this.youtubeUrl,
    this.pickedBunnyFile,
    this.bunnyFileBytes,
    this.selectedLibraryMaterial,
    this.pickedHandoutFile,
    this.handoutFileBytes,
    required this.isQuizEnabled,
    required this.questions,
    required this.passingScore,
  });
}

class AllInOneLectureOrchestrator {
  static String? validateSubmission({
    required VideoSourceType selectedSource,
    required String youtubeUrl,
    required LibraryVideoEntity? selectedBankVideo,
    required bool isQuizEnabled,
    required List<InlineQuizQuestionData> questions,
    required AppLocalizations l10n,
  }) {
    if (selectedSource == VideoSourceType.youtube) {
      final id = YouTubeUrlParser.extractVideoId(youtubeUrl);
      if (id == null) return l10n.invalidYoutubeUrl;
    }

    if (selectedSource == VideoSourceType.bank && selectedBankVideo == null) {
      return l10n.selectFromBank;
    }

    if (isQuizEnabled) {
      if (questions.isEmpty) return l10n.quizRulesAtLeastOneQuestion;

      for (int i = 0; i < questions.length; i++) {
        final q = questions[i];
        if (q.questionController.text.trim().isEmpty) {
          return l10n.questionTextRequired;
        }
        if (q.type == QuestionType.multipleChoice) {
          if (q.optA.text.trim().isEmpty ||
              q.optB.text.trim().isEmpty ||
              q.optC.text.trim().isEmpty ||
              q.optD.text.trim().isEmpty) {
            return l10n.fillAllOptionsNotice;
          }
        }
      }
    }

    return null;
  }

  static Future<LibraryMaterialEntity?> checkHandoutDuplicate(
    PlatformFile file,
  ) async {
    final bytes = file.bytes;
    if (bytes == null) return null;

    final computedHash = sha256.convert(bytes).toString();
    final dupRes = await InjectionContainer.materialsLibraryRepository
        .checkDuplicate(
      fileHash: computedHash,
      fileName: file.name,
      fileSize: file.size,
    );
    return dupRes.dataOrNull;
  }

  static Future<void> createAndPublishLecture({
    required AllInOneLecturePayload payload,
    required AppLocalizations l10n,
    required void Function(String message) onProgress,
  }) async {
    final title = payload.title.trim();
    final description = payload.description.trim();
    final hasVideo = payload.selectedSource != VideoSourceType.none;

    // 1. Create content record
    onProgress(l10n.creatingContent);
    final contentRes = await InjectionContainer.contentRepository.createContent(
      groupId: payload.groupId,
      title: title,
      description: description.isNotEmpty ? description : null,
      type: hasVideo ? ContentType.video : ContentType.pdf,
      status: ContentStatus.published,
      sortOrder: payload.nextSortOrder,
    );

    if (!contentRes.isSuccess || contentRes.dataOrNull == null) {
      throw Exception(
        contentRes.failureOrNull?.message ?? 'Failed to create lecture',
      );
    }

    final content = contentRes.dataOrNull!;
    final contentId = content.id;

    // 2. Video linking
    await _linkVideo(payload, contentId, title, l10n, onProgress);

    // 3. PDF Handout Linking / Upload
    await _linkHandout(payload, content, l10n, onProgress);

    // 4. Create and Link Inline Quiz
    await _createAndLinkQuiz(payload, title, contentId, l10n, onProgress);
  }

  static Future<void> _linkVideo(
    AllInOneLecturePayload payload,
    String contentId,
    String title,
    AppLocalizations l10n,
    void Function(String message) onProgress,
  ) async {
    if (payload.selectedSource == VideoSourceType.bank &&
        payload.selectedBankVideo != null) {
      onProgress(l10n.savingChanges);
      final bankRes = await InjectionContainer.videoBankRepository
          .linkToLectureContent(
            libraryVideoId: payload.selectedBankVideo!.id,
            contentId: contentId,
            title: title,
          );
      if (!bankRes.isSuccess) {
        throw Exception(
          bankRes.failureOrNull?.message ?? 'Failed to link video from bank',
        );
      }
    } else if (payload.selectedSource == VideoSourceType.youtube) {
      onProgress(l10n.linkingYoutubeVideo);
      final yRes = await InjectionContainer.videosRepository.linkYouTubeVideo(
        contentId: contentId,
        youtubeUrl: payload.youtubeUrl,
        title: title,
      );
      if (!yRes.isSuccess) {
        throw Exception(
          yRes.failureOrNull?.message ?? 'Failed to link YouTube video',
        );
      }
    } else if (payload.selectedSource == VideoSourceType.bunny &&
        payload.bunnyFileBytes != null) {
      onProgress(l10n.uploadingVideoNotice);
      final bRes = await InjectionContainer.videosRepository
          .createAndUploadVideo(
            contentId: contentId,
            title: title,
            videoBytes: payload.bunnyFileBytes!,
            fileName: payload.pickedBunnyFile?.name ?? 'video.mp4',
          );
      if (!bRes.isSuccess) {
        throw Exception(
          bRes.failureOrNull?.message ?? 'Failed to upload video',
        );
      }
    }
  }

  static Future<void> _linkHandout(
    AllInOneLecturePayload payload,
    ContentEntity content,
    AppLocalizations l10n,
    void Function(String message) onProgress,
  ) async {
    final contentId = content.id;

    if (payload.selectedLibraryMaterial != null) {
      onProgress(l10n.savingChanges);
      final linkRes = await InjectionContainer.materialsLibraryRepository
          .linkToLecture(
            libraryMaterialId: payload.selectedLibraryMaterial!.id,
            contentId: contentId,
            tenantId: content.tenantId,
          );
      if (!linkRes.isSuccess) {
        throw Exception(
          linkRes.failureOrNull?.message ??
              'Failed to link handout from library',
        );
      }
    } else if (payload.pickedHandoutFile != null &&
        payload.handoutFileBytes != null) {
      onProgress(l10n.uploadingMaterialNotice);
      final cleanTitle = payload.pickedHandoutFile!.name.replaceAll(
        RegExp(r'\.pdf$', caseSensitive: false),
        '',
      );

      final uploadRes = await InjectionContainer.materialsLibraryRepository
          .uploadMaterial(
            title: cleanTitle,
            fileName: payload.pickedHandoutFile!.name,
            fileBytes: payload.handoutFileBytes!,
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
  }

  static Future<void> _createAndLinkQuiz(
    AllInOneLecturePayload payload,
    String title,
    String contentId,
    AppLocalizations l10n,
    void Function(String message) onProgress,
  ) async {
    if (!payload.isQuizEnabled || payload.questions.isEmpty) return;

    onProgress(l10n.creatingExam);

    final questionsPayload = <ExamQuestionEntity>[];
    for (int i = 0; i < payload.questions.length; i++) {
      final q = payload.questions[i];
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

    final examRes = await InjectionContainer.examsRepository.createExam(
      groupId: payload.groupId,
      title: '$title Quiz',
      durationMinutes: 30,
      maxScore: totalScore > 0 ? totalScore : 100,
      passingScore: payload.passingScore,
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
}
