import 'package:cached_network_image/cached_network_image.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<MistakesCubit>().loadMistakes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openImageDialog(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.s16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                memCacheWidth: 800,
                memCacheHeight: 800,
                maxWidthDiskCache: 1200,
                fit: BoxFit.contain,
                placeholder: (_, __) => const SizedBox(
                  height: 250,
                  child: Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (_, __, ___) => const SizedBox(
                  height: 250,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    );
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
      body: BlocBuilder<MistakesCubit, MistakesState>(
        builder: (context, state) {
          if (state is MistakesLoading || state is MistakesInitial) {
            return const AppLoadingView();
          }

          if (state is MistakesError) {
            return AppErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<MistakesCubit>().loadMistakes(),
            );
          }

          if (state is MistakesLoaded) {
            final questions = state.filteredQuestions;

            return RefreshIndicator(
              onRefresh: () => context
                  .read<MistakesCubit>()
                  .loadMistakes(forceRefresh: true),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s16,
                  vertical: AppSpacing.s24,
                ),
                child: ResponsiveContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Banner
                      StudentMistakesHeaderBanner(state: state),
                      const SizedBox(height: AppSpacing.s20),

                      // Zero-Mistake Gauntlet Hero Card (Pillar 3.2 & 3.1)
                      ZeroMistakeGauntletCard(state: state),
                      const SizedBox(height: AppSpacing.s20),

                      // Stats Row
                      StudentMistakesStatsGrid(state: state),
                      const SizedBox(height: AppSpacing.s24),

                      // Filter Bar (Type, Status, Search, Source)
                      StudentMistakesFilterBar(
                        state: state,
                        searchController: _searchController,
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // Mistake Sort Bar (Pillar 3.3)
                      MistakeSortBar(
                        activeSort: state.sortOrder,
                        onSortChanged: (sort) => context
                            .read<MistakesCubit>()
                            .setSortOrder(sort),
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // Questions List or Empty State
                      if (questions.isEmpty)
                        AppEmptyView(
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
                        )
                      else ...[
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: questions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.s16),
                          itemBuilder: (context, index) {
                            final q = questions[index];
                            return StudentMistakeQuestionCard(
                              question: q,
                              index: index + 1,
                              onOpenImage: (url) =>
                                  _openImageDialog(context, url),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s48),
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
}
