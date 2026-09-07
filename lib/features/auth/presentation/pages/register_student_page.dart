import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/auth_state.dart';

class RegisterStudentPage extends StatefulWidget {
  final String? tenantId;

  const RegisterStudentPage({super.key, this.tenantId});

  @override
  State<RegisterStudentPage> createState() => _RegisterStudentPageState();
}

class _RegisterStudentPageState extends State<RegisterStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final tenantId = widget.tenantId ?? '00000000-0000-0000-0000-000000000001';

    context.read<AuthCubit>().registerStudent(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          tenantId: tenantId,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل حساب طالب جديد'),
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthPendingApproval) {
            context.go(AppRouter.studentPending, extra: state.user.fullName);
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'انضم إلى المنصة التعليمية',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        const Text(
                          'املأ البيانات التالية لتقديم طلب الانضمام للمعلم',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        AppTextField(
                          controller: _nameController,
                          labelText: 'الاسم ثلاثي',
                          prefixIcon: const Icon(Icons.person_outline, size: 20),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'يرجى إدخال اسم الطالب';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppTextField(
                          controller: _emailController,
                          labelText: 'البريد الإلكتروني',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined, size: 20),
                          validator: (val) {
                            if (val == null || !val.contains('@')) {
                              return 'يرجى إدخال بريد إلكتروني صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppTextField(
                          controller: _phoneController,
                          labelText: 'رقم الهاتف (واتساب)',
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                          validator: (val) {
                            if (val == null || val.trim().length < 8) {
                              return 'يرجى إدخال رقم هاتف صحيح';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        AppTextField(
                          controller: _passwordController,
                          labelText: 'كلمة المرور',
                          isPassword: true,
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          validator: (val) {
                            if (val == null || val.length < 6) {
                              return 'يجب أن لا تقل كلمة المرور عن 6 أحرف';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.s24),
                        AppButton(
                          text: 'تقديم طلب التسجيل',
                          isLoading: isLoading,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        TextButton(
                          onPressed: () {
                            context.go(AppRouter.login);
                          },
                          child: const Text('لديك حساب بالفعل؟ تسجيل الدخول'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
