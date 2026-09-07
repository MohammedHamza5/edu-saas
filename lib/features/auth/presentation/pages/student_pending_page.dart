import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

class StudentPendingPage extends StatelessWidget {
  final String studentName;

  const StudentPendingPage({
    super.key,
    this.studentName = 'طالبنا العزيز',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.s32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7), // Amber 100
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: Color(0xFFB45309), // Amber 700
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  const Text(
                    'طلبك قيد المراجعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    'مرحباً $studentName، تم استلام بيانات تسجيلك بنجاح. حسابك بانتظار موافقة المعلم للانضمام إلى المجموعة الدراسية.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  AppButton(
                    text: 'العودة لتسجيل الدخول',
                    variant: AppButtonVariant.outlined,
                    onPressed: () {
                      context.go(AppRouter.login);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
