import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/assignment_entity.dart';
import '../cubit/assignments_cubit.dart';
import '../cubit/assignments_state.dart';

class GradeSubmissionPage extends StatefulWidget {
  final AssignmentEntity assignment;
  final AssignmentSubmissionEntity submission;

  const GradeSubmissionPage({
    super.key,
    required this.assignment,
    required this.submission,
  });

  @override
  State<GradeSubmissionPage> createState() => _GradeSubmissionPageState();
}

class _GradeSubmissionPageState extends State<GradeSubmissionPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _scoreController;
  late TextEditingController _feedbackController;

  @override
  void initState() {
    super.initState();
    _scoreController = TextEditingController(
      text: widget.submission.score != null ? widget.submission.score.toString() : '',
    );
    _feedbackController = TextEditingController(
      text: widget.submission.teacherFeedback ?? '',
    );
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitGrade() async {
    if (!_formKey.currentState!.validate()) return;

    final score = int.parse(_scoreController.text.trim());
    final feedback = _feedbackController.text.trim().isNotEmpty
        ? _feedbackController.text.trim()
        : null;

    final success = await context.read<AssignmentsCubit>().gradeSubmission(
          submissionId: widget.submission.id,
          score: score,
          feedback: feedback,
        );

    if (mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التقييم بنجاح'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _openFile(SubmissionFileEntity file) async {
    final signedUrl = await context
        .read<AssignmentsCubit>()
        .getFileSignedUrl(file.storagePath);

    if (!mounted) return;

    if (signedUrl != null) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(file.fileName),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('حجم الملف: ${file.formattedSize}'),
              const SizedBox(height: AppSpacing.s8),
              const Text('رابط الملف الآمن (صالح لمدة ساعة):'),
              const SizedBox(height: AppSpacing.s4),
              SelectableText(
                signedUrl,
                style: const TextStyle(fontSize: 12, color: AppColors.primary),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إغلاق'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر فتح الملف حالياً'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');

    return Scaffold(
      appBar: AppBar(
        title: const Text('تقييم تسليم الطالب'),
        centerTitle: true,
      ),
      body: BlocBuilder<AssignmentsCubit, AssignmentsState>(
        builder: (context, state) {
          final isGrading =
              state is TeacherAssignmentsLoaded && state.isGrading;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Student details card
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.1),
                              child: Text(
                                widget.submission.studentName.isNotEmpty
                                    ? widget.submission.studentName.characters.first
                                    : 'ط',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.submission.studentName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (widget.submission.studentEmail != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      widget.submission.studentEmail!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s8,
                                vertical: AppSpacing.s4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.submission.status.color
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSmall),
                              ),
                              child: Text(
                                widget.submission.status.labelAr,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: widget.submission.status.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s12),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: AppSpacing.s12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'تاريخ التسليم: ${dateFormat.format(widget.submission.submittedAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'المحاولة رقم: ${widget.submission.attemptNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s20),

                  // Submitted Files section
                  const Text(
                    'الملفات المرفقة من الطالب',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),

                  if (widget.submission.files.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMedium),
                      ),
                      child: const Center(
                        child: Text(
                          'لم يقم الطالب برفع ملفات مع هذا التسليم',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    )
                  else
                    ...widget.submission.files.map((file) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                        child: AppCard(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          child: Row(
                            children: [
                              Icon(
                                file.isPdf
                                    ? Icons.picture_as_pdf_outlined
                                    : file.isImage
                                        ? Icons.image_outlined
                                        : Icons.insert_drive_file_outlined,
                                color: file.isPdf
                                    ? AppColors.error
                                    : AppColors.primary,
                                size: 28,
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.fileName,
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
                                      file.formattedSize,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined),
                                tooltip: 'عرض الملف',
                                color: AppColors.primary,
                                onPressed: () => _openFile(file),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: AppSpacing.s24),

                  // Grading Form
                  const Text(
                    'رصد الدرجة والتقييم',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  AppTextField(
                    controller: _scoreController,
                    labelText: 'الدرجة المستحقة (من ${widget.assignment.maxScore})',
                    hintText: 'مثال: 85',
                    keyboardType: TextInputType.number,
                    prefixIcon: const Icon(Icons.grade_outlined),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'يرجى إدخال الدرجة';
                      }
                      final val = int.tryParse(value.trim());
                      if (val == null) {
                        return 'يرجى إدخال رقم صحيح';
                      }
                      if (val < 0 || val > widget.assignment.maxScore) {
                        return 'الدرجة يجب أن تكون بين 0 و ${widget.assignment.maxScore}';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.s16),

                  AppTextField(
                    controller: _feedbackController,
                    labelText: 'ملاحظات وتوجيهات للمعلم (اختياري)',
                    hintText: 'أضف نقاط القوة والمجالات التي تحتاج لتحسين...',
                    maxLines: 4,
                    prefixIcon: const Icon(Icons.comment_outlined),
                  ),

                  const SizedBox(height: AppSpacing.s32),

                  AppButton(
                    text: 'حفظ التقييم وإشعار الطالب',
                    onPressed: isGrading ? null : _submitGrade,
                    isLoading: isGrading,
                    variant: AppButtonVariant.primary,
                    icon: Icons.check_circle_outline,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
