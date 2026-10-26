import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../content/domain/entities/content_entity.dart';
import '../../../content/domain/entities/file_attachment_entity.dart';
import '../../../content/presentation/widgets/material_viewer_sheet.dart';
import '../cubit/videos_cubit.dart';
import '../../domain/entities/video_entity.dart';

class VideoAttachedMaterialCard extends StatelessWidget {
  final VideoEntity? video;
  final bool isTeacher;
  final String? groupId;
  final String? groupPdfStoragePath;
  final String? groupPdfFileName;
  final bool isAttachingPdf;
  final bool isOpeningPdf;
  final String? preloadedPdfPath;
  final String? preloadedPdfUrl;
  final void Function(VideoEntity video) onOpenMaterial;
  final void Function(VideoEntity? currentVideo, {required bool hasGroupPdf}) onOpenPdfDirectly;
  final void Function(VideoEntity video) onPickAndAttachPdf;

  const VideoAttachedMaterialCard({
    super.key,
    required this.video,
    required this.isTeacher,
    this.groupId,
    this.groupPdfStoragePath,
    this.groupPdfFileName,
    this.isAttachingPdf = false,
    this.isOpeningPdf = false,
    this.preloadedPdfPath,
    this.preloadedPdfUrl,
    required this.onOpenMaterial,
    required this.onOpenPdfDirectly,
    required this.onPickAndAttachPdf,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentVideo = video;
    // 1. الأولوية للـ PDF الخاص بالمجموعة (إذا دخلنا من group course)
    final hasGroupPdf =
        groupPdfStoragePath != null && groupPdfFileName != null;

    // 2. الـ PDF الافتراضي المربوط بالفيديو نفسه
    final attachedFile = video?.attachedFile;

    if (!hasGroupPdf && attachedFile == null && !isTeacher) {
      return const SizedBox.shrink();
    }

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Title + PDF Tag
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  context.l10n.attachedLessonMaterial,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withAlpha(20),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  border: Border.all(
                    color: const Color(0xFFEA580C).withAlpha(60),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 11,
                      color: Color(0xFFEA580C),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'PDF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFEA580C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 4),
          Text(
            context.l10n.attachedLessonMaterialSubtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.s12),

          if (hasGroupPdf || attachedFile != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withAlpha(25),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border.withAlpha(70)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withAlpha(20),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: const Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 22,
                      color: Color(0xFFEA580C),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasGroupPdf
                              ? groupPdfFileName!
                              : (attachedFile?.fileName ?? 'Study Material'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasGroupPdf
                              ? 'PDF'
                              : '${attachedFile?.formattedFileSize ?? ''} • PDF',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                    label: Flexible(
                      child: Text(
                        context.l10n.openPdfAction,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.s12,
                        horizontal: AppSpacing.s16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                      ),
                    ),
                    onPressed: () {
                      if (hasGroupPdf) {
                        // فتح PDF المجموعة
                        final contentWrapper = ContentEntity(
                          id: currentVideo!.contentId,
                          tenantId: '',
                          groupId: groupId ?? '',
                          title: currentVideo.title ?? groupPdfFileName!,
                          description: currentVideo.description,
                          type: ContentType.pdf,
                          status: ContentStatus.published,
                          file: FileAttachmentEntity(
                            id: '',
                            tenantId: '',
                            contentId: currentVideo.contentId,
                            storagePath: groupPdfStoragePath!,
                            fileName: groupPdfFileName!,
                            mimeType: 'application/pdf',
                            fileSize: 0,
                            createdAt: currentVideo.createdAt,
                          ),
                          createdAt: currentVideo.createdAt,
                          updatedAt: currentVideo.updatedAt,
                        );
                        final cubit = context.read<VideosCubit>();
                        MaterialViewerSheet.show(
                          context,
                          content: contentWrapper,
                          onGetSignedUrl: (path) async {
                            final effectivePath =
                                path.isNotEmpty ? path : groupPdfStoragePath!;
                            if (preloadedPdfPath == effectivePath &&
                                preloadedPdfUrl != null) {
                              return preloadedPdfUrl!;
                            }
                            return cubit.getSignedFileUrl(effectivePath);
                          },
                        );
                      } else {
                        onOpenMaterial(currentVideo!);
                      }
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Tooltip(
                  message: context.l10n.openPdfInNewTabTooltip,
                  child: Material(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      onTap: isOpeningPdf
                          ? null
                          : () => onOpenPdfDirectly(
                              currentVideo,
                              hasGroupPdf: hasGroupPdf,
                            ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s12,
                          horizontal: AppSpacing.s14,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isOpeningPdf)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              )
                            else
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (isTeacher) ...[
              const SizedBox(height: AppSpacing.s8),
              OutlinedButton.icon(
                icon: isAttachingPdf
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded, size: 15),
                label: Flexible(
                  child: Text(
                    context.l10n.attachPdfToLessonAction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                onPressed: isAttachingPdf
                    ? null
                    : () => onPickAndAttachPdf(currentVideo!),
              ),
            ],
          ] else if (isTeacher) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withAlpha(20),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: AppColors.border.withAlpha(80),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.note_add_outlined,
                    size: 32,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Text(
                    context.l10n.noAttachedMaterialForLesson,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: isAttachingPdf
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.upload_file_rounded, size: 16),
                      label: Text(context.l10n.attachPdfToLessonAction),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s10,
                        ),
                      ),
                      onPressed: isAttachingPdf
                          ? null
                          : () => onPickAndAttachPdf(currentVideo!),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


}
