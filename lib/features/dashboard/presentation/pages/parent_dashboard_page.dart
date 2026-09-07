import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';

class ParentDashboardPage extends StatelessWidget {
  const ParentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة متابعة ولي الأمر'),
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
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'متابعة مستوى الأبناء الأكاديمي',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.s16),
            AppCard(
              title: 'التقارير الأكاديمية (قراءة فقط)',
              subtitle: 'سجل الحضور ودرجات الامتحانات والواجبات',
              child: Text(
                'هذه اللوحة مخصصة لعرض درجات ومتابعة الطلاب المرتبطين بحسابك فقط.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
