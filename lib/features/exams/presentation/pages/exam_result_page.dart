import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';

class ExamResultPage extends StatelessWidget {
  final ExamEntity exam;
  final ExamAttemptEntity attempt;

  const ExamResultPage({
    super.key,
    required this.exam,
    required this.attempt,
  });

  @override
  Widget build(BuildContext context) {
    final isPassed = attempt.isPassed(exam.passingScore);
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');
    final score = attempt.score ?? 0;
    final percentage = attempt.percentage ?? (exam.maxScore > 0 ? (score / exam.maxScore) * 100 : 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نتيجة الامتحان'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          children: [
            // Hero Result Card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: (isPassed ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isPassed ? Icons.emoji_events_outlined : Icons.sentiment_dissatisfied_outlined,
                        color: isPassed ? AppColors.success : AppColors.error,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  Text(
                    isPassed ? 'تهانينا! لقد اجتزت الامتحان بنجاح' : 'للأسف لم تتجاوز درجة النجاح',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isPassed ? AppColors.success : AppColors.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s6),

                  Text(
                    exam.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: AppSpacing.s20),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: AppSpacing.s20),

                  // Score Numbers (Large Academic Typography)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$score',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          color: isPassed ? AppColors.success : AppColors.error,
                        ),
                      ),
                      Text(
                        ' / ${exam.maxScore}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'النسبة المئوية: ${percentage.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (exam.passingScore != null) ...[
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      'درجة النجاح المطلوبة: ${exam.passingScore} من ${exam.maxScore}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s16),

            // Attempt details card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: Column(
                children: [
                  _buildDetailRow(
                    'تاريخ التسليم',
                    attempt.submittedAt != null ? dateFormat.format(attempt.submittedAt!) : 'الآن',
                  ),
                  const Divider(height: AppSpacing.s16, color: AppColors.border),
                  _buildDetailRow(
                    'حالة المحاولة',
                    attempt.status.labelAr,
                    valueColor: attempt.status.color,
                  ),
                  if (exam.allowRetake) ...[
                    const Divider(height: AppSpacing.s16, color: AppColors.border),
                    _buildDetailRow(
                      'سياسة إعادة الامتحان',
                      'مسموحة (يتم اعتماد أعلى درجة)',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s32),

            AppButton(
              text: 'العودة لقائمة الامتحانات',
              icon: Icons.home_outlined,
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildDetailRow(String title, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
