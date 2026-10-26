import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../cubit/materials_library_cubit.dart';
import '../cubit/materials_library_state.dart';

/// Responsive header banner for Materials Library with folder creation and upload actions.
class TeacherMaterialsHeader extends StatelessWidget {
  final VoidCallback onCreateFolder;
  final VoidCallback onUploadFiles;

  const TeacherMaterialsHeader({
    super.key,
    required this.onCreateFolder,
    required this.onUploadFiles,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 680;

        final folderIcon = Container(
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: const Color(0xFFEA580C).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          ),
          child: Icon(
            Icons.folder_shared_rounded,
            color: const Color(0xFFEA580C),
            size: isNarrow ? 26 : 28,
          ),
        );

        final titleSection = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.materialsLibraryTitle,
              style: (isNarrow
                      ? theme.textTheme.titleLarge
                      : theme.textTheme.headlineSmall)
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.materialsLibrarySubtitle,
              style: (isNarrow
                      ? theme.textTheme.bodySmall
                      : theme.textTheme.bodyMedium)
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        );

        final actions = [
          OutlinedButton.icon(
            icon: Icon(
              Icons.create_new_folder_outlined,
              size: isNarrow ? 18 : 20,
            ),
            label: Text(l10n.createNewFolderAction),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? AppSpacing.s14 : AppSpacing.s16,
                vertical: isNarrow ? AppSpacing.s12 : AppSpacing.s14,
              ),
            ),
            onPressed: onCreateFolder,
          ),
          BlocBuilder<MaterialsLibraryCubit, MaterialsLibraryState>(
            buildWhen: (prev, curr) => prev.isUploading != curr.isUploading,
            builder: (context, state) {
              return AppButton(
                text: l10n.uploadMaterialAction,
                icon: Icons.upload_file_rounded,
                isLoading: state.isUploading,
                onPressed: state.isUploading ? null : onUploadFiles,
              );
            },
          ),
        ];

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  folderIcon,
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(child: titleSection),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: actions,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            folderIcon,
            const SizedBox(width: AppSpacing.s16),
            Expanded(child: titleSection),
            const SizedBox(width: AppSpacing.s12),
            actions[0],
            const SizedBox(width: AppSpacing.s10),
            actions[1],
          ],
        );
      },
    );
  }
}
