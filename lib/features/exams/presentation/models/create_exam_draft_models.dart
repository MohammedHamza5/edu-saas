import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../domain/entities/exam_entity.dart';

class CreateExamDraftOption {
  final TextEditingController controller;
  bool isCorrect;
  String? imageUrl;
  Map<String, dynamic>? imageMeta;

  CreateExamDraftOption({
    String text = '',
    this.isCorrect = false,
  }) : controller = TextEditingController(text: text);

  Map<String, dynamic> toJson() => {
        'text': controller.text,
        'isCorrect': isCorrect,
        'imageUrl': imageUrl,
        'imageMeta': imageMeta,
      };

  static CreateExamDraftOption fromJson(Map<String, dynamic> json) {
    final opt = CreateExamDraftOption(
      text: json['text'] as String? ?? '',
      isCorrect: json['isCorrect'] as bool? ?? false,
    );
    opt.imageUrl = json['imageUrl'] as String?;
    if (json['imageMeta'] is Map) {
      opt.imageMeta = Map<String, dynamic>.from(json['imageMeta'] as Map);
    }
    return opt;
  }

  void dispose() {
    controller.dispose();
  }
}

class CreateExamDraftQuestion {
  final TextEditingController textController;
  final TextEditingController pointsController;
  QuestionType type = QuestionType.multipleChoice;
  int points;
  bool trueFalseAnswer = true;
  late List<CreateExamDraftOption> options;
  String? imageUrl;
  Uint8List? localImageBytes;
  Map<String, dynamic>? imageMeta;
  Future<String>? uploadFuture;
  bool isUploadingImage = false;
  String? uploadError;
  String? contextId;
  bool isExpanded;

  CreateExamDraftQuestion({
    this.isExpanded = true,
    int initialPoints = 5,
    String initialText = '',
  })  : points = initialPoints,
        textController = TextEditingController(text: initialText),
        pointsController =
            TextEditingController(text: initialPoints.toString()) {
    options = [
      CreateExamDraftOption(isCorrect: true),
      CreateExamDraftOption(isCorrect: false),
      CreateExamDraftOption(isCorrect: false),
      CreateExamDraftOption(isCorrect: false),
    ];
  }

  Map<String, dynamic> toJson() => {
        'text': textController.text,
        'points': points,
        'type': type.name,
        'trueFalseAnswer': trueFalseAnswer,
        'imageUrl': imageUrl,
        'imageMeta': imageMeta,
        'contextId': contextId,
        'isExpanded': isExpanded,
        'options': options.map((o) => o.toJson()).toList(),
      };

  static CreateExamDraftQuestion fromJson(Map<String, dynamic> json) {
    final q = CreateExamDraftQuestion(
      isExpanded: json['isExpanded'] as bool? ?? false,
      initialPoints: json['points'] as int? ?? 5,
      initialText: json['text'] as String? ?? '',
    );
    q.type = QuestionType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => QuestionType.multipleChoice,
    );
    q.trueFalseAnswer = json['trueFalseAnswer'] as bool? ?? true;
    q.imageUrl = json['imageUrl'] as String?;
    if (json['imageMeta'] is Map) {
      q.imageMeta = Map<String, dynamic>.from(json['imageMeta'] as Map);
    }
    q.contextId = json['contextId'] as String?;
    final rawOptions = json['options'] as List?;
    if (rawOptions != null && rawOptions.isNotEmpty) {
      for (final opt in q.options) {
        opt.dispose();
      }
      q.options = rawOptions
          .map((o) => CreateExamDraftOption.fromJson(o as Map<String, dynamic>))
          .toList();
    }
    return q;
  }

  void dispose() {
    textController.dispose();
    pointsController.dispose();
    for (final opt in options) {
      opt.dispose();
    }
  }
}

/// Helper to serialize draft exam form states to persistent storage.
class CreateExamDraftSerializer {
  CreateExamDraftSerializer._();

  static Map<String, dynamic> serialize({
    required String title,
    required String duration,
    required String maxScore,
    required String passingScore,
    required String defaultPoints,
    required bool shuffle,
    required bool showResult,
    required bool allowRetake,
    required bool isPublished,
    required bool saveToQuestionBank,
    required String? pdfFileId,
    required String? pdfFileName,
    required int? pdfFileSize,
    required String? pdfStoragePath,
    required List<CreateExamDraftQuestion> questions,
  }) {
    return {
      'savedAt': DateTime.now().toIso8601String(),
      'title': title,
      'duration': duration,
      'maxScore': maxScore,
      'passingScore': passingScore,
      'defaultPoints': defaultPoints,
      'shuffle': shuffle,
      'showResult': showResult,
      'allowRetake': allowRetake,
      'isPublished': isPublished,
      'saveToQuestionBank': saveToQuestionBank,
      'pdfFileId': pdfFileId,
      'pdfFileName': pdfFileName,
      'pdfFileSize': pdfFileSize,
      'pdfStoragePath': pdfStoragePath,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  static CreateExamDraftValues deserialize(Map<String, dynamic> data) {
    List<CreateExamDraftQuestion>? questions;
    final rawQuestions = data['questions'] as List?;
    if (rawQuestions != null && rawQuestions.isNotEmpty) {
      questions = [];
      for (int i = 0; i < rawQuestions.length; i++) {
        final q = CreateExamDraftQuestion.fromJson(
          rawQuestions[i] as Map<String, dynamic>,
        );
        q.isExpanded = i == 0;
        questions.add(q);
      }
    }

    return CreateExamDraftValues(
      title: data['title'] as String?,
      duration: data['duration'] as String?,
      maxScore: data['maxScore'] as String?,
      passingScore: data['passingScore'] as String?,
      defaultPoints: data['defaultPoints'] as String?,
      shuffle: data['shuffle'] is bool ? data['shuffle'] as bool : null,
      showResult:
          data['showResult'] is bool ? data['showResult'] as bool : null,
      allowRetake:
          data['allowRetake'] is bool ? data['allowRetake'] as bool : null,
      isPublished:
          data['isPublished'] is bool ? data['isPublished'] as bool : null,
      saveToQuestionBank: data['saveToQuestionBank'] is bool
          ? data['saveToQuestionBank'] as bool
          : null,
      pdfFileId: data['pdfFileId'] as String?,
      pdfFileName: data['pdfFileName'] as String?,
      pdfFileSize: data['pdfFileSize'] as int?,
      pdfStoragePath: data['pdfStoragePath'] as String?,
      questions: questions,
    );
  }
}

/// Parsed draft values container.
class CreateExamDraftValues {
  final String? title;
  final String? duration;
  final String? maxScore;
  final String? passingScore;
  final String? defaultPoints;
  final bool? shuffle;
  final bool? showResult;
  final bool? allowRetake;
  final bool? isPublished;
  final bool? saveToQuestionBank;
  final String? pdfFileId;
  final String? pdfFileName;
  final int? pdfFileSize;
  final String? pdfStoragePath;
  final List<CreateExamDraftQuestion>? questions;

  const CreateExamDraftValues({
    this.title,
    this.duration,
    this.maxScore,
    this.passingScore,
    this.defaultPoints,
    this.shuffle,
    this.showResult,
    this.allowRetake,
    this.isPublished,
    this.saveToQuestionBank,
    this.pdfFileId,
    this.pdfFileName,
    this.pdfFileSize,
    this.pdfStoragePath,
    this.questions,
  });
}
