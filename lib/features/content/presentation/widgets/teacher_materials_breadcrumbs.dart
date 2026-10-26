import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/materials_library_cubit.dart';
import '../cubit/materials_library_state.dart';

/// Horizontal breadcrumbs navigation bar displaying root and nested folder hierarchy.
class TeacherMaterialsBreadcrumbs extends StatelessWidget {
  const TeacherMaterialsBreadcrumbs({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<MaterialsLibraryCubit, MaterialsLibraryState>(
      buildWhen: (prev, curr) => prev.breadcrumbs != curr.breadcrumbs,
      builder: (context, state) {
        final trail = state.breadcrumbs;

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                InkWell(
                  onTap: () => context
                      .read<MaterialsLibraryCubit>()
                      .navigateToBreadcrumb(-1),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.home_outlined,
                          size: 18,
                          color: Color(0xFFEA580C),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.rootMaterialsTitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFEA580C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                for (int i = 0; i < trail.length; i++) ...[
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  InkWell(
                    onTap: () => context
                        .read<MaterialsLibraryCubit>()
                        .navigateToBreadcrumb(i),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Text(
                        trail[i].name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: i == trail.length - 1
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: i == trail.length - 1
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
