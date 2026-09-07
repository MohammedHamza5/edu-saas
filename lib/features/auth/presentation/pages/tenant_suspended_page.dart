import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';

class TenantSuspendedPage extends StatelessWidget {
  const TenantSuspendedPage({super.key});

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
                      color: Color(0xFFFEE2E2), // Red 100
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      color: AppColors.error,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  const Text(
                    'تم تعليق هذا الحساب المؤسسي',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  const Text(
                    'نأسف، تم تعليق وصول المنصة لهذا المدرس مؤقتاً. بياناتك محفوظة بالكامل ولكن لا يمكن تسجيل الدخول في الوقت الحالي. يرجى مراجعة إدارة المنصة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s32),
                  AppButton(
                    text: 'العودة للرئيسية',
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
