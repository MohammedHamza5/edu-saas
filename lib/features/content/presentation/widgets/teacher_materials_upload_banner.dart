import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/materials_library_cubit.dart';
import '../cubit/materials_library_state.dart';

/// Active upload progress banner with percentage indicator and filename display.
class TeacherMaterialsUploadBanner extends StatelessWidget {
  const TeacherMaterialsUploadBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<MaterialsLibraryCubit, MaterialsLibraryState>(
      buildWhen: (prev, curr) =>
          prev.isUploading != curr.isUploading ||
          prev.uploadProgress != curr.uploadProgress ||
          prev.uploadingFileName != curr.uploadingFileName ||
          prev.uploadCurrentIndex != curr.uploadCurrentIndex,
      builder: (context, state) {
        if (!state.isUploading) return const SizedBox.shrink();

        final fileName = state.uploadingFileName ?? '';
        final cur = state.uploadCurrentIndex > 0 ? state.uploadCurrentIndex : 1;
        final total = state.uploadTotalFiles > 0 ? state.uploadTotalFiles : 1;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.s12),
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  Expanded(
                    child: Text(
                      total > 1
                          ? l10n.uploadingFileProgress(cur, total, fileName)
                          : l10n.uploadingFilesTitle +
                              (fileName.isNotEmpty ? ': $fileName' : '...'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppColors.primary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(state.uploadProgress * 100).toInt()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: state.uploadProgress > 0 ? state.uploadProgress : null,
                  minHeight: 5,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
