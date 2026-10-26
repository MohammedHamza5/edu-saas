import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/library_material_entity.dart';
import '../../domain/entities/material_folder_entity.dart';
import '../cubit/materials_library_state.dart';
import 'teacher_folder_grid_card.dart';
import 'teacher_material_item_card.dart';

/// Renders the folders grid and paginated materials list using CustomScrollView slivers.
class TeacherMaterialsSliversView extends StatelessWidget {
  final ScrollController scrollController;
  final MaterialsLibraryState state;
  final ValueChanged<MaterialFolderEntity> onFolderTap;
  final ValueChanged<MaterialFolderEntity> onEditFolder;
  final ValueChanged<MaterialFolderEntity> onDeleteFolder;
  final ValueChanged<LibraryMaterialEntity> onPreviewMaterial;
  final ValueChanged<LibraryMaterialEntity> onRenameMaterial;
  final ValueChanged<LibraryMaterialEntity> onMoveMaterial;
  final ValueChanged<LibraryMaterialEntity> onDeleteMaterial;

  const TeacherMaterialsSliversView({
    super.key,
    required this.scrollController,
    required this.state,
    required this.onFolderTap,
    required this.onEditFolder,
    required this.onDeleteFolder,
    required this.onPreviewMaterial,
    required this.onRenameMaterial,
    required this.onMoveMaterial,
    required this.onDeleteMaterial,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        // Folders Grid Section
        if (state.folders.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.s12,
                top: AppSpacing.s4,
              ),
              child: Text(
                l10n.folderCount(state.folders.length),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisExtent: 80,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final folder = state.folders[index];
              return TeacherFolderGridCard(
                folder: folder,
                onTap: () => onFolderTap(folder),
                onEdit: () => onEditFolder(folder),
                onDelete: () => onDeleteFolder(folder),
              );
            }, childCount: state.folders.length),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: AppSpacing.s24),
          ),
        ],

        // Materials List Section
        if (state.materials.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: Text(
                l10n.folderFilesCount(state.materials.length),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = state.materials[index];
              return TeacherMaterialItemCard(
                item: item,
                onPreview: () => onPreviewMaterial(item),
                onRename: () => onRenameMaterial(item),
                onMove: () => onMoveMaterial(item),
                onDelete: () => onDeleteMaterial(item),
              );
            }, childCount: state.materials.length),
          ),
        ],

        if (state.hasMoreMaterials)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.s16),
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
