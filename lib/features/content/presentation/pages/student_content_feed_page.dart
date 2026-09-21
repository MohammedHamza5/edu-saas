import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
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
import 'package:edu_saas/features/groups/domain/entities/group_entity.dart';
import '../../domain/entities/content_entity.dart';
import '../../domain/entities/file_attachment_entity.dart';
import '../../domain/entities/lesson_assignment_entity.dart';
import '../../domain/repositories/content_repository.dart';
import '../cubit/course_progress_cubit.dart';
import '../cubit/course_progress_state.dart';
import '../widgets/material_viewer_sheet.dart';
import '../widgets/student_lesson_tile.dart';
import '../widgets/student_mission_command_deck.dart';

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
  bool _isRoadmapMode = true;

  String? get _currentUserId {
    try {
      final authState = context.read<AuthCubit>().state;
      if (authState is AuthAuthenticated) {
        return authState.user.id;
      }
    } catch (_) {}
    try {
      return InjectionContainer.supabaseClient.auth.currentUser?.id;
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _activeGroupId = widget.groupId;
    _activeGroupName = widget.groupName;
    _fetchStudentGroups();
    context.read<CourseProgressCubit>().loadCourseProgress(
          _activeGroupId,
          studentId: _currentUserId,
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
    // Pagination is not needed for the course progress as it returns the whole sequence
  }

  Future<void> _handleContentTap(LessonAssignmentEntity item, {int? index, int? totalCount}) async {
    if (item.isLocked) {
      final prevIndex = index != null && index > 1
          ? index - 1
          : (item.sortOrder > 1 ? item.sortOrder - 1 : 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(context.l10n.completeLessonToUnlock(prevIndex)),
        ),
      );
      return;
    }

    switch (item.type) {
      case ContentType.video:
        final encodedTitle = item.lessonExamTitle != null 
            ? Uri.encodeComponent(item.lessonExamTitle!) 
            : '';
        final encodedGroupName = _activeGroupName != null
            ? Uri.encodeComponent(_activeGroupName!)
            : '';
        final lIndex = index ?? item.sortOrder;
        final tLessons = totalCount ?? 1;
        await context.push(
          '${AppRoutes.videoPlayer}?id=${item.contentId}&associatedExamId=${item.lessonExamId ?? ''}&associatedExamTitle=$encodedTitle&groupId=$_activeGroupId&groupName=$encodedGroupName&lessonIndex=$lIndex&totalLessons=$tLessons',
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
          content: ContentEntity(
            id: item.contentId,
            tenantId: '',
            groupId: item.groupId,
            title: item.title,
            type: item.type,
            status: ContentStatus.published,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            file: item.pdfFileId != null
                ? FileAttachmentEntity(
                    id: item.pdfFileId!,
                    tenantId: '',
                    contentId: item.contentId,
                    fileName: item.pdfFileName ?? '',
                    storagePath: item.pdfStoragePath ?? '',
                    mimeType: '',
                    fileSize: 0,
                    createdAt: DateTime.now(),
                  )
                : null,
          ),
          onGetSignedUrl: (storagePath) =>
              context.read<ContentRepository>().getSignedFileUrl(storagePath: storagePath).then((value) => value.dataOrNull ?? ''),
        );
        break;
    }

    // Refresh course progress when returning from any content view (Phase E)
    if (mounted) {
      unawaited(context.read<CourseProgressCubit>().loadCourseProgress(
        _activeGroupId,
        studentId: InjectionContainer.supabaseClient.auth.currentUser?.id,
      ));
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
            onPressed: () => context.read<CourseProgressCubit>().loadCourseProgress(
                  _activeGroupId,
                  studentId: InjectionContainer.supabaseClient.auth.currentUser?.id,
                ),
          ),
        ],
      ),
      body: BlocConsumer<CourseProgressCubit, CourseProgressState>(
        listener: (context, state) {
          if (state is CourseProgressError) {
            final userFriendlyMessage = _isTechnicalError(state.message)
                ? context.l10n.errorOccurred
                : state.message;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(userFriendlyMessage),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CourseProgressLoading) {
            return const AppLoadingView.cardsGrid(count: 4, columns: 2);
          }

          if (state is CourseProgressError) {
            final userFriendlyMessage = _isTechnicalError(state.message)
                ? context.l10n.errorOccurred
                : state.message;
            return AppErrorView(
              message: userFriendlyMessage,
              onRetry: () => context.read<CourseProgressCubit>().loadCourseProgress(
                    _activeGroupId,
                    studentId: InjectionContainer.supabaseClient.auth.currentUser?.id,
                  ),
            );
          }

          if (state is CourseProgressLoaded) {
            final allPublished = state.lessons;

            final completedCount = allPublished.where((i) => i.isEffectivelyCompleted).length;
            final totalPublishedCount = allPublished.length;
            final overallProgressPct = totalPublishedCount > 0
                ? ((completedCount / totalPublishedCount) * 100).toInt()
                : 0;

            // Find immediate next mission/lesson
            LessonAssignmentEntity? nextLesson;
            int? nextLessonIndex;
            for (int i = 0; i < allPublished.length; i++) {
              final it = allPublished[i];
              if (!it.isEffectivelyCompleted && !it.isLocked) {
                nextLesson = it;
                nextLessonIndex = i + 1;
                break;
              }
            }
            if (nextLesson == null) {
              for (int i = 0; i < allPublished.length; i++) {
                final it = allPublished[i];
                if (!it.isEffectivelyCompleted) {
                  nextLesson = it;
                  nextLessonIndex = i + 1;
                  break;
                }
              }
            }

            // Filter by type
            var items = _selectedTypeFilter == null
                ? allPublished
                : allPublished
                    .where((i) => i.type == _selectedTypeFilter)
                    .toList();

            if (_searchQuery.isNotEmpty) {
              items = items
                  .where((i) =>
                      i.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                      (i.description
                              ?.toLowerCase()
                              .contains(_searchQuery.toLowerCase()) ??
                          false) ||
                      (i.pdfFileName
                              ?.toLowerCase()
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
                      context.read<CourseProgressCubit>().loadCourseProgress(
                            _activeGroupId,
                            studentId: _currentUserId,
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
                                              .read<CourseProgressCubit>()
                                              .loadCourseProgress(
                                                g.id,
                                                studentId: _currentUserId,
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

                      // 1.1 Hero Mission Command Deck
                      if (allPublished.isNotEmpty)
                        SliverToBoxAdapter(
                          child: StudentMissionCommandDeck(
                            nextLesson: nextLesson,
                            nextLessonIndex: nextLessonIndex,
                            completedCount: completedCount,
                            totalCount: totalPublishedCount,
                            overallPercentage: overallProgressPct,
                            groupName: _activeGroupName ?? '',
                            onResume: nextLesson != null
                                ? () => _handleContentTap(
                                      nextLesson!,
                                      index: nextLessonIndex,
                                      totalCount: totalPublishedCount,
                                    )
                                : null,
                          ),
                        ),

                      // 1.2 View Switcher (Roadmap vs Syllabus List)
                      if (allPublished.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.s4, bottom: AppSpacing.s8),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    padding: const EdgeInsets.all(3),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildViewModeButton(
                                          icon: Icons.alt_route_rounded,
                                          label: context.l10n.syllabusViewRoadmap,
                                          isActive: _isRoadmapMode,
                                          onTap: () => setState(() => _isRoadmapMode = true),
                                        ),
                                        _buildViewModeButton(
                                          icon: Icons.format_list_numbered_rounded,
                                          label: context.l10n.syllabusViewList,
                                          isActive: !_isRoadmapMode,
                                          onTap: () => setState(() => _isRoadmapMode = false),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
                                message: context.l10n.courseBeingPreparedTitle,
                                subtitle: context.l10n.courseBeingPreparedSubtitle,
                                icon: Icons.school_outlined,
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
                              return StudentLessonTile(
                                content: item.toContentEntity(),
                                lesson: item,
                                index: index + 1,
                                isLast: index == items.length - 1,
                                isRoadmapMode: _isRoadmapMode &&
                                    _selectedTypeFilter == null &&
                                    _searchQuery.isEmpty,
                                onTap: () => _handleContentTap(
                                  item,
                                  index: index + 1,
                                  totalCount: items.length,
                                ),
                                onOpenHandout: item.pdfFileId != null
                                    ? () async {
                                        await MaterialViewerSheet.show(
                                          context,
                                          content: ContentEntity(
                                            id: item.contentId,
                                            tenantId: '',
                                            groupId: item.groupId,
                                            title: item.title,
                                            type: item.type,
                                            status: ContentStatus.published,
                                            createdAt: DateTime.now(),
                                            updatedAt: DateTime.now(),
                                            file: FileAttachmentEntity(
                                              id: item.pdfFileId!,
                                              tenantId: '',
                                              contentId: item.contentId,
                                              fileName: item.pdfFileName ?? '',
                                              storagePath: item.pdfStoragePath ?? '',
                                              mimeType: '',
                                              fileSize: 0,
                                              createdAt: DateTime.now(),
                                            ),
                                          ),
                                          onGetSignedUrl: (storagePath) =>
                                              context.read<ContentRepository>().getSignedFileUrl(storagePath: storagePath).then((value) => value.dataOrNull ?? ''),
                                        );
                                      }
                                    : null,
                                onTakeQuiz: item.hasLessonExam
                                    ? () {
                                        context.push(
                                          '${AppRoutes.studentExams}?examId=${item.lessonExamId}',
                                        );
                                      }
                                    : null,
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

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildViewModeButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
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

  bool _isTechnicalError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('exception') ||
        lower.contains('postgres') ||
        lower.contains('sql') ||
        lower.contains('syntax') ||
        lower.contains('null') ||
        lower.contains('undefined') ||
        lower.contains('code:');
  }
}
