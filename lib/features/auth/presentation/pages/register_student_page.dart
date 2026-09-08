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
  final _customTrackController = TextEditingController();

  static const List<String> _tracks = [
    'SAT',
    'EST',
    'ACT',
    'Basics',
    'Advanced',
    'مخصص',
  ];

  String _selectedTrack = 'SAT';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _customTrackController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Canonical Tenant ID for default American System Academy
    final tenantId = widget.tenantId ?? '11111111-1111-1111-1111-111111111111';

    final effectiveTrack = _selectedTrack == 'مخصص'
        ? _customTrackController.text.trim()
        : _selectedTrack;

    final studentFullName = _nameController.text.trim();
    final displayName = effectiveTrack.isNotEmpty
        ? '$studentFullName ($effectiveTrack)'
        : studentFullName;

    context.read<AuthCubit>().registerStudent(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: displayName,
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
                constraints: const BoxConstraints(maxWidth: 480),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'الانضمام للأكاديمية التعليمية',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        const Text(
                          'برنامج الدبلومة الأمريكية والرياضيات المتخصصة (SAT / EST / ACT)',
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
                        const SizedBox(height: AppSpacing.s20),

                        // مسار الدراسة / المستوى المطلوب
                        const Text(
                          'المسار أو المستوى المستهدف:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s8,
                          children: _tracks.map((track) {
                            final isSelected = _selectedTrack == track;
                            return ChoiceChip(
                              label: Text(track),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedTrack = track;
                                  });
                                }
                              },
                            );
                          }).toList(),
                        ),

                        // حقل إدخال عند اختيار "مخصص"
                        if (_selectedTrack == 'مخصص') ...[
                          const SizedBox(height: AppSpacing.s16),
                          AppTextField(
                            controller: _customTrackController,
                            labelText: 'المسار أو المجموعة المخصصة',
                            hintText: 'مثال: AP Calculus, ورشة المراجعة السريعة...',
                            prefixIcon: const Icon(Icons.edit_note_outlined, size: 20),
                            validator: (val) {
                              if (_selectedTrack == 'مخصص' && (val == null || val.trim().isEmpty)) {
                                return 'يرجى كتابة اسم المسار أو المجموعة المخصصة';
                              }
                              return null;
                            },
                          ),
                        ],

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
