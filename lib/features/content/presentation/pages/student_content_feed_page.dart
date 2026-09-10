import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';
import '../widgets/content_item_card.dart';
import '../widgets/material_viewer_sheet.dart';

class StudentContentFeedPage extends StatefulWidget {
  final String groupId;
  final String? groupName;

  const StudentContentFeedPage({
    super.key,
    required this.groupId,
    this.groupName,
  });

  @override
  State<StudentContentFeedPage> createState() => _StudentContentFeedPageState();
}

class _StudentContentFeedPageState extends State<StudentContentFeedPage> {
  ContentType? _selectedTypeFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<ContentCubit>().loadGroupContent(
          widget.groupId,
          isStudent: true,
        );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleOpenFile(ContentEntity item) async {
    await MaterialViewerSheet.show(
      context,
      content: item,
      onGetSignedUrl: (storagePath) =>
          context.read<ContentCubit>().getSignedUrl(storagePath),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.groupName != null
        ? 'محتوى: ${widget.groupName}'
        : 'محتوى ومذكرات المجموعة';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'رجوع للوحة الطالب',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRouter.studentDashboard),
        ),
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded,
                size: 20, color: AppColors.primary),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث المحتوى',
            onPressed: () => context.read<ContentCubit>().loadGroupContent(
                  widget.groupId,
                  isStudent: true,
                ),
          ),
        ],
      ),
      body: BlocConsumer<ContentCubit, ContentState>(
        listener: (context, state) {
          if (state is ContentError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ContentLoading) {
            return const Center(
              child: ResponsiveContainer(
                maxWidth: 900,
                padding: EdgeInsets.all(AppSpacing.s16),
                child: AppLoadingView(
                  style: AppLoadingStyle.skeletonList,
                ),
              ),
            );
          }

          if (state is ContentError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<ContentCubit>().loadGroupContent(
                    widget.groupId,
                    isStudent: true,
                  ),
            );
          }

          if (state is ContentLoaded) {
            final allPublished = state.items
                .where((i) => i.status == ContentStatus.published)
                .toList();

            // Filter by type
            var items = _selectedTypeFilter == null
                ? allPublished
                : allPublished
                    .where((i) => i.type == _selectedTypeFilter)
                    .toList();

            // Filter by live search query
            if (_searchQuery.isNotEmpty) {
              items = items
                  .where((i) =>
                      i.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (i.description
                              ?.toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ??
                          false) ||
                      (i.file?.fileName
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ??
                          false))
                  .toList();
            }

            return Center(
              child: ResponsiveContainer(
                maxWidth: 1000,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Search Bar & Filter Chips
                    AppTextField(
                      controller: _searchController,
                      hintText:
                          'ابحث في المذكرات، الملخصات، أو الفيديوهات...',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textSecondary, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      onChanged: (val) {
                        setState(() => _searchQuery = val.trim());
                      },
                    ),

                    const SizedBox(height: AppSpacing.s12),

                    // Type Filter Chips Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(
                            label: 'الكل (${allPublished.length})',
                            isSelected: _selectedTypeFilter == null,
                            onSelected: () =>
                                setState(() => _selectedTypeFilter = null),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          _buildFilterChip(
                            label:
                                'المذكرات (${allPublished.where((i) => i.type == ContentType.pdf).length})',
                            isSelected: _selectedTypeFilter == ContentType.pdf,
                            onSelected: () => setState(
                                () => _selectedTypeFilter = ContentType.pdf),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          _buildFilterChip(
                            label:
                                'الصور (${allPublished.where((i) => i.type == ContentType.image).length})',
                            isSelected: _selectedTypeFilter == ContentType.image,
                            onSelected: () => setState(
                                () => _selectedTypeFilter = ContentType.image),
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          _buildFilterChip(
                            label:
                                'الفيديوهات (${allPublished.where((i) => i.type == ContentType.video).length})',
                            isSelected: _selectedTypeFilter == ContentType.video,
                            onSelected: () => setState(
                                () => _selectedTypeFilter = ContentType.video),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.s12),

                    // Content Feed List or Empty State
                    Expanded(
                      child: allPublished.isEmpty
                          ? const AppEmptyView(
                              message:
                                  'لم يتم نشر أي محتوى دراسي في هذه المجموعة بعد\nستظهر المذكرات والدروس هنا فور نشر المعلم لها.',
                              icon: Icons.menu_book_rounded,
                            )
                          : items.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.search_off_rounded,
                                        size: 48,
                                        color: AppColors.textMuted,
                                      ),
                                      const SizedBox(height: AppSpacing.s12),
                                      Text(
                                        'لا توجد مواد دراسية مطابقة لبحثك "$_searchQuery"',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: AppSpacing.s10),
                                      child: ContentItemCard(
                                        content: item,
                                        isTeacher: false,
                                        onOpenFile: (_) =>
                                            _handleOpenFile(item),
                                        onTap: () => _handleOpenFile(item),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary.withAlpha(35),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }
}
