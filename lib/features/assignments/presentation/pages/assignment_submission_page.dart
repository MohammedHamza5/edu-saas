import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../domain/entities/assignment_entity.dart';
import '../cubit/assignments_cubit.dart';
import '../cubit/assignments_state.dart';
import '../widgets/assignment_details_info_card.dart';
import '../widgets/assignment_files_upload_section.dart';
import '../widgets/assignment_previous_submission_card.dart';

class AssignmentSubmissionPage extends StatefulWidget {
  final AssignmentEntity assignment;

  const AssignmentSubmissionPage({super.key, required this.assignment});

  @override
  State<AssignmentSubmissionPage> createState() =>
      _AssignmentSubmissionPageState();
}

class _AssignmentSubmissionPageState extends State<AssignmentSubmissionPage> {
  final List<PlatformFile> _selectedFiles = [];

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'heic', 'heif'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(
          context,
          context.l10n.filePickFailed(e.toString()),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  Future<void> _submitAssignment() async {
    if (_selectedFiles.isEmpty) {
      AppFeedback.showWarning(context, context.l10n.attachAtLeastOneFile);
      return;
    }

    final filesToUpload = _selectedFiles.map((f) {
      final ext = f.extension?.toLowerCase() ?? '';
      String mimeType = 'application/octet-stream';
      if (ext == 'pdf') mimeType = 'application/pdf';
      if (ext == 'png') mimeType = 'image/png';
      if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';
      if (ext == 'heic') mimeType = 'image/heic';
      if (ext == 'heif') mimeType = 'image/heif';

      return (
        fileName: f.name,
        bytes: f.bytes?.toList() ?? <int>[],
        mimeType: mimeType,
      );
    }).toList();

    final successMsg = context.l10n.assignmentSubmittedSuccess;
    final cubit = context.read<AssignmentsCubit>();
    final success = await cubit.submitAssignment(
      assignmentId: widget.assignment.id,
      files: filesToUpload,
    );

    if (!mounted) return;

    if (success) {
      AppFeedback.showSuccess(context, successMsg);
      Navigator.of(context).pop();
    } else {
      final state = cubit.state;
      final errorMsg = state is StudentAssignmentsLoaded && state.message != null
          ? state.message!
          : context.l10n.errorOccurred;
      AppFeedback.showError(context, errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
    final assignment = widget.assignment;
    final mySub = assignment.mySubmission;
    final isReviewed = mySub?.isReviewed ?? false;
    final isSubmitted = mySub != null;
    final isOverdue = assignment.isOverdue;
    final canSubmit =
        !isReviewed && (!isOverdue || assignment.allowLateSubmission);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.assignmentDetailsTitle),
        centerTitle: true,
      ),
      body: BlocBuilder<AssignmentsCubit, AssignmentsState>(
        builder: (context, state) {
          final isSubmitting =
              state is StudentAssignmentsLoaded && state.isSubmitting;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AssignmentDetailsInfoCard(
                  assignment: assignment,
                  dateFormat: dateFormat,
                ),
                if (mySub != null)
                  AssignmentPreviousSubmissionCard(
                    assignment: assignment,
                    mySub: mySub,
                    dateFormat: dateFormat,
                  ),
                AssignmentFilesUploadSection(
                  canSubmit: canSubmit,
                  isSubmitted: isSubmitted,
                  isOverdue: isOverdue,
                  allowLateSubmission: assignment.allowLateSubmission,
                  isSubmitting: isSubmitting,
                  selectedFiles: _selectedFiles,
                  onPickFiles: _pickFiles,
                  onRemoveFile: _removeFile,
                  onSubmit: _submitAssignment,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
