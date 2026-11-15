import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/network/supabase_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../cubit/auth_cubit.dart';

/// Shown to a student whose subscription/access duration has elapsed.
/// Provides friendly guidance and a 1-tap WhatsApp renewal link directly to the teacher.
class SubscriptionExpiredPage extends StatelessWidget {
  const SubscriptionExpiredPage({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    final l10n = context.l10n;
    final studentName =
        SupabaseService.currentUser?.userMetadata?['full_name'] as String? ??
        l10n.roleStudent;

    final message = l10n.renewWhatsAppMessage(studentName);
    final encodedMessage = Uri.encodeComponent(message);

    // Dr. Antounios official WhatsApp or default fallback
    const teacherPhone = '+201289196324';
    final cleanPhone = teacherPhone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$encodedMessage');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s24,
            vertical: AppSpacing.s40,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(AppSpacing.s32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 32,
                  offset: Offset(0, 16),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s20),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.hourglass_disabled_rounded,
                    color: AppColors.error,
                    size: 48,
                  ),
                ),
                const SizedBox(height: AppSpacing.s24),

                // Title
                Text(
                  l10n.subscriptionExpiredTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),

                // Description
                Text(
                  l10n.subscriptionExpiredDesc,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.s32),

                // WhatsApp Action Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.chat_bubble_rounded, size: 20),
                    label: Text(
                      l10n.renewSubscriptionWhatsAppAction,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _openWhatsApp(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),

                // Sign Out Action
                SizedBox(
                  width: double.infinity,
                  child: AppButton(
                    text: l10n.logout,
                    variant: AppButtonVariant.text,
                    icon: Icons.logout_rounded,
                    onPressed: () {
                      context.read<AuthCubit>().logout();
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
