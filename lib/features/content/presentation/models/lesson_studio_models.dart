import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../domain/entities/library_material_entity.dart';

/// Represents an exam attached to a staged lecture in the Lesson Studio.
class StudioAttachedExam {
  final String examId;
  String examTitle;
  bool isRequired;

  StudioAttachedExam({
    required this.examId,
    required this.examTitle,
    this.isRequired = true,
  });

  Map<String, dynamic> toJson({int sortOrder = 0}) => {
    'exam_id': examId,
    'sort_order': sortOrder,
    'is_required': isRequired,
  };
}

/// Represents a lecture being staged and configured before persistence in the Lesson Studio.
class StagedLecture {
  final LibraryVideoEntity video;
  final TextEditingController titleController;
  String? chapterId;
  PlatformFile? pdfFile;
  Uint8List? pdfBytes;
  LibraryMaterialEntity? libraryMaterial;
  bool isPublished;
  final List<StudioAttachedExam> attachedExams = [];
  int? customPassingScore;

  bool get hasPdf => libraryMaterial != null || pdfFile != null;
  String get pdfDisplayName =>
      libraryMaterial != null ? libraryMaterial!.title : (pdfFile?.name ?? '');
  int? get pdfSize =>
      libraryMaterial != null ? libraryMaterial!.fileSize : (pdfFile?.size);

  String? get formattedPdfSize {
    final size = pdfSize;
    if (size == null) return null;
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get hasExam => attachedExams.isNotEmpty;

  String? get examId =>
      attachedExams.isNotEmpty ? attachedExams.first.examId : null;
  set examId(String? id) {
    attachedExams.clear();
    if (id != null) {
      attachedExams.add(StudioAttachedExam(examId: id, examTitle: ''));
    }
  }

  StagedLecture({
    required this.video,
    required String initialTitle,
    this.chapterId,
    this.isPublished = true,
    List<StudioAttachedExam>? initialExams,
    this.libraryMaterial,
  }) : titleController = TextEditingController(text: initialTitle) {
    if (initialExams != null) {
      attachedExams.addAll(initialExams);
    }
  }

  void dispose() {
    titleController.dispose();
  }
}
