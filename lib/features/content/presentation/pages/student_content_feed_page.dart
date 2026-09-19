import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../groups/domain/entities/group_entity.dart';
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
  final ScrollController _scrollController = ScrollController();
  late String _activeGroupId;
  late String? _activeGroupName;
  List<GroupEntity> _studentGroups = [];

  ContentType? _selectedTypeFilter;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeGroupId = widget.groupId;
    _activeGroupName = widget.groupName;
    _fetchStudentGroups();
    context.read<ContentCubit>().loadGroupContent(
          _activeGroupId,
          isStudent: true,
        );
    _scrollController.addListener(_onScroll);
  }

  Future<void> _fetchStudentGroups() async {
    try {
      final result = await InjectionContainer.groupsRepository.getGroups();
      if (mounted && result.isSuccess && result.dataOrNull != null) {
        setState(() {
          _studentGroups = result.dataOrNull!;
          if (_activeGroupName == null && _studentGroups.isNotEmpty) {
            final match = _studentGroups.where((g) => g.id == _activeGroupId);
            if (match.isNotEmpty) {
              _activeGroupName = match.first.name;
            }
          }
        });
      }
    } catch (_) {
      // Safe fallback when groupsRepository is uninitialized in tests or offline
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<ContentCubit>().loadMoreContent();
    }
  }

  Future<void> _handleContentTap(ContentEntity item) async {
    if (item.isLocked) {
      final examTitle =
          item.prerequisiteExamTitle ?? context.l10n.prerequisiteExamBadge;
      final passScore = item.prerequisitePassingScore ?? 60;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(context.l10n.mustPassExamToUnlock(examTitle, passScore)),
          action: item.prerequisiteExamId != null
              ? SnackBarAction(
                  label: context.l10n.takeRequiredExamAction,
                  textColor: Colors.white,
                  onPressed: () => context.push(AppRoutes.studentExams),
                )
              : null,
        ),
      );
      return;
    }

    switch (item.type) {
      case ContentType.video:
        final encodedTitle = item.associatedExamTitle != null 
            ? Uri.encodeComponent(item.associatedExamTitle!) 
            : '';
        await context.push(
          '${AppRoutes.videoPlayer}?id=${item.id}&associatedExamId=${item.associatedExamId ?? ''}&associatedExamTitle=$encodedTitle',
        );
        break;
      case ContentType.assignment:
        await context.push(AppRoutes.studentAssignments);
        break;
      case ContentType.exam:
        await context.push(AppRoutes.studentExams);
        break;
      case ContentType.pdf:
      case ContentType.image:
        await MaterialViewerSheet.show(
          context,
          content: item,
          onGetSignedUrl: (storagePath) =>
              context.read<ContentCubit>().getSignedUrl(storagePath),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = _activeGroupName != null
        ? context.l10n.groupContentPrefix(_activeGroupName!)
        : context.l10n.groupContentDefault;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.l10n.backToStudentDashboard,
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRoutes.studentDashboard),
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
            tooltip: context.l10n.refreshContent,
            onPressed: () => context.read<ContentCubit>().loadGroupContent(
                  _activeGroupId,
                  isStudent: true,
                  forceRefresh: true,
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
            return const AppLoadingView.cardsGrid(count: 4, columns: 2);
          }

          if (state is ContentError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<ContentCubit>().loadGroupContent(
                    _activeGroupId,
                    isStudent: true,
                    forceRefresh: true,
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
                maxWidth: ResponsiveBreakpoints.maxContentWidth,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                ),
                child: RefreshIndicator(
                  onRefresh: () async =>
                      context.read<ContentCubit>().loadGroupContent(
                            _activeGroupId,
                            isStudent: true,
                            forceRefresh: true,
                          ),
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // 1. Group Switcher Pills (Only if student has multiple groups)
                      if (_studentGroups.length > 1)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s12),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _studentGroups.map((g) {
                                  final isSelected = g.id == _activeGroupId;
                                  return Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                      end: AppSpacing.s8,
                                    ),
                                    child: ChoiceChip(
                                      avatar: Icon(
                                        Icons.school_rounded,
                                        size: 16,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.primary,
                                      ),
                                      label: Text(g.name),
                                      selected: isSelected,
                                      selectedColor: AppColors.primary,
                                      backgroundColor: AppColors.surfaceVariant,
                                      labelStyle: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                      onSelected: (selected) {
                                        if (selected && _activeGroupId != g.id) {
                                          setState(() {
                                            _activeGroupId = g.id;
                                            _activeGroupName = g.name;
                                            _selectedTypeFilter = null;
                                            _searchController.clear();
                                            _searchQuery = '';
                                          });
                                          context
                                              .read<ContentCubit>()
                                              .loadGroupContent(
                                                g.id,
                                                isStudent: true,
                                              );
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),

                      // 2. Search Bar
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.s12),
                          child: AppTextField(
                            controller: _searchController,
                            hintText: context.l10n.searchContentPlaceholder,
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 18,
                                    ),
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
                        ),
                      ),

                      // 3. Type Filter Chips Row
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s8,
                          ),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  label: context.l10n
                                      .filterAllWithCount(allPublished.length),
                                  isSelected: _selectedTypeFilter == null,
                                  onSelected: () => setState(
                                    () => _selectedTypeFilter = null,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterPdfsWithCount(
                                    allPublished
                                        .where((i) => i.type == ContentType.pdf)
                                        .length,
                                  ),
                                  isSelected:
                                      _selectedTypeFilter == ContentType.pdf,
                                  onSelected: () => setState(
                                    () => _selectedTypeFilter = ContentType.pdf,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterImagesWithCount(
                                    allPublished
                                        .where(
                                          (i) => i.type == ContentType.image,
                                        )
                                        .length,
                                  ),
                                  isSelected:
                                      _selectedTypeFilter == ContentType.image,
                                  onSelected: () => setState(
                                    () =>
                                        _selectedTypeFilter = ContentType.image,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                _buildFilterChip(
                                  label: context.l10n.filterVideosWithCount(
                                    allPublished
                                        .where(
                                          (i) => i.type == ContentType.video,
                                        )
                                        .length,
                                  ),
                                  isSelected:
                                      _selectedTypeFilter == ContentType.video,
                                  onSelected: () => setState(
                                    () =>
                                        _selectedTypeFilter = ContentType.video,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 4. Content Feed List or Empty State
                      if (allPublished.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
                              child: AppEmptyView(
                                message: context.l10n.noContentPublishedYet,
                                icon: Icons.menu_book_rounded,
                              ),
                            ),
                          ),
                        )
                      else if (items.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 48),
                            child: Center(
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
                                    context.l10n
                                        .noMatchingContentFound(_searchQuery),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.only(bottom: 32),
                          sliver: SliverList.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.s10,
                                ),
                                child: ContentItemCard(
                                  content: item,
                                  isTeacher: false,
                                  onOpenFile: (_) => _handleContentTap(item),
                                  onTap: () => _handleContentTap(item),
                                ),
                              );
                            },
                          ),
                        ),
                      if (state.isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.s16,
                            ),
                            child: Center(
                              child: AppLoadingView.compact(size: 24),
                            ),
                          ),
                        ),
                    ],
                  ),
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
