import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/mistake_entities.dart';
import '../cubit/mistakes_cubit.dart';

/// Compact, aesthetic self-reflection selector for student mistakes.
class MistakeReflectionSelector extends StatelessWidget {
  final MistakeQuestionEntity question;

  const MistakeReflectionSelector({
    super.key,
    required this.question,
  });

  void _onSelectReason(BuildContext context, String reasonKey) {
    final current = question.reflectionReason;
    final newReason = (current == reasonKey) ? null : reasonKey;
    context.read<MistakesCubit>().updateReflection(
          mistakeId: question.mistakeId,
          reason: newReason,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final current = question.reflectionReason;

    final reasons = [
      (
        key: 'concept_gap',
        label: l10n.reflectionConceptGap,
        icon: Icons.psychology_outlined,
        color: const Color(0xFF7C3AED),
      ),
      (
        key: 'careless_error',
        label: l10n.reflectionCarelessError,
        icon: Icons.bolt_outlined,
        color: AppColors.error,
      ),
      (
        key: 'misread_question',
        label: l10n.reflectionMisreadQuestion,
        icon: Icons.menu_book_outlined,
        color: const Color(0xFF0284C7),
      ),
      (
        key: 'time_pressure',
        label: l10n.reflectionTimePressure,
        icon: Icons.hourglass_top_outlined,
        color: AppColors.warning,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.help_outline_rounded, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                l10n.reflectionHeader,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),
        Wrap(
          spacing: AppSpacing.s6,
          runSpacing: AppSpacing.s6,
          children: reasons.map((r) {
            final isSelected = current == r.key;
            return InkWell(
              onTap: () => _onSelectReason(context, r.key),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? r.color.withValues(alpha: 0.16)
                      : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: isSelected
                        ? r.color.withValues(alpha: 0.6)
                        : Colors.transparent,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      r.icon,
                      size: 13,
                      color: isSelected ? r.color : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      r.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? r.color : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
