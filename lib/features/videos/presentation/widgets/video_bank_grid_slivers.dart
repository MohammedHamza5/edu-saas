import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../domain/entities/library_video_entity.dart';
import '../../domain/entities/video_folder_entity.dart';
import 'video_bank_cards.dart';

/// Sliver grid for displaying folders in the video bank.
class VideoBankFoldersGridSliver extends StatelessWidget {
  final List<VideoFolderEntity> folders;
  final bool isMobile;
  final double hPadding;
  final ValueChanged<VideoFolderEntity> onOpen;
  final ValueChanged<VideoFolderEntity> onAssignAsChapter;
  final ValueChanged<VideoFolderEntity> onChangeColor;
  final ValueChanged<VideoFolderEntity> onRename;
  final ValueChanged<VideoFolderEntity> onDelete;

  const VideoBankFoldersGridSliver({
    super.key,
    required this.folders,
    required this.isMobile,
    required this.hPadding,
    required this.onOpen,
    required this.onAssignAsChapter,
    required this.onChangeColor,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: isMobile ? 600 : 380,
          mainAxisSpacing: AppSpacing.s12,
          crossAxisSpacing: AppSpacing.s12,
          mainAxisExtent: isMobile ? 120 : 116,
        ),
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final f = folders[i];
          return VideoBankFolderCard(
            key: ValueKey('folder_${f.id}'),
            folder: f,
            onOpen: () => onOpen(f),
            onAssignAsChapter: () => onAssignAsChapter(f),
            onChangeColor: () => onChangeColor(f),
            onRename: () => onRename(f),
            onDelete: () => onDelete(f),
          );
        }, childCount: folders.length),
      ),
    );
  }
}

/// Sliver grid for displaying video cards in the video bank,
/// including empty states and pagination loading indicator.
class VideoBankVideosGridSliver extends StatelessWidget {
  final List<LibraryVideoEntity> filteredVideos;
  final bool hasFolders;
  final double hPadding;
  final String? currentFolderName;
  final bool isLoadingMore;
  final ValueChanged<LibraryVideoEntity> onPreview;
  final ValueChanged<LibraryVideoEntity> onAddToCourse;
  final ValueChanged<LibraryVideoEntity> onMove;
  final ValueChanged<LibraryVideoEntity> onRename;
  final ValueChanged<LibraryVideoEntity> onDelete;
  final ValueChanged<LibraryVideoEntity> onSync;
  final VoidCallback onUploadVideo;

  const VideoBankVideosGridSliver({
    super.key,
    required this.filteredVideos,
    required this.hasFolders,
    required this.hPadding,
    required this.currentFolderName,
    required this.isLoadingMore,
    required this.onPreview,
    required this.onAddToCourse,
    required this.onMove,
    required this.onRename,
    required this.onDelete,
    required this.onSync,
    required this.onUploadVideo,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    if (filteredVideos.isEmpty && !hasFolders) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppEmptyView(
          icon: Icons.video_library_outlined,
          message: l10n.noVideosInFolder,
          actionText: l10n.uploadToBank,
          onAction: onUploadVideo,
        ),
      );
    }

    if (filteredVideos.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: hPadding),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 360,
          mainAxisSpacing: AppSpacing.s16,
          crossAxisSpacing: AppSpacing.s16,
          mainAxisExtent: 360,
        ),
        delegate: SliverChildBuilderDelegate((ctx, i) {
          final v = filteredVideos[i];
          return VideoBankVideoCard(
            key: ValueKey('lib_${v.id}'),
            video: v,
            onPreview: () => onPreview(v),
            onAddToCourse: () => onAddToCourse(v),
            onMove: () => onMove(v),
            onRename: () => onRename(v),
            onDelete: () => onDelete(v),
            onSync: () => onSync(v),
          );
        }, childCount: filteredVideos.length),
      ),
    );
  }
}
