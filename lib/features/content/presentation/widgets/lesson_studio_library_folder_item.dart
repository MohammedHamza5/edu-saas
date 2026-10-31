import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../videos/domain/entities/library_video_entity.dart';
import '../../../videos/domain/entities/video_folder_entity.dart';

/// Folder header and expandable video subtree in the library sidebar tree.
class LessonStudioLibraryFolderItem extends StatelessWidget {
  final VideoFolderEntity folder;
  final bool isExpanded;
  final bool isLoading;
  final bool? triState;
  final List<LibraryVideoEntity> filteredVideos;
  final int totalVideosCount;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleCheckbox;
  final Widget Function(BuildContext context, LibraryVideoEntity video) videoRowBuilder;

  const LessonStudioLibraryFolderItem({
    super.key,
    required this.folder,
    required this.isExpanded,
    required this.isLoading,
    required this.triState,
    required this.filteredVideos,
    required this.totalVideosCount,
    required this.onToggleExpand,
    required this.onToggleCheckbox,
    required this.videoRowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onToggleExpand,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                // Expand Icon
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),

                // Folder Tri-State Checkbox
                Checkbox(
                  value: triState,
                  tristate: true,
                  visualDensity: VisualDensity.compact,
                  onChanged: (_) => onToggleCheckbox(),
                ),
                const SizedBox(width: 4),

                // Folder Color Dot / Icon
                Icon(
                  Icons.folder_rounded,
                  size: 18,
                  color: folder.color != null
                      ? Color(
                          int.parse(folder.color!.replaceFirst('#', '0xFF')),
                        )
                      : AppColors.primary,
                ),
                const SizedBox(width: 8),

                // Folder Name + Count
                Expanded(
                  child: Text(
                    folder.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isLoading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    '$totalVideosCount',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Subtree (Videos in folder)
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 20, right: 8),
            child: totalVideosCount == 0 && !isLoading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        l10n.noVideosInFolder,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final video in filteredVideos)
                        videoRowBuilder(context, video),
                    ],
                  ),
          ),
      ],
    );
  }
}
