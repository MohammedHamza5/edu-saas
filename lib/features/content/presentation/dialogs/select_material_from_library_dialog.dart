import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/pdf_launcher_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../videos/presentation/utils/folder_color_palette.dart';
import '../../domain/entities/library_material_entity.dart';
import '../cubit/materials_library_cubit.dart';
import '../cubit/materials_library_state.dart';
import 'material_folder_dialogs.dart';

class SelectMaterialFromLibraryDialog extends StatefulWidget {
  const SelectMaterialFromLibraryDialog({super.key});

  static Future<LibraryMaterialEntity?> show(BuildContext context) {
    return showDialog<LibraryMaterialEntity>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => BlocProvider(
        create: (_) =>
            InjectionContainer.createMaterialsLibraryCubit()..loadFolder(),
        child: const SelectMaterialFromLibraryDialog(),
      ),
    );
  }

  @override
  State<SelectMaterialFromLibraryDialog> createState() =>
      _SelectMaterialFromLibraryDialogState();
}

class _SelectMaterialFromLibraryDialogState
    extends State<SelectMaterialFromLibraryDialog> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      unawaited(context.read<MaterialsLibraryCubit>().loadMoreMaterials());
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<MaterialsLibraryCubit>().search(query);
      }
    });
  }

  Future<void> _handleCreateFolder() async {
    final result = await CreateMaterialFolderDialog.show(context);
    if (result != null && result.name.trim().isNotEmpty && mounted) {
      final success = await context
          .read<MaterialsLibraryCubit>()
          .createFolder(result.name, color: result.color);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.savingChanges),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
  }

  Future<void> _previewMaterial(LibraryMaterialEntity material) async {
    try {
      final signedUrlRes = await InjectionContainer.materialsLibraryRepository
          .getSignedUrl(
        material.storagePath,
        storageProvider: material.storageProvider,
      );
      if (signedUrlRes.isSuccess && signedUrlRes.dataOrNull != null && mounted) {
        final url = signedUrlRes.dataOrNull!;
        await PdfLauncherHelper.launchPdfUrl(url, context: context);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: const Icon(
                      Icons.folder_shared_rounded,
                      color: Color(0xFFEA580C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.selectFromMaterialsLibrary,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.selectFromMaterialsLibrarySubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Search & Actions Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: l10n.materialsSearchHint,
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  context
                                      .read<MaterialsLibraryCubit>()
                                      .search('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor:
                            AppColors.surfaceVariant.withValues(alpha: 0.35),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusMedium),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                    label: Text(l10n.createNewFolderAction),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s14,
                        vertical: AppSpacing.s12,
                      ),
                    ),
                    onPressed: _handleCreateFolder,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // Breadcrumbs Bar
              BlocBuilder<MaterialsLibraryCubit, MaterialsLibraryState>(
                builder: (context, state) {
                  final trail = state.breadcrumbs;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.25),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
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
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.home_outlined,
                                    size: 16,
                                    color: Color(0xFFEA580C),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l10n.rootMaterialsTitle,
                                    style: const TextStyle(
                                      fontSize: 12,
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
                              size: 16,
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
                                  vertical: 2,
                                ),
                                child: Text(
                                  trail[i].name,
                                  style: TextStyle(
                                    fontSize: 12,
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
              ),
              const SizedBox(height: AppSpacing.s12),

              // Body: Folders & Materials
              Expanded(
                child:
                    BlocBuilder<MaterialsLibraryCubit, MaterialsLibraryState>(
                  builder: (context, state) {
                    if (state.isLoading &&
                        state.folders.isEmpty &&
                        state.materials.isEmpty) {
                      return const Center(child: AppLoadingView());
                    }

                    if (state.hasError &&
                        state.folders.isEmpty &&
                        state.materials.isEmpty) {
                      return AppErrorView(
                        message: state.errorMessage,
                        onRetry: () =>
                            context.read<MaterialsLibraryCubit>().loadFolder(
                                  folder: state.currentFolder,
                                ),
                      );
                    }

                    if (state.isEmpty) {
                      return AppEmptyView(
                        message: l10n.noMaterialsFound,
                        subtitle: l10n.noMaterialsFoundSubtitle,
                        icon: Icons.folder_open_rounded,
                      );
                    }

                    return CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        // Folders Grid Section
                        if (state.folders.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.s10,
                                top: AppSpacing.s4,
                              ),
                              child: Text(
                                '${state.folders.length} ${l10n.groupsListTitle}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          SliverGrid(
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 210,
                              mainAxisExtent: 68,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final folder = state.folders[index];
                                final folderColor =
                                    FolderColorPalette.getFolderColor(
                                        folder.color);

                                return InkWell(
                                  onTap: () => context
                                      .read<MaterialsLibraryCubit>()
                                      .loadFolder(folder: folder),
                                  borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusMedium),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                        AppSpacing.s10),
                                    decoration: BoxDecoration(
                                      color: folderColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusMedium),
                                      border: Border.all(
                                        color:
                                            folderColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.folder_rounded,
                                          color: folderColor,
                                          size: 28,
                                        ),
                                        const SizedBox(width: AppSpacing.s8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                folder.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                              Text(
                                                l10n.folderFilesCount(
                                                    folder.filesCount),
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          size: 16,
                                          color: AppColors.textSecondary,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              childCount: state.folders.length,
                            ),
                          ),
                          const SliverToBoxAdapter(
                            child: SizedBox(height: AppSpacing.s16),
                          ),
                        ],

                        // Files List / Grid Section
                        if (state.materials.isNotEmpty) ...[
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s10),
                              child: Text(
                                l10n.folderFilesCount(state.materials.length),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final item = state.materials[index];
                                return _buildMaterialListCard(
                                    context, item, l10n);
                              },
                              childCount: state.materials.length,
                            ),
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
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialListCard(
    BuildContext context,
    LibraryMaterialEntity item,
    AppLocalizations l10n,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.s8),
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Icon badge
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: item.isPdf
                  ? Colors.red.withValues(alpha: 0.12)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            ),
            child: Icon(
              item.isPdf
                  ? Icons.picture_as_pdf_rounded
                  : Icons.description_rounded,
              color: item.isPdf ? Colors.redAccent : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),

          // File Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.formattedFileSize,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: AppColors.textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (item.isAssigned) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          l10n.usedInLecturesCount(item.assignedLecturesCount),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else ...[
                      Text(
                        l10n.unusedMaterial,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s8),

          // Actions
          IconButton(
            icon: const Icon(Icons.remove_red_eye_outlined, size: 20),
            tooltip: l10n.previewMaterialAction,
            color: AppColors.textSecondary,
            onPressed: () => _previewMaterial(item),
          ),
          const SizedBox(width: AppSpacing.s6),
          AppButton(
            text: l10n.selectMaterialAction,
            icon: Icons.check_circle_outline_rounded,
            onPressed: () => Navigator.of(context).pop(item),
          ),
        ],
      ),
    );
  }
}
