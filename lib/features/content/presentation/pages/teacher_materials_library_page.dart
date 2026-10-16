import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/pdf_launcher_helper.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../videos/presentation/utils/folder_color_palette.dart';
import '../../domain/entities/library_material_entity.dart';
import '../../domain/entities/material_folder_entity.dart';
import '../cubit/materials_library_cubit.dart';
import '../cubit/materials_library_state.dart';
import '../dialogs/material_folder_dialogs.dart';

class TeacherMaterialsLibraryPage extends StatelessWidget {
  const TeacherMaterialsLibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          InjectionContainer.createMaterialsLibraryCubit()..loadFolder(),
      child: const _TeacherMaterialsLibraryView(),
    );
  }
}

class _TeacherMaterialsLibraryView extends StatefulWidget {
  const _TeacherMaterialsLibraryView();

  @override
  State<_TeacherMaterialsLibraryView> createState() =>
      _TeacherMaterialsLibraryViewState();
}

class _TeacherMaterialsLibraryViewState
    extends State<_TeacherMaterialsLibraryView> {
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
      final success = await context.read<MaterialsLibraryCubit>().createFolder(
        result.name,
        color: result.color,
      );
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

  Future<void> _handleEditFolder(MaterialFolderEntity folder) async {
    final result = await CreateMaterialFolderDialog.show(
      context,
      initialName: folder.name,
      initialColor: folder.color,
      isEditing: true,
    );
    if (result != null && result.name.trim().isNotEmpty && mounted) {
      await context.read<MaterialsLibraryCubit>().updateFolder(
        folder.id,
        result.name,
        color: result.color,
      );
    }
  }

  Future<void> _handleDeleteFolder(MaterialFolderEntity folder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmDeleteFolderTitle),
        content: Text(context.l10n.confirmDeleteFolderMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<MaterialsLibraryCubit>().deleteFolder(folder.id);
    }
  }

  Future<void> _handleUploadFiles() async {
    final cubit = context.read<MaterialsLibraryCubit>();
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );

      if (res == null || res.files.isEmpty || !mounted) return;

      final totalFiles = res.files.length;
      int addedCount = 0;
      int duplicateCount = 0;
      final failedFiles = <String>[];

      for (int i = 0; i < totalFiles; i++) {
        final file = res.files[i];
        if (file.bytes == null) continue;

        if (mounted) {
          cubit.updateUploadStatus(
            isUploading: true,
            progress: (i + 1) / totalFiles,
            fileName: file.name,
            totalFiles: totalFiles,
            currentIndex: i + 1,
          );
        }

        try {
          final item = await cubit.uploadMaterial(
            title: file.name.replaceAll(
              RegExp(r'\.pdf$', caseSensitive: false),
              '',
            ),
            fileName: file.name,
            fileBytes: file.bytes!,
            mimeType: 'application/pdf',
          );

          if (item != null) {
            if (item.createdAt.difference(DateTime.now()).inSeconds.abs() >
                30) {
              duplicateCount++;
            } else {
              addedCount++;
            }
          } else {
            failedFiles.add(file.name);
          }
        } catch (e) {
          failedFiles.add(file.name);
        }
      }

      if (mounted) {
        cubit.updateUploadStatus(
          isUploading: false,
          progress: 1.0,
          totalFiles: totalFiles,
          currentIndex: totalFiles,
        );

        if (failedFiles.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text(
                context.l10n.uploadMaterialError(
                  failedFiles.join(', '),
                  context.l10n.errorOccurred,
                ),
              ),
              duration: const Duration(seconds: 4),
            ),
          );
        } else if (duplicateCount > 0 && addedCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.primary,
              content: Text(context.l10n.materialDuplicateNotice),
              duration: const Duration(seconds: 3),
            ),
          );
        } else if (addedCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Text(
                context.l10n.uploadMaterialSuccess(
                  totalFiles == 1 ? res.files.first.name : '$addedCount files',
                ),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        cubit.updateUploadStatus(isUploading: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text(
              context.l10n.uploadMaterialError('File', e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleRenameMaterial(LibraryMaterialEntity item) async {
    final newTitle = await RenameMaterialDialog.show(
      context,
      currentTitle: item.title,
    );
    if (newTitle != null && newTitle.isNotEmpty && mounted) {
      await context.read<MaterialsLibraryCubit>().updateMaterial(
        item.id,
        newTitle,
      );
    }
  }

  Future<void> _handleMoveMaterial(LibraryMaterialEntity item) async {
    final allFoldersRes = await InjectionContainer.materialsLibraryRepository
        .getAllFolders();
    final allFolders = allFoldersRes.dataOrNull ?? [];

    if (!mounted) return;
    final targetFolderId = await MoveMaterialDialog.show(
      context,
      currentFolderId: item.folderId,
      folders: allFolders,
    );

    if (targetFolderId != null && mounted) {
      await context.read<MaterialsLibraryCubit>().moveMaterial(
        item.id,
        targetFolderId.isEmpty ? null : targetFolderId,
      );
    }
  }

  Future<void> _handleDeleteMaterial(LibraryMaterialEntity item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.confirmDeleteMaterialTitle),
        content: Text(context.l10n.confirmDeleteMaterialMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.cancelAction),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<MaterialsLibraryCubit>().deleteMaterial(item.id);
    }
  }

  Future<void> _previewMaterial(LibraryMaterialEntity item) async {
    try {
      final res = await InjectionContainer.materialsLibraryRepository
          .getSignedUrl(
            item.storagePath,
            storageProvider: item.storageProvider,
          );
      if (res.isSuccess && res.dataOrNull != null) {
        if (!mounted || !context.mounted) return;
        await PdfLauncherHelper.launchPdfUrl(res.dataOrNull!, context: context);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ResponsiveContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Page Header (Responsive LayoutBuilder)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 680;
                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.s12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEA580C)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.folder_shared_rounded,
                                  color: Color(0xFFEA580C),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.materialsLibraryTitle,
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      l10n.materialsLibrarySubtitle,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Wrap(
                            spacing: AppSpacing.s8,
                            runSpacing: AppSpacing.s8,
                            children: [
                              OutlinedButton.icon(
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                  size: 18,
                                ),
                                label: Text(l10n.createNewFolderAction),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.s14,
                                    vertical: AppSpacing.s12,
                                  ),
                                ),
                                onPressed: _handleCreateFolder,
                              ),
                              BlocBuilder<MaterialsLibraryCubit,
                                  MaterialsLibraryState>(
                                buildWhen: (prev, curr) =>
                                    prev.isUploading != curr.isUploading,
                                builder: (context, state) {
                                  return AppButton(
                                    text: l10n.uploadMaterialAction,
                                    icon: Icons.upload_file_rounded,
                                    isLoading: state.isUploading,
                                    onPressed: state.isUploading
                                        ? null
                                        : _handleUploadFiles,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.s12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEA580C)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                          child: const Icon(
                            Icons.folder_shared_rounded,
                            color: Color(0xFFEA580C),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.materialsLibraryTitle,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.materialsLibrarySubtitle,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        OutlinedButton.icon(
                          icon: const Icon(
                            Icons.create_new_folder_outlined,
                            size: 20,
                          ),
                          label: Text(l10n.createNewFolderAction),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s16,
                              vertical: AppSpacing.s14,
                            ),
                          ),
                          onPressed: _handleCreateFolder,
                        ),
                        const SizedBox(width: AppSpacing.s10),
                        BlocBuilder<MaterialsLibraryCubit,
                            MaterialsLibraryState>(
                          buildWhen: (prev, curr) =>
                              prev.isUploading != curr.isUploading,
                          builder: (context, state) {
                            return AppButton(
                              text: l10n.uploadMaterialAction,
                              icon: Icons.upload_file_rounded,
                              isLoading: state.isUploading,
                              onPressed: state.isUploading
                                  ? null
                                  : _handleUploadFiles,
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s20),

                // Search & Filter Bar (Responsive LayoutBuilder)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isFilterNarrow = constraints.maxWidth < 540;
                    final filterChips = BlocBuilder<MaterialsLibraryCubit,
                        MaterialsLibraryState>(
                      buildWhen: (prev, curr) =>
                          prev.mimeTypeFilter != curr.mimeTypeFilter,
                      builder: (context, state) {
                        return Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: Text(l10n.allMaterialsFilter),
                              selected: state.mimeTypeFilter == null,
                              onSelected: (_) => context
                                  .read<MaterialsLibraryCubit>()
                                  .setFilter(null),
                            ),
                            ChoiceChip(
                              label: Text(l10n.pdfFilesFilter),
                              selected: state.mimeTypeFilter == 'pdf',
                              onSelected: (_) => context
                                  .read<MaterialsLibraryCubit>()
                                  .setFilter('pdf'),
                            ),
                          ],
                        );
                      },
                    );

                    final searchField = TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: l10n.materialsSearchHint,
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 22,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  context
                                      .read<MaterialsLibraryCubit>()
                                      .search('');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMedium,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMedium,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.border,
                          ),
                        ),
                      ),
                    );

                    if (isFilterNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          searchField,
                          const SizedBox(height: AppSpacing.s10),
                          filterChips,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: searchField),
                        const SizedBox(width: AppSpacing.s12),
                        filterChips,
                      ],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.s12),

                // Breadcrumbs Bar
                BlocBuilder<MaterialsLibraryCubit, MaterialsLibraryState>(
                  builder: (context, state) {
                    final trail = state.breadcrumbs;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
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
                ),
                const SizedBox(height: AppSpacing.s12),

                // Active Upload Status Banner
                BlocBuilder<MaterialsLibraryCubit, MaterialsLibraryState>(
                  buildWhen: (prev, curr) =>
                      prev.isUploading != curr.isUploading ||
                      prev.uploadProgress != curr.uploadProgress ||
                      prev.uploadingFileName != curr.uploadingFileName ||
                      prev.uploadCurrentIndex != curr.uploadCurrentIndex,
                  builder: (context, state) {
                    if (!state.isUploading) return const SizedBox.shrink();

                    final fileName = state.uploadingFileName ?? '';
                    final cur = state.uploadCurrentIndex > 0
                        ? state.uploadCurrentIndex
                        : 1;
                    final total = state.uploadTotalFiles > 0
                        ? state.uploadTotalFiles
                        : 1;

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
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
                                      ? l10n.uploadingFileProgress(
                                          cur,
                                          total,
                                          fileName,
                                        )
                                      : l10n.uploadingFilesTitle +
                                          (fileName.isNotEmpty
                                              ? ': $fileName'
                                              : '...'),
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
                              value: state.uploadProgress > 0
                                  ? state.uploadProgress
                                  : null,
                              minHeight: 5,
                              backgroundColor:
                                  AppColors.primary.withValues(alpha: 0.15),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Main Content View
                Expanded(
                  child: BlocBuilder<MaterialsLibraryCubit, MaterialsLibraryState>(
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
                          onRetry: () => context
                              .read<MaterialsLibraryCubit>()
                              .loadFolder(folder: state.currentFolder),
                        );
                      }

                      if (state.isEmpty) {
                        return AppEmptyView(
                          message: l10n.noMaterialsFound,
                          subtitle: l10n.noMaterialsFoundSubtitle,
                          icon: Icons.folder_open_rounded,
                          actionText: l10n.uploadMaterialAction,
                          onAction: _handleUploadFiles,
                        );
                      }

                      return CustomScrollView(
                        controller: _scrollController,
                        slivers: [
                          // Folders Section
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
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 260,
                                    mainAxisExtent: 80,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final folder = state.folders[index];
                                final fColor =
                                    FolderColorPalette.getFolderColor(
                                      folder.color,
                                    );

                                return InkWell(
                                  onTap: () => context
                                      .read<MaterialsLibraryCubit>()
                                      .loadFolder(folder: folder),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium,
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.s12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: fColor.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusMedium,
                                      ),
                                      border: Border.all(
                                        color: fColor.withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.folder_rounded,
                                          color: fColor,
                                          size: 32,
                                        ),
                                        const SizedBox(width: AppSpacing.s10),
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
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                '${l10n.folderFilesCount(folder.filesCount)} • ${folder.formattedTotalSize}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(
                                            Icons.more_vert_rounded,
                                            size: 18,
                                            color: AppColors.textSecondary,
                                          ),
                                          onSelected: (action) {
                                            if (action == 'edit') {
                                              _handleEditFolder(folder);
                                            } else if (action == 'delete') {
                                              _handleDeleteFolder(folder);
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.edit_outlined,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(l10n.editFolderName),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 18,
                                                    color: AppColors.error,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    l10n.deleteFolderAction,
                                                    style: const TextStyle(
                                                      color: AppColors.error,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
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
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s12,
                                ),
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
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final item = state.materials[index];
                                return _buildMaterialCard(context, item, l10n);
                              }, childCount: state.materials.length),
                            ),
                          ],

                          if (state.hasMoreMaterials)
                            const SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.all(AppSpacing.s16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
      ),
    );
  }

  Widget _buildMaterialCard(
    BuildContext context,
    LibraryMaterialEntity item,
    AppLocalizations l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s10),
      child: AppCard(
        variant: AppCardVariant.elevated,
        padding: const EdgeInsets.all(AppSpacing.s14),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: item.isPdf
                    ? Colors.red.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: Icon(
                item.isPdf
                    ? Icons.picture_as_pdf_rounded
                    : Icons.description_rounded,
                color: item.isPdf ? Colors.redAccent : AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: AppSpacing.s14),

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
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.formattedFileSize,
                        style: const TextStyle(
                          fontSize: 12,
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
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.usedInLecturesCount(item.assignedLecturesCount),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ] else ...[
                        Text(
                          l10n.unusedMaterial,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.s12),

            // Quick Preview Button
            OutlinedButton.icon(
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
              label: Text(l10n.previewMaterialAction),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s12,
                  vertical: AppSpacing.s8,
                ),
              ),
              onPressed: () => unawaited(_previewMaterial(item)),
            ),
            const SizedBox(width: AppSpacing.s8),

            // Menu Button
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert_rounded,
                color: AppColors.textSecondary,
              ),
              onSelected: (action) {
                if (action == 'rename') {
                  _handleRenameMaterial(item);
                } else if (action == 'move') {
                  _handleMoveMaterial(item);
                } else if (action == 'delete') {
                  _handleDeleteMaterial(item);
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.editMaterialAction),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'move',
                  child: Row(
                    children: [
                      const Icon(Icons.drive_file_move_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(l10n.moveMaterialAction),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.deleteMaterialAction,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
