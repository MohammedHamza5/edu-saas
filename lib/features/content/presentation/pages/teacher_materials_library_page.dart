import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/pdf_launcher_helper.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/library_material_entity.dart';
import '../../domain/entities/material_folder_entity.dart';
import '../cubit/materials_library_cubit.dart';
import '../cubit/materials_library_state.dart';
import '../dialogs/material_folder_dialogs.dart';
import '../utils/teacher_materials_uploader.dart';
import '../widgets/teacher_materials_breadcrumbs.dart';
import '../widgets/teacher_materials_filter_bar.dart';
import '../widgets/teacher_materials_header.dart';
import '../widgets/teacher_materials_slivers_view.dart';
import '../widgets/teacher_materials_upload_banner.dart';

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
    final cubit = context.read<MaterialsLibraryCubit>();
    final l10n = context.l10n;
    final result = await CreateMaterialFolderDialog.show(context);
    if (!mounted) return;
    if (result != null && result.name.trim().isNotEmpty) {
      final success = await cubit.createFolder(
        result.name,
        color: result.color,
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.savingChanges),
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
    if (!mounted) return;
    if (result != null && result.name.trim().isNotEmpty) {
      await context.read<MaterialsLibraryCubit>().updateFolder(
        folder.id,
        result.name,
        color: result.color,
      );
    }
  }

  Future<void> _handleDeleteFolder(MaterialFolderEntity folder) async {
    final cubit = context.read<MaterialsLibraryCubit>();
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteFolderTitle),
        content: Text(l10n.confirmDeleteFolderMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      await cubit.deleteFolder(folder.id);
      if (!mounted) return;
    }
  }

  Future<void> _handleUploadFiles() {
    return TeacherMaterialsUploader.pickAndUploadFiles(
      context: context,
      cubit: context.read<MaterialsLibraryCubit>(),
    );
  }

  Future<void> _handleRenameMaterial(LibraryMaterialEntity item) async {
    final newTitle = await RenameMaterialDialog.show(
      context,
      currentTitle: item.title,
    );
    if (!mounted) return;
    if (newTitle != null && newTitle.isNotEmpty) {
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

    if (!mounted) return;
    if (targetFolderId != null) {
      await context.read<MaterialsLibraryCubit>().moveMaterial(
        item.id,
        targetFolderId.isEmpty ? null : targetFolderId,
      );
    }
  }

  Future<void> _handleDeleteMaterial(LibraryMaterialEntity item) async {
    final cubit = context.read<MaterialsLibraryCubit>();
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmDeleteMaterialTitle),
        content: Text(l10n.confirmDeleteMaterialMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      await cubit.deleteMaterial(item.id);
      if (!mounted) return;
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
                TeacherMaterialsHeader(
                  onCreateFolder: _handleCreateFolder,
                  onUploadFiles: _handleUploadFiles,
                ),
                const SizedBox(height: AppSpacing.s20),

                // Search & Filter Bar
                TeacherMaterialsFilterBar(
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  onClearSearch: () {
                    _searchController.clear();
                    context.read<MaterialsLibraryCubit>().search('');
                  },
                ),
                const SizedBox(height: AppSpacing.s12),

                // Breadcrumbs Bar
                const TeacherMaterialsBreadcrumbs(),
                const SizedBox(height: AppSpacing.s12),

                // Active Upload Status Banner
                const TeacherMaterialsUploadBanner(),

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

                      return TeacherMaterialsSliversView(
                        scrollController: _scrollController,
                        state: state,
                        onFolderTap: (folder) => context
                            .read<MaterialsLibraryCubit>()
                            .loadFolder(folder: folder),
                        onEditFolder: _handleEditFolder,
                        onDeleteFolder: _handleDeleteFolder,
                        onPreviewMaterial: (item) =>
                            unawaited(_previewMaterial(item)),
                        onRenameMaterial: _handleRenameMaterial,
                        onMoveMaterial: _handleMoveMaterial,
                        onDeleteMaterial: _handleDeleteMaterial,
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
}
