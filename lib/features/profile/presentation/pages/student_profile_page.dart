import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/academic_hero_banner.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../cubit/student_profile_cubit.dart';
import '../cubit/student_profile_state.dart';
import '../widgets/sections/student_contact_info_section.dart';
import '../widgets/sections/student_preferences_section.dart';
import '../widgets/sections/student_profile_header_card.dart';
import '../widgets/sections/student_security_section.dart';

/// Coordinator Page for Student Profile and Settings
class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  State<StudentProfilePage> createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<StudentProfileCubit>().loadProfile();
      }
    });
  }

  void _handleStateListeners(BuildContext context, StudentProfileState state) {
    if (state is StudentProfileLoaded) {
      if (state.successMessage != null) {
        final msg = switch (state.successMessage) {
          'PROFILE_UPDATED_SUCCESS' => context.l10n.studentProfileUpdatedSuccess,
          'PASSWORD_CHANGED_SUCCESS' => context.l10n.studentPasswordUpdatedSuccess,
          'AVATAR_UPDATED_SUCCESS' => context.l10n.studentAvatarUpdatedSuccess,
          _ => state.successMessage!,
        };
        AppFeedback.showSuccess(context, msg);
        context.read<StudentProfileCubit>().clearMessages();
      } else if (state.errorMessage != null) {
        AppFeedback.showError(context, state.errorMessage);
        context.read<StudentProfileCubit>().clearMessages();
      }
    }
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s20,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              Container(
                height: 110,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.l10n.studentProfileAndSettingsTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: isAr ? 'رجوع' : 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.studentDashboard);
            }
          },
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocConsumer<StudentProfileCubit, StudentProfileState>(
        listener: _handleStateListeners,
        builder: (context, state) {
          return switch (state) {
            StudentProfileInitial() || StudentProfileLoading() => _buildLoadingSkeleton(),
            StudentProfileError(:final message) => AppErrorView(
                message: message,
                onRetry: () => context.read<StudentProfileCubit>().loadProfile(),
              ),
            StudentProfileLoaded(:final profile, :final isSaving, :final isChangingPassword) =>
              RefreshIndicator(
                onRefresh: () => context.read<StudentProfileCubit>().loadProfile(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Prestigious Academic Hero Banner
                          AcademicHeroBanner(
                            title: context.l10n.studentProfileAndSettingsTitle,
                            subtitle: context.l10n.studentProfileSubtitle,
                            trailing: Container(
                              padding: const EdgeInsets.all(AppSpacing.s12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                              ),
                              child: const Icon(
                                Icons.manage_accounts_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s20),

                          // 2. Header Card (Avatar, Status, Enrolled Groups)
                          StudentProfileHeaderCard(profile: profile),
                          const SizedBox(height: AppSpacing.s20),

                          // 3. Contact Information & Name (With Parent Phone Dialog)
                          StudentContactInfoSection(
                            profile: profile,
                            isSaving: isSaving,
                            onSave: ({
                              required fullName,
                              phone,
                              parentPhone,
                            }) async {
                              await context.read<StudentProfileCubit>().updateProfileInfo(
                                    fullName: fullName,
                                    phone: phone,
                                    parentPhone: parentPhone,
                                  );
                            },
                          ),
                          const SizedBox(height: AppSpacing.s20),

                          // 4. Security (Password change)
                          StudentSecuritySection(
                            isChangingPassword: isChangingPassword,
                            onChangePassword: ({required newPassword}) async {
                              await context.read<StudentProfileCubit>().changePassword(
                                    newPassword: newPassword,
                                  );
                            },
                          ),
                          const SizedBox(height: AppSpacing.s20),

                          // 5. Preferences (Language, Logout)
                          const StudentPreferencesSection(),
                          const SizedBox(height: AppSpacing.s32),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          };
        },
      ),
    );
  }
}
