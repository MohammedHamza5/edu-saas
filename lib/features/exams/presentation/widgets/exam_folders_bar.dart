import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../domain/entities/exam_folder_entity.dart';
import 'exam_folder_dialogs.dart';

class ExamFoldersBar extends StatelessWidget {
  final List<ExamFolderEntity> folders;
  final String? selectedFolderId;
  final int totalExamsCount;
  final int uncategorizedCount;
  final ValueChanged<String?> onSelectFolder;
  final VoidCallback onCreateFolder;
  final ValueChanged<ExamFolderEntity> onEditFolder;
  final ValueChanged<ExamFolderEntity> onDeleteFolder;

  const ExamFoldersBar({
    super.key,
    required this.folders,
    required this.selectedFolderId,
    required this.totalExamsCount,
    required this.uncategorizedCount,
    required this.onSelectFolder,
    required this.onCreateFolder,
    required this.onEditFolder,
    required this.onDeleteFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
        children: [
          // 1. "All Exams" chip
          _buildFilterChip(
            context,
            isSelected: selectedFolderId == null,
            label: context.l10n.allExamsTab,
            count: totalExamsCount,
            icon: Icons.grid_view_rounded,
            onTap: () => onSelectFolder(null),
          ),
          const SizedBox(width: AppSpacing.s8),

          // 2. Folders chips
          ...folders.map((folder) {
            final isSelected = selectedFolderId == folder.id;
            final fColor = parseHexColor(folder.color);

            return Padding(
              padding: const EdgeInsetsDirectional.only(end: AppSpacing.s8),
              child: InkWell(
                onTap: () => onSelectFolder(folder.id),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? fColor.withValues(alpha: 0.18)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    border: Border.all(
                      color: isSelected
                          ? fColor
                          : AppColors.border.withValues(alpha: 0.8),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: fColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        folder.name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? fColor : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? fColor.withValues(alpha: 0.25)
                              : AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${folder.examCount}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? fColor : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Folder menu
                      PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          size: 14,
                          color: isSelected ? fColor : AppColors.textSecondary,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: '',
                        itemBuilder: (ctx) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                const Icon(Icons.edit_outlined, size: 16),
                                const SizedBox(width: 8),
                                Text(ctx.l10n.editFolderAction),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.delete_outline,
                                  size: 16,
                                  color: AppColors.error,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  ctx.l10n.deleteFolderAction,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onSelected: (val) {
                          if (val == 'edit') {
                            onEditFolder(folder);
                          } else if (val == 'delete') {
                            onDeleteFolder(folder);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // 3. "Uncategorized" chip (if any exams exist without a folder)
          if (uncategorizedCount > 0 || selectedFolderId == 'uncategorized') ...[
            _buildFilterChip(
              context,
              isSelected: selectedFolderId == 'uncategorized',
              label: context.l10n.uncategorizedFolder,
              count: uncategorizedCount,
              icon: Icons.folder_off_outlined,
              onTap: () => onSelectFolder('uncategorized'),
            ),
            const SizedBox(width: AppSpacing.s8),
          ],

          // 4. "New Folder" action chip
          ActionChip(
            avatar: const Icon(
              Icons.add_rounded,
              size: 16,
              color: AppColors.primary,
            ),
            label: Text(
              context.l10n.newFolderAction,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            backgroundColor: AppColors.primary.withValues(alpha: 0.08),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.3),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            onPressed: onCreateFolder,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required bool isSelected,
    required String label,
    required int count,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s6,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border.withValues(alpha: 0.8),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
