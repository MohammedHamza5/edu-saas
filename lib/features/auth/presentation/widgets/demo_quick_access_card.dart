import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import 'demo_access_button.dart';

/// Interactive 1-click Quick Access Card for Prospective Teachers on the Demo Domain.
/// Eliminates all typing friction by providing instant login buttons with seed accounts.
class DemoQuickAccessCard extends StatelessWidget {
  final void Function(String email, String password) onSelectCredentials;
  final bool isLoading;

  const DemoQuickAccessCard({
    super.key,
    required this.onSelectCredentials,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s20),
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B4B).withValues(alpha: 0.65), // Deep Indigo
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFF38BDF8),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.demoQuickAccessHeader,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  context.l10n.demoLiveBadge,
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Text(
            context.l10n.demoSelectAccountPrompt,
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // 1. Teacher Quick Login
          DemoAccessButton(
            icon: Icons.school_rounded,
            title: context.l10n.demoTeacherLoginTitle,
            subtitle: context.l10n.demoTeacherLoginSubtitle,
            color: const Color(0xFF6366F1),
            isLoading: isLoading,
            onTap: () =>
                onSelectCredentials('demo.teacher@edsentre.com', 'Demo@2026!'),
          ),
          const SizedBox(height: 8),

          // 2. Student 1: Test Taking with Desmos
          DemoAccessButton(
            icon: Icons.calculate_rounded,
            title: context.l10n.demoStudentTestLoginTitle,
            subtitle: context.l10n.demoStudentTestLoginSubtitle,
            color: const Color(0xFF0EA5E9),
            isLoading: isLoading,
            onTap: () =>
                onSelectCredentials('demo.student1@edsentre.com', 'Demo@2026!'),
          ),
          const SizedBox(height: 8),

          // 3. Student 2: Mistakes & Anki
          DemoAccessButton(
            icon: Icons.auto_awesome_rounded,
            title: context.l10n.demoStudentMistakesLoginTitle,
            subtitle: context.l10n.demoStudentMistakesLoginSubtitle,
            color: const Color(0xFF8B5CF6),
            isLoading: isLoading,
            onTap: () =>
                onSelectCredentials('demo.student2@edsentre.com', 'Demo@2026!'),
          ),
        ],
      ),
    );
  }
}
