import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../cubit/mistakes_cubit.dart';
import '../cubit/mistakes_state.dart';
import '../widgets/interactive_lightbox_dialog.dart';
import '../widgets/mistake_sort_bar.dart';
import '../widgets/student_mistake_question_card.dart';
import '../widgets/student_mistakes_filter_bar.dart';
import '../widgets/student_mistakes_header_banner.dart';
import '../widgets/student_mistakes_stats_grid.dart';
import '../widgets/zero_mistake_gauntlet_card.dart';

class StudentMistakesPage extends StatefulWidget {
  const StudentMistakesPage({super.key});

  @override
  State<StudentMistakesPage> createState() => _StudentMistakesPageState();
}

class _StudentMistakesPageState extends State<StudentMistakesPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  static const int _pageSize = 20;
  int _displayedCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<MistakesCubit>().loadMistakes();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 350) {
      _loadMore();
    }
  }

  void _loadMore() {
    final s = context.read<MistakesCubit>().state;
    if (s is MistakesLoaded) {
      final total = s.filteredQuestions.length;
      if (_displayedCount < total) {
        setState(() {
          _displayedCount = (_displayedCount + _pageSize).clamp(0, total);
        });
      }
    }
  }

  void _openImageDialog(BuildContext context, String imageUrl) {
    InteractiveLightboxDialog.show(context, imageUrl: imageUrl);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l10n.mistakesBankTitle),
        elevation: 0,
        centerTitle: false,
      ),
      body: BlocConsumer<MistakesCubit, MistakesState>(
        listenWhen: (prev, curr) {
          if (prev is MistakesLoaded && curr is MistakesLoaded) {
            return prev.statusFilter != curr.statusFilter ||
                prev.typeFilter != curr.typeFilter ||
                prev.reasonFilter != curr.reasonFilter ||
                prev.sortOrder != curr.sortOrder ||
                prev.searchQuery != curr.searchQuery;
          }
          return false;
        },
        listener: (context, state) {
          setState(() => _displayedCount = _pageSize);
        },
        builder: (context, state) {
          if (state is MistakesLoading || state is MistakesInitial) {
            return const AppLoadingView();
          }

          if (state is MistakesError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<MistakesCubit>().loadMistakes(),
            );
          }

          if (state is MistakesLoaded) {
            final questions = state.filteredQuestions;
            final displayedQuestions =
                questions.take(_displayedCount).toList();
            final hasMore = _displayedCount < questions.length;

            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _displayedCount = _pageSize);
                await context.read<MistakesCubit>().loadMistakes(
                  forceRefresh: true,
                );
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Header & Filters Deck
                  SliverToBoxAdapter(
                    child: ResponsiveContainer(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s16,
                          AppSpacing.s24,
                          AppSpacing.s16,
                          AppSpacing.s16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            StudentMistakesHeaderBanner(state: state),
                            const SizedBox(height: AppSpacing.s20),
                            ZeroMistakeGauntletCard(state: state),
                            const SizedBox(height: AppSpacing.s20),
                            StudentMistakesStatsGrid(state: state),
                            const SizedBox(height: AppSpacing.s24),
                            StudentMistakesFilterBar(
                              state: state,
                              searchController: _searchController,
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            MistakeSortBar(
                              activeSort: state.sortOrder,
                              onSortChanged: (sort) => context
                                  .read<MistakesCubit>()
                                  .setSortOrder(sort),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Questions List or Empty State
                  if (questions.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: ResponsiveContainer(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.s24),
                            child: AppEmptyView(
                              message: state.statusFilter ==
                                      MistakeStatusFilter.resolved
                                  ? l10n.noMasteredMistakesFound
                                  : l10n.noMistakesFound,
                              subtitle: state.statusFilter ==
                                      MistakeStatusFilter.resolved
                                  ? l10n.noMasteredMistakesFoundSub
                                  : l10n.noMistakesFoundSub,
                              icon: state.statusFilter ==
                                      MistakeStatusFilter.resolved
                                  ? Icons.stars_rounded
                                  : Icons.check_circle_outline_rounded,
                            ),
                          ),
                        ),
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                      ),
                      sliver: SliverList.separated(
                        itemCount: displayedQuestions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.s16),
                        itemBuilder: (context, index) {
                          final q = displayedQuestions[index];
                          return RepaintBoundary(
                            key: ValueKey('mistake_${q.mistakeId}'),
                            child: ResponsiveContainer(
                              child: StudentMistakeQuestionCard(
                                question: q,
                                index: index + 1,
                                onOpenImage: (url) =>
                                    _openImageDialog(context, url),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // 3. Pagination Footer
                    if (hasMore)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.s24,
                          ),
                          child: Center(
                            child: TextButton.icon(
                              onPressed: _loadMore,
                              icon: const Icon(
                                Icons.expand_more_rounded,
                                size: 20,
                              ),
                              label: Text(
                                l10n.loadMoreWithCount(
                                  displayedQuestions.length,
                                  questions.length,
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSpacing.s48),
                      ),
                  ],
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
