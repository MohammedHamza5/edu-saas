import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          context.l10n.studentProfileAndSettingsTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      body: BlocConsumer<StudentProfileCubit, StudentProfileState>(
        listener: _handleStateListeners,
        builder: (context, state) {
          return switch (state) {
            StudentProfileInitial() || StudentProfileLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
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
                    vertical: AppSpacing.s20,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Header Card (Avatar, Status, Enrolled Groups)
                          StudentProfileHeaderCard(profile: profile),
                          const SizedBox(height: AppSpacing.s20),

                          // 2. Contact Information & Name (With Parent Phone Dialog)
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

                          // 3. Security (Password change)
                          StudentSecuritySection(
                            isChangingPassword: isChangingPassword,
                            onChangePassword: ({required newPassword}) async {
                              await context.read<StudentProfileCubit>().changePassword(
                                    newPassword: newPassword,
                                  );
                            },
                          ),
                          const SizedBox(height: AppSpacing.s20),

                          // 4. Preferences (Language, Logout)
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
