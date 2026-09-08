import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة المعلم الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () {
              context.read<AuthCubit>().logout();
              context.go(AppRouter.login);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نظرة عامة على المجموعات والطلاب',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            Row(
              children: [
                const Expanded(
                  child: AppCard(
                    padding: EdgeInsets.all(AppSpacing.s16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إجمالي الطلاب', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        SizedBox(height: AppSpacing.s8),
                        Text('10', style: AppTypography.statFigureLarge),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s16),
                Expanded(
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.s16),
                    onTap: () => context.push(AppRouter.groupsList),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('المجموعات النشطة', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        SizedBox(height: AppSpacing.s8),
                        Text('3', style: AppTypography.statFigureLarge),
                        SizedBox(height: AppSpacing.s4),
                        Text('اضغط للإدارة والتحكم ←', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),
            AppCard(
              onTap: () => context.push(AppRouter.groupsList),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.groups_rounded, color: AppColors.primary),
                  ),
                  SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('إدارة المجموعات الدراسية (SAT / EST / ACT)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                        SizedBox(height: 4),
                        Text('إنشاء مجموعات جديدة، تخصيص المسارات، وضبط سياسة المحتوى السابق', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),
            AppCard(
              onTap: () => context.push(AppRouter.teacherAttendance),
              child: const Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryLight,
                    child: Icon(Icons.fact_check_rounded, color: AppColors.primary),
                  ),
                  SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('رصد الحضور والغياب اليومي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                        SizedBox(height: 4),
                        Text('تسجيل حضور وغياب الطلاب في المجموعات مع ملاحظات وإحصائيات فورية', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
