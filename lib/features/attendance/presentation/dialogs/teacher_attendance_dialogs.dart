import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/whatsapp_interactive_dialog.dart';
import '../../../../core/utils/whatsapp_report_generator.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/attendance_entity.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';

/// Helper dialogs and WhatsApp preview sheets for teacher attendance interactions.
abstract final class TeacherAttendanceDialogs {
  static void showNoteDialog(
    BuildContext context, {
    required StudentAttendanceItem student,
    required AttendanceCubit attendanceCubit,
  }) {
    final controller = TextEditingController(text: student.note ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            context.l10n.noteForStudentTitle(student.studentName),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: AppTextField(
            controller: controller,
            hintText: context.l10n.attendanceNoteHint,
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () async {
                final note = controller.text.trim();
                final successText = context.l10n.studentNoteSavedSuccess;
                Navigator.of(dialogCtx).pop();
                await attendanceCubit.updateStudentNote(
                  student.studentId,
                  note,
                );
                if (!context.mounted) return;
                AppFeedback.showSuccess(context, successText);
              },
              child: Text(
                context.l10n.save,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  static void showWhatsAppLectureNotice(
    BuildContext context, {
    required StudentAttendanceItem student,
    required TeacherAttendanceLoaded loadedState,
    required String? selectedGroupId,
  }) {
    final groupsState = context.read<GroupsCubit>().state;
    String? groupName;
    if (groupsState is GroupsLoaded) {
      final match = groupsState.groups.where((g) => g.id == selectedGroupId);
      if (match.isNotEmpty) {
        groupName = match.first.name;
      }
    }

    final activeLecture = loadedState.activeLecture;
    final lectureTitle = activeLecture != null
        ? activeLecture.title
        : (student.currentLectureTitle ?? context.l10n.allLecturesOverview);

    final reportText = WhatsAppReportGenerator.generateLectureWatchNotice(
      studentName: student.studentName,
      lectureTitle: lectureTitle,
      watchProgressPercent: student.watchProgressPercent,
      groupName: groupName,
      watchMinutes: student.watchSeconds > 0
          ? (student.watchSeconds / 60).round()
          : null,
      totalMinutes: student.totalDurationSeconds > 0
          ? (student.totalDurationSeconds / 60).round()
          : null,
      customNote: student.note,
    );

    WhatsAppInteractiveDialog.show(
      context,
      studentName: student.studentName,
      reportText: reportText,
      phone: student.phone,
    );
  }

  static void showWhatsAppOverallNotice(
    BuildContext context, {
    required StudentAttendanceItem student,
    required TeacherAttendanceLoaded loadedState,
    required String? selectedGroupId,
  }) {
    final groupsState = context.read<GroupsCubit>().state;
    String groupName = 'المجموعة';
    if (groupsState is GroupsLoaded) {
      final match = groupsState.groups.where((g) => g.id == selectedGroupId);
      if (match.isNotEmpty) {
        groupName = match.first.name;
      }
    }

    final total = student.totalLecturesCount > 0 ? student.totalLecturesCount : 1;
    final completed = student.completedLecturesCount;
    final completionPct = (completed / total) * 100.0;

    final reportText = WhatsAppReportGenerator.generateOverallEngagementNotice(
      studentName: student.studentName,
      groupName: groupName,
      completedLectures: completed,
      totalLectures: total,
      completionPercentage: completionPct,
      customNote: student.note,
    );

    WhatsAppInteractiveDialog.show(
      context,
      studentName: student.studentName,
      reportText: reportText,
      phone: student.phone,
    );
  }
}
