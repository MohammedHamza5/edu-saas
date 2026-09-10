import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/tenant_registry.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/math_tokens.dart';
import '../../../../core/theme/tenant_theme_cubit.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/academic_auth_scaffold.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/language_switcher_button.dart';
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
    'custom',
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
    final tenantId =
        widget.tenantId ?? '11111111-1111-1111-1111-111111111111';

    final effectiveTrack = _selectedTrack == 'custom'
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
    final branding = (() {
      try {
        return context.watch<TenantThemeCubit>().state;
      } catch (_) {
        return TenantRegistry.defaultBranding;
      }
    })();
    final mathTokens =
        Theme.of(context).extension<MathTokens>() ?? MathTokens.light;

    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthPendingApproval) {
          context.go(AppRouter.studentPending, extra: state.user.fullName);
        } else if (state is AuthError) {
          AppFeedback.showError(context, state.message);
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;

        return AcademicAuthScaffold(
          maxWidth: 500,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Language Switcher at Top ────────────────────────────────
                const Align(
                  alignment: AlignmentDirectional.topEnd,
                  child: LanguageSwitcherButton(compact: true),
                ),
                const SizedBox(height: AppSpacing.s8),

                // ── 1. Brand Emblem ──────────────────────────────────────────
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: mathTokens.primaryButtonGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: branding.primaryColor.withValues(alpha: 0.35),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      branding.signatureSymbol,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'serif',
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── 2. Academic Registration Badge ───────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: branding.primaryColor.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                      border: Border.all(
                        color: branding.primaryColor.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981), // Emerald indicator
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            context.l10n.studentRegistrationBadge,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: TextStyle(
                              color: branding.primaryLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── 3. Page Title & Subtitle ─────────────────────────────────
                Text(
                  context.l10n.registerStudentTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${branding.teacherName} • ${branding.academicTrack}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.s28),

                // ── 4. Student Full Name ──────────────────────────────────────
                AppTextField(
                  controller: _nameController,
                  labelText: context.l10n.fullNameInputHint,
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return context.l10n.pleaseEnterFullName;
                    }
                    if (val.trim().split(' ').length < 2) {
                      return context.l10n.pleaseEnterValidFullName;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── 5. Email Address ─────────────────────────────────────────
                AppTextField(
                  controller: _emailController,
                  labelText: context.l10n.emailLabel,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  validator: (val) {
                    if (val == null || !val.contains('@')) {
                      return context.l10n.pleaseEnterValidEmail;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── 6. WhatsApp Phone Number ─────────────────────────────────
                AppTextField(
                  controller: _phoneController,
                  labelText: context.l10n.studentWhatsappPhone,
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                  validator: (val) {
                    if (val == null || val.trim().length < 10) {
                      return context.l10n.pleaseEnterValidPhone;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                // ── 7. Academic Track Selection ──────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.targetAcademicTrack,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Wrap(
                      spacing: AppSpacing.s8,
                      runSpacing: AppSpacing.s8,
                      children: _tracks.map((track) {
                        final isSelected = _selectedTrack == track;
                        final displayLabel = track == 'custom' ? context.l10n.customTrack : track;
                        return ChoiceChip(
                          label: Text(displayLabel),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedTrack = track);
                            }
                          },
                          selectedColor: branding.primaryColor,
                          backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.7),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFFCBD5E1),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? branding.primaryLight
                                  : Colors.white.withValues(alpha: 0.14),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),

                if (_selectedTrack == 'custom') ...[
                  const SizedBox(height: AppSpacing.s12),
                  AppTextField(
                    controller: _customTrackController,
                    labelText: 'المسار أو المجموعة المخصصة',
                    prefixIcon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                ],
                const SizedBox(height: AppSpacing.s16),

                // ── 8. Password ──────────────────────────────────────────────
                AppTextField(
                  controller: _passwordController,
                  isPassword: true,
                  labelText: context.l10n.passwordFieldHint,
                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return context.l10n.pleaseEnterPasswordMin;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s24),

                // ── 9. Submit Registration Button ────────────────────────────
                AppButton(
                  text: context.l10n.registerAndStartLearning,
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
                const SizedBox(height: AppSpacing.s20),

                // ── 10. Login Navigation Link ────────────────────────────────
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.alreadyRegisteredPrompt,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      style: TextButton.styleFrom(
                        enabledMouseCursor: SystemMouseCursors.click,
                      ),
                      onPressed: () => context.go(AppRouter.login),
                      child: Text(
                        context.l10n.signInNowLink,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: branding.primaryLight,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s8),

                // ── 11. Approval Workflow Note ───────────────────────────────
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 13,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.l10n.registrationApprovalNotice,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
