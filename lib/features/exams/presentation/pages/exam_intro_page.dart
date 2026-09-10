import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import 'exam_taking_page.dart';

class ExamIntroPage extends StatelessWidget {
  final ExamEntity exam;

  const ExamIntroPage({
    super.key,
    required this.exam,
  });

  @override
  Widget build(BuildContext context) {
    final hasActive = exam.hasActiveAttempt;
    final canTake = exam.canTakeExam;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعليمات وقواعد الامتحان'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.s20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.quiz_outlined,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Text(
                    exam.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (exam.groupName != null) ...[
                    const SizedBox(height: AppSpacing.s6),
                    Text(
                      'المجموعة: ${exam.groupName}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s20),

            // Key Stats Grid
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    Icons.timer_outlined,
                    'مدة الامتحان',
                    '${exam.durationMinutes} دقيقة',
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: _buildInfoTile(
                    Icons.grade_outlined,
                    'الدرجة العظمى',
                    '${exam.maxScore} درجة',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    Icons.verified_outlined,
                    'درجة النجاح',
                    exam.passingScore != null ? '${exam.passingScore} درجة' : 'غير محددة',
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: _buildInfoTile(
                    Icons.replay_outlined,
                    'إعادة المحاولة',
                    exam.allowRetake ? 'مسموحة (أعلى درجة)' : 'غير مسموحة',
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.s24),

            // Instructions Box
            const Text(
              'تعليمات هامة قبل البدء:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _RuleItem(text: 'يبدأ احتساب الوقت فور الضغط على زر "بدء الامتحان" عبر خوادم المنصة.'),
                  SizedBox(height: AppSpacing.s8),
                  _RuleItem(text: 'يتم حفظ إجاباتك تلقائياً أثناء التنقل بين الأسئلة تحسباً لأي انقطاع في الاتصال.'),
                  SizedBox(height: AppSpacing.s8),
                  _RuleItem(text: 'عند انتهاء الوقت سيتم تسليم إجاباتك تلقائياً واحتساب النتيجة فوراً.'),
                  SizedBox(height: AppSpacing.s8),
                  _RuleItem(text: 'يُرجى عدم إغلاق نافذة الامتحان حتى ظهور رسالة التسليم بنجاح.'),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.s32),

            // Action Button
            if (canTake) ...[
              AppButton(
                text: hasActive ? 'استئناف الامتحان الحالي' : 'بدء الامتحان الآن',
                icon: hasActive ? Icons.play_arrow : Icons.rocket_launch_outlined,
                onPressed: () async {
                  final cubit = context.read<ExamsCubit>();
                  final success = await cubit.startExamTaking(exam);

                  if (context.mounted && success) {
                    await Navigator.of(context).pushReplacement<void, void>(
                      MaterialPageRoute<void>(
                        builder: (_) => BlocProvider.value(
                          value: cubit,
                          child: const ExamTakingPage(),
                        ),
                      ),
                    );
                  }
                },
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(color: AppColors.warning),
                ),
                child: Center(
                  child: Text(
                    exam.myBestScore != null
                        ? 'لقد أنهيت هذا الامتحان مسبقاً بنتيجة: ${exam.myBestScore}/${exam.maxScore} ولا يُسمح بالإعادة.'
                        : 'لا يمكن تقديم هذا الامتحان حالياً.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: AppSpacing.s6),
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String text;
  const _RuleItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.check_circle_outline, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
