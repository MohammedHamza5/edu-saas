import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/child_entity.dart';

class ChildSelectorBar extends StatelessWidget {
  final List<ChildEntity> children;
  final ChildEntity selectedChild;
  final ValueChanged<ChildEntity> onChildSelected;

  const ChildSelectorBar({
    super.key,
    required this.children,
    required this.selectedChild,
    required this.onChildSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (children.length <= 1) {
      // Single child view: Simple academic header badge
      final child = children.first;
      return RepaintBoundary(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.18),
                      AppColors.primary.withValues(alpha: 0.06),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  child.fullName.isNotEmpty
                      ? child.fullName.characters.first
                      : 'S',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (child.relationship != null &&
                        child.relationship!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          context.l10n.relationshipLabel(child.relationship!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: AppSpacing.s4),
                    Text(
                      context.l10n.currentStudentBadge,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Multiple children switcher (P-02)
    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.school_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                context.l10n.selectChildToMonitor,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  context.l10n.enrolledChildrenCount(children.length),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: children.map((child) {
                final isSelected = child.id == selectedChild.id;

                return Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.s8),
                  child: ChoiceChip(
                    avatar: CircleAvatar(
                      backgroundColor: isSelected
                          ? Colors.white
                          : AppColors.primary.withValues(alpha: 0.12),
                      child: Text(
                        child.fullName.isNotEmpty
                            ? child.fullName.characters.first
                            : 'S',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.primary,
                        ),
                      ),
                    ),
                    label: Text(child.fullName),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        onChildSelected(child);
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
