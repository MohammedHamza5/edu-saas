import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../exams/domain/entities/exam_entity.dart';
import '../../../exams/presentation/cubit/exams_cubit.dart';
import '../../../exams/presentation/pages/create_exam_page.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/library_material_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../dialogs/select_material_from_library_dialog.dart';
import '../widgets/video_picker_sheet.dart';

/// Helper for video selection and quiz navigation inside the Lesson Editor.
class LessonEditorActionsHelper {
  LessonEditorActionsHelper._();

  /// Picks a PDF file from device storage.
  static Future<PlatformFile?> pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        return result.files.first;
      }
    } catch (_) {}
    return null;
  }

  /// Opens the modal dialog to pick a material from the library.
  static Future<LibraryMaterialEntity?> pickFromLibrary(
    BuildContext context,
  ) async {
    return await SelectMaterialFromLibraryDialog.show(context);
  }

  /// Opens the video bank picker sheet while pre-filtering already added videos.
  static Future<ContentEntity?> pickVideoFromBank({
    required BuildContext context,
    required String groupId,
    required String groupName,
    String? currentEditingLessonId,
  }) async {
    final Set<String> alreadyAddedIds = {};
    final Set<String> alreadyAddedTitles = {};

    try {
      final cubit = context.read<ContentCubit>();
      if (cubit.state is ContentLoaded) {
        final items = (cubit.state as ContentLoaded).items;
        for (final item in items) {
          if (item.id != currentEditingLessonId) {
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

    return await VideoPickerSheet.show(
      context,
      currentGroupId: groupId,
      currentGroupName: groupName,
      alreadyAddedVideoIds: alreadyAddedIds,
      alreadyAddedTitles: alreadyAddedTitles,
    );
  }

  /// Opens the Create Exam page configured as a gatekeeper quiz for this lesson.
  static Future<ExamEntity?> openCreateQuiz({
    required BuildContext context,
    required String groupId,
    required String groupName,
    required String lessonTitle,
  }) async {
    final initialQuizTitle =
        lessonTitle.isNotEmpty ? 'كويز: $lessonTitle' : null;

    return await Navigator.push<ExamEntity?>(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider<ExamsCubit>(
          create: (_) => ExamsCubit(
            repository: InjectionContainer.examsRepository,
          ),
          child: CreateExamPage(
            groupId: groupId,
            groupName: groupName,
            initialTitle: initialQuizTitle,
          ),
        ),
      ),
    );
  }
}
