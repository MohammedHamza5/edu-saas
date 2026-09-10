import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/assignment_entity.dart';
import '../cubit/assignments_cubit.dart';
import '../cubit/assignments_state.dart';

class AssignmentSubmissionPage extends StatefulWidget {
  final AssignmentEntity assignment;

  const AssignmentSubmissionPage({
    super.key,
    required this.assignment,
  });

  @override
  State<AssignmentSubmissionPage> createState() => _AssignmentSubmissionPageState();
}

class _AssignmentSubmissionPageState extends State<AssignmentSubmissionPage> {
  final List<PlatformFile> _selectedFiles = [];

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر اختيار الملفات: $e'),
            backgroundColor: AppColors.error,
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إرفاق ملف واحد على الأقل قبل التسليم'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final filesToUpload = _selectedFiles.map((f) {
      final ext = f.extension?.toLowerCase() ?? '';
      String mimeType = 'application/octet-stream';
      if (ext == 'pdf') mimeType = 'application/pdf';
      if (ext == 'png') mimeType = 'image/png';
      if (ext == 'jpg' || ext == 'jpeg') mimeType = 'image/jpeg';

      return (
        fileName: f.name,
        bytes: f.bytes?.toList() ?? <int>[],
        mimeType: mimeType,
      );
    }).toList();

    final success = await context.read<AssignmentsCubit>().submitAssignment(
          assignmentId: widget.assignment.id,
          files: filesToUpload,
        );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسليم الواجب بنجاح!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
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
    final canSubmit = !isReviewed && (!isOverdue || assignment.allowLateSubmission);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل وتسليم الواجب'),
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
                // Assignment Info Card
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  assignment.title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (assignment.groupName != null) ...[
                                  const SizedBox(height: AppSpacing.s4),
                                  Text(
                                    'المجموعة: ${assignment.groupName}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s10,
                              vertical: AppSpacing.s6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                            ),
                            child: Text(
                              '${assignment.maxScore} درجة',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),
                      const Divider(height: 1, color: AppColors.border),
                      const SizedBox(height: AppSpacing.s12),

                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: isOverdue ? AppColors.error : AppColors.textMuted,
                          ),
                          const SizedBox(width: AppSpacing.s6),
                          Expanded(
                            child: Text(
                              assignment.dueAt != null
                                  ? 'الموعد النهائي: ${dateFormat.format(assignment.dueAt!)}'
                                  : 'لا يوجد موعد نهائي محدد',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal,
                                color: isOverdue ? AppColors.error : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (assignment.allowLateSubmission) ...[
                        const SizedBox(height: AppSpacing.s6),
                        const Row(
                          children: [
                            Icon(Icons.info_outline, size: 14, color: AppColors.info),
                            SizedBox(width: AppSpacing.s6),
                            Text(
                              'التسليم المتأخر متاح بعد الموعد',
                              style: TextStyle(fontSize: 12, color: AppColors.info),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s16),

                // Instructions Card
                if (assignment.instructions != null &&
                    assignment.instructions!.trim().isNotEmpty) ...[
                  const Text(
                    'التعليمات والأسئلة المطلوبة',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Text(
                      assignment.instructions!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s20),
                ],

                // Previous Submission / Feedback Card
                if (isSubmitted) ...[
                  const Text(
                    'حالة تسليمك للواجب',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    backgroundColor: isReviewed
                        ? AppColors.success.withValues(alpha: 0.05)
                        : AppColors.surface,
                    borderColor: isReviewed ? AppColors.success : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(mySub.status.icon, color: mySub.status.color, size: 20),
                                const SizedBox(width: AppSpacing.s8),
                                Text(
                                  mySub.status.labelAr,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: mySub.status.color,
                                  ),
                                ),
                              ],
                            ),
                            if (isReviewed && mySub.score != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s12,
                                  vertical: AppSpacing.s6,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  borderRadius:
                                      BorderRadius.circular(AppSpacing.radiusSmall),
                                ),
                                child: Text(
                                  'الدرجة: ${mySub.score} / ${assignment.maxScore}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Text(
                          'تاريخ التسليم: ${dateFormat.format(mySub.submittedAt)} (محاولة ${mySub.attemptNumber})',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),

                        // Teacher Feedback if available
                        if (mySub.teacherFeedback != null &&
                            mySub.teacherFeedback!.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s12),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: AppSpacing.s12),
                          const Row(
                            children: [
                              Icon(Icons.rate_review_outlined,
                                  size: 16, color: AppColors.primary),
                              SizedBox(width: AppSpacing.s6),
                              Text(
                                'ملاحظات المعلم:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s6),
                          Text(
                            mySub.teacherFeedback!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s20),
                ],

                // File Upload Section (if submission is allowed)
                if (canSubmit) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isSubmitted ? 'إعادة التسليم (محاولة جديدة)' : 'رفع ملفات الحل',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pickFiles,
                        icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                        label: const Text('اختيار ملفات'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),

                  if (_selectedFiles.isEmpty)
                    InkWell(
                      onTap: _pickFiles,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s32,
                          horizontal: AppSpacing.s16,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                          border: Border.all(
                            color: AppColors.border,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: const Column(
                          children: [
                            Icon(
                              Icons.cloud_upload_outlined,
                              size: 44,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: AppSpacing.s12),
                            Text(
                              'اضغط لاختيار ملفات الإجابة (PDF أو صور)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: AppSpacing.s4),
                            Text(
                              'الحد الأقصى للملف 20 ميجابايت',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._selectedFiles.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final file = entry.value;
                      final isPdf = file.extension?.toLowerCase() == 'pdf';

                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          child: Row(
                            children: [
                              Icon(
                                isPdf
                                    ? Icons.picture_as_pdf_outlined
                                    : Icons.image_outlined,
                                color: isPdf ? AppColors.error : AppColors.primary,
                                size: 28,
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${(file.size / 1024).toStringAsFixed(1)} KB',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.error),
                                onPressed: () => _removeFile(idx),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: AppSpacing.s24),

                  AppButton(
                    text: isSubmitted ? 'إرسال المحاولة الجديدة' : 'تسليم الواجب الآن',
                    onPressed: isSubmitting ? null : _submitAssignment,
                    isLoading: isSubmitting,
                    variant: AppButtonVariant.primary,
                    icon: Icons.check_circle_outline,
                  ),
                ] else if (isOverdue && !assignment.allowLateSubmission && !isSubmitted) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.error_outline, color: AppColors.error),
                        SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Text(
                            'انتهى موعد تسليم هذا الواجب ولا يُسمح بالتسليم المتأخر.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
