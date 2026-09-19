import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/academic_auth_scaffold.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/language_switcher_button.dart';

class TenantSuspendedPage extends StatelessWidget {
  const TenantSuspendedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AcademicAuthScaffold(
      maxWidth: 460,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: AlignmentDirectional.topEnd,
            child: LanguageSwitcherButton(compact: true),
          ),
          const SizedBox(height: AppSpacing.s8),
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                  blurRadius: 20,
                ),
              ],
            ),
            child: const Icon(
              Icons.block_rounded,
              color: Color(0xFFF87171),
              size: 38,
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          Text(
            context.l10n.tenantSuspendedTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),
          Text(
            context.l10n.tenantSuspendedMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF94A3B8),
              height: 1.6,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s32),
          AppButton(
            text: context.l10n.backToLogin,
            variant: AppButtonVariant.primary,
            onPressed: () {
              context.go(AppRoutes.login);
            },
          ),
        ],
      ),
    );
  }
}
