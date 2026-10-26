import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/mistake_entities.dart';
import '../cubit/mistakes_cubit.dart';
import '../cubit/mistakes_state.dart';
import '../widgets/mistake_practice_mode_dialog.dart';
import '../widgets/student_mistake_question_card.dart';
import '../widgets/mistake_sort_bar.dart';
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
                    child: Icon(Icons.broken_image, color: Colors.white, size: 40),
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
              onRetry: () => context.read<MistakesCubit>().loadMistakes(),
            );
          }

          if (state is MistakesLoaded) {
            final questions = state.filteredQuestions;

            return RefreshIndicator(
              onRefresh: () => context.read<MistakesCubit>().loadMistakes(forceRefresh: true),
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
                      _buildHeaderBanner(
                        context,
                        state,
                      ),
                      const SizedBox(height: AppSpacing.s20),

                      // Zero-Mistake Gauntlet Hero Card (Pillar 3.2 & 3.1)
                      ZeroMistakeGauntletCard(state: state),
                      const SizedBox(height: AppSpacing.s20),

                      // Stats Row
                      _buildStatsRow(context, state),
                      const SizedBox(height: AppSpacing.s24),

                      // Filter Bar (Type, Status, Search, Source)
                      _buildFilterBar(context, state),
                      const SizedBox(height: AppSpacing.s16),

                      // Mistake Sort Bar (Pillar 3.3)
                      MistakeSortBar(
                        activeSort: state.sortOrder,
                        onSortChanged: (sort) => context.read<MistakesCubit>().setSortOrder(sort),
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // Questions List or Empty State
                      if (questions.isEmpty)
                        AppEmptyView(
                          message: state.statusFilter == MistakeStatusFilter.resolved
                              ? l10n.noMasteredMistakesFound
                              : l10n.noMistakesFound,
                          subtitle: state.statusFilter == MistakeStatusFilter.resolved
                              ? l10n.noMasteredMistakesFoundSub
                              : l10n.noMistakesFoundSub,
                          icon: state.statusFilter == MistakeStatusFilter.resolved
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
                              onOpenImage: (url) => _openImageDialog(context, url),
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

  Widget _buildHeaderBanner(
    BuildContext context,
    MistakesLoaded state,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.82),
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.mistakesBankTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s4),
                    Text(
                      l10n.mistakesBankSubtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s20),
          Wrap(
            spacing: AppSpacing.s12,
            runSpacing: AppSpacing.s8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (state.totalCountInList > 0)
                ElevatedButton.icon(
                  onPressed: () {
                    MistakePracticeModeDialog.show(
                      context: context,
                      unresolvedCount: state.unresolvedCountInList,
                      resolvedCount: state.resolvedCountInList,
                      totalCount: state.totalCountInList,
                      onSelectMode: (mode) {
                        final typeParam = state.typeFilter == MistakeTypeFilter.wrongOnly
                            ? '&type=wrongOnly'
                            : state.typeFilter == MistakeTypeFilter.skippedOnly
                                ? '&type=skippedOnly'
                                : '';
                        final query = state.selectedExamId != null
                            ? '?examId=${state.selectedExamId}&mode=$mode$typeParam'
                            : '?mode=$mode$typeParam';
                        context.push('${AppRoutes.mistakesPractice}$query');
                      },
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    l10n.startMistakesPractice,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: theme.colorScheme.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s20,
                      vertical: AppSpacing.s14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, MistakesLoaded state) {
    final l10n = context.l10n;
    final summary = state.summary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 600;
        final cardList = [
          _buildStatCard(
            context,
            label: l10n.unresolvedMistakesCount,
            count: summary.unresolvedCount,
            color: AppColors.warning,
            icon: Icons.pending_actions_rounded,
          ),
          _buildStatCard(
            context,
            label: l10n.resolvedMistakesCount,
            count: summary.resolvedCount,
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
          ),
          _buildStatCard(
            context,
            label: l10n.totalMistakesCount,
            count: summary.totalMistakes,
            color: AppColors.info,
            icon: Icons.analytics_outlined,
          ),
          _buildBreakdownCard(
            context,
            wrongCount: state.unresolvedWrongCountInList,
            skippedCount: state.unresolvedSkippedCountInList,
          ),
        ];

        if (isSmall) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: cardList[0]),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: cardList[1]),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),
              Row(
                children: [
                  Expanded(child: cardList[2]),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(child: cardList[3]),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cardList[0]),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: cardList[1]),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: cardList[2]),
            const SizedBox(width: AppSpacing.s8),
            Expanded(child: cardList[3]),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Icon(icon, color: color, size: 22),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownCard(
    BuildContext context, {
    required int wrongCount,
    required int skippedCount,
  }) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            l10n.mistakesTypeBreakdown,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  '❌ $wrongCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  '⏸️ $skippedCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, MistakesLoaded state) {
    final l10n = context.l10n;
    final cubit = context.read<MistakesCubit>();
    final summary = state.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Prominent Status Segment Tabs (Needs Practice / Mastered / All)
        Container(
          padding: const EdgeInsets.all(AppSpacing.s4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildStatusTab(
                  context,
                  title: l10n.mistakeTabUnresolved,
                  count: state.unresolvedCountInList,
                  isSelected: state.statusFilter == MistakeStatusFilter.unresolved,
                  color: AppColors.warning,
                  onTap: () => cubit.setStatusFilter(MistakeStatusFilter.unresolved),
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: _buildStatusTab(
                  context,
                  title: l10n.mistakeTabResolved,
                  count: state.resolvedCountInList,
                  isSelected: state.statusFilter == MistakeStatusFilter.resolved,
                  color: AppColors.success,
                  onTap: () => cubit.setStatusFilter(MistakeStatusFilter.resolved),
                ),
              ),
              const SizedBox(width: AppSpacing.s4),
              Expanded(
                child: _buildStatusTab(
                  context,
                  title: l10n.mistakeTabAll,
                  count: state.totalCountInList,
                  isSelected: state.statusFilter == MistakeStatusFilter.all,
                  color: Theme.of(context).colorScheme.primary,
                  onTap: () => cubit.setStatusFilter(MistakeStatusFilter.all),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s12),

        // 2. Search Box
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: l10n.searchMistakesPlaceholder,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      cubit.setSearchQuery('');
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
          ),
          onChanged: (val) {
            cubit.setSearchQuery(val);
            setState(() {});
          },
        ),
        const SizedBox(height: AppSpacing.s12),

        // 3. Type Filter Chips
        Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: [
            // Mistake Type: All
            FilterChip(
              label: Text('${l10n.filterAllTypes} (${state.questions.length})'),
              selected: state.typeFilter == MistakeTypeFilter.all,
              onSelected: (_) => cubit.setTypeFilter(MistakeTypeFilter.all),
            ),
            // Mistake Type: Wrong Answers Only
            FilterChip(
              avatar: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
              label: Text('${l10n.filterWrongAnswersOnly} (${state.wrongCountInList})'),
              selected: state.typeFilter == MistakeTypeFilter.wrongOnly,
              selectedColor: AppColors.error.withValues(alpha: 0.15),
              onSelected: (_) => cubit.setTypeFilter(MistakeTypeFilter.wrongOnly),
            ),
            // Mistake Type: Skipped Questions Only
            FilterChip(
              avatar: const Icon(Icons.pause_circle_outline_rounded, size: 16, color: AppColors.warning),
              label: Text('${l10n.filterSkippedOnly} (${state.skippedCountInList})'),
              selected: state.typeFilter == MistakeTypeFilter.skippedOnly,
              selectedColor: AppColors.warning.withValues(alpha: 0.15),
              onSelected: (_) => cubit.setTypeFilter(MistakeTypeFilter.skippedOnly),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s8),

        // Reflection Reason Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(l10n.filterAllTypes),
                selected: state.reasonFilter == MistakeReasonFilter.all,
                onSelected: (_) => cubit.setReasonFilter(MistakeReasonFilter.all),
              ),
              const SizedBox(width: AppSpacing.s6),
              FilterChip(
                avatar: const Icon(Icons.psychology_outlined, size: 15, color: Color(0xFF7C3AED)),
                label: Text(l10n.reflectionConceptGap),
                selected: state.reasonFilter == MistakeReasonFilter.conceptGap,
                selectedColor: const Color(0xFF7C3AED).withValues(alpha: 0.15),
                onSelected: (_) => cubit.setReasonFilter(MistakeReasonFilter.conceptGap),
              ),
              const SizedBox(width: AppSpacing.s6),
              FilterChip(
                avatar: const Icon(Icons.bolt_outlined, size: 15, color: AppColors.error),
                label: Text(l10n.reflectionCarelessError),
                selected: state.reasonFilter == MistakeReasonFilter.carelessError,
                selectedColor: AppColors.error.withValues(alpha: 0.15),
                onSelected: (_) => cubit.setReasonFilter(MistakeReasonFilter.carelessError),
              ),
              const SizedBox(width: AppSpacing.s6),
              FilterChip(
                avatar: const Icon(Icons.menu_book_outlined, size: 15, color: Color(0xFF0284C7)),
                label: Text(l10n.reflectionMisreadQuestion),
                selected: state.reasonFilter == MistakeReasonFilter.misreadQuestion,
                selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
                onSelected: (_) => cubit.setReasonFilter(MistakeReasonFilter.misreadQuestion),
              ),
              const SizedBox(width: AppSpacing.s6),
              FilterChip(
                avatar: const Icon(Icons.hourglass_top_outlined, size: 15, color: AppColors.warning),
                label: Text(l10n.reflectionTimePressure),
                selected: state.reasonFilter == MistakeReasonFilter.timePressure,
                selectedColor: AppColors.warning.withValues(alpha: 0.15),
                onSelected: (_) => cubit.setReasonFilter(MistakeReasonFilter.timePressure),
              ),
            ],
          ),
        ),

        // 3. Exam Sources Dropdown (if multiple sources exist)
        if (summary.sources.length > 1) ...[
          const SizedBox(height: AppSpacing.s12),
          DropdownButtonFormField<String?>(
            value: state.selectedExamId,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s4,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
            ),
            hint: Text(l10n.filterBySourceExam),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(l10n.allExamsFilter),
              ),
              ...summary.sources.map(
                (MistakeSourceEntity src) => DropdownMenuItem<String?>(
                  value: src.examId,
                  child: Text(
                    '${src.examTitle} (${src.unresolvedCount})',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (val) => cubit.filterByExam(val),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusTab(
    BuildContext context, {
    required String title,
    required int count,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s8,
            vertical: AppSpacing.s8,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
            border: isSelected
                ? Border.all(color: color.withValues(alpha: 0.4), width: 1.5)
                : Border.all(color: Colors.transparent, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? color : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color
                      : Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
