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

                      // Stats Row
                      _buildStatsRow(context, state),
                      const SizedBox(height: AppSpacing.s24),

                      // Filter Bar (Type, Status, Search, Source)
                      _buildFilterBar(context, state),
                      const SizedBox(height: AppSpacing.s16),

                      // Questions List or Empty State
                      if (questions.isEmpty)
                        AppEmptyView(
                          message: l10n.noMistakesFound,
                          subtitle: l10n.noMistakesFoundSub,
                          icon: Icons.check_circle_outline_rounded,
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
                            return _buildQuestionCard(context, q, index + 1);
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
    final summary = state.summary;
    final hasUnresolved = summary.unresolvedCount > 0;

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
              if (hasUnresolved)
                ElevatedButton.icon(
                  onPressed: () {
                    final typeParam = state.typeFilter == MistakeTypeFilter.wrongOnly
                        ? '&type=wrongOnly'
                        : state.typeFilter == MistakeTypeFilter.skippedOnly
                            ? '&type=skippedOnly'
                            : '';
                    final query = state.selectedExamId != null
                        ? '?examId=${state.selectedExamId}$typeParam'
                        : typeParam.isNotEmpty
                            ? '?${typeParam.substring(1)}'
                            : '';
                    context.push('${AppRoutes.mistakesPractice}$query');
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(
                    state.typeFilter == MistakeTypeFilter.wrongOnly
                        ? l10n.practiceFilteredMistakes(state.unresolvedWrongCountInList)
                        : state.typeFilter == MistakeTypeFilter.skippedOnly
                            ? l10n.practiceFilteredMistakes(state.unresolvedSkippedCountInList)
                            : l10n.startMistakesPractice,
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
        // 1. Search Box
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

        // 2. Type Filter Chips & Status Chips
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

            const SizedBox(width: AppSpacing.s8),

            // Review Status
            FilterChip(
              label: Text(l10n.filterUnresolved),
              selected: state.onlyUnresolved,
              onSelected: (_) => cubit.toggleResolvedFilter(true),
            ),
            FilterChip(
              label: Text(l10n.filterResolved),
              selected: !state.onlyUnresolved,
              onSelected: (_) => cubit.toggleResolvedFilter(false),
            ),
          ],
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

  Widget _buildQuestionCard(
    BuildContext context,
    MistakeQuestionEntity q,
    int index,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final lastDate = q.lastFailedAt != null
        ? '${q.lastFailedAt!.year}-${q.lastFailedAt!.month.toString().padLeft(2, '0')}-${q.lastFailedAt!.day.toString().padLeft(2, '0')}'
        : '-';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(
          color: q.isResolved
              ? AppColors.success.withValues(alpha: 0.3)
              : q.isSkipped
                  ? AppColors.warning.withValues(alpha: 0.35)
                  : AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Exam Title & Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.sourceExamTitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (q.lessonTitle != null && q.lessonTitle!.isNotEmpty)
                      Text(
                        q.lessonTitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s8),

              // Distinctive Type Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: q.isSkipped
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(
                    color: q.isSkipped
                        ? AppColors.warning.withValues(alpha: 0.35)
                        : AppColors.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      q.isSkipped
                          ? Icons.pause_circle_outline_rounded
                          : Icons.cancel_outlined,
                      size: 13,
                      color: q.isSkipped ? AppColors.warning : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      q.isSkipped
                          ? l10n.skippedQuestionBadge
                          : l10n.wrongAnswerBadge,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: q.isSkipped ? AppColors.warning : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s6),

              // Status Badge (Mastered vs Needs Review)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: q.isResolved
                      ? AppColors.success.withValues(alpha: 0.12)
                      : AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: Text(
                  q.isResolved ? l10n.statusMastered : l10n.statusNeedsReview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: q.isResolved ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),

          // Metadata row: failure count, last attempt date
          Row(
            children: [
              Text(
                l10n.timesFailedLabel(q.failureCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: AppSpacing.s16),
              Text(
                l10n.lastMistakeDate(lastDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),

          // Detailed Context Notice Banner
          if (q.isSkipped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.questionWasSkippedNotice,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cancel_outlined, size: 15, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      q.selectedOptionText != null && q.selectedOptionText!.isNotEmpty
                          ? l10n.previousWrongChoice(q.selectedOptionText!)
                          : l10n.wrongAnswerBadge,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: AppSpacing.s16),

          // Question Stem
          if (q.questionText.isNotEmpty) ...[
            Text(
              q.questionText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],

          // Question Image (if any)
          if (q.imageUrl != null && q.imageUrl!.isNotEmpty) ...[
            GestureDetector(
              onTap: () => _openImageDialog(context, q.imageUrl!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  width: double.infinity,
                  color: Colors.black.withValues(alpha: 0.04),
                  child: CachedNetworkImage(
                    imageUrl: q.imageUrl!,
                    memCacheWidth: 600,
                    memCacheHeight: 600,
                    maxWidthDiskCache: 800,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.s16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(AppSpacing.s16),
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],

          // Options List with subtle previous selection indicator
          ...q.options.map((opt) {
            final wasChosen = opt.id == q.lastSelectedOptionId;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: wasChosen
                      ? AppColors.error.withValues(alpha: 0.05)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: wasChosen
                      ? Border.all(color: AppColors.error.withValues(alpha: 0.3))
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      wasChosen
                          ? Icons.cancel_rounded
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: wasChosen ? AppColors.error : Colors.grey,
                    ),
                    const SizedBox(width: AppSpacing.s6),
                    Expanded(
                      child: Text(
                        opt.optionText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: wasChosen ? FontWeight.bold : FontWeight.normal,
                          color: wasChosen ? AppColors.error : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.s8),

          // Individual Question Practice Button
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              onPressed: () {
                context.push('${AppRoutes.mistakesPractice}?examId=${q.sourceExamId}');
              },
              icon: const Icon(Icons.fitness_center_rounded, size: 16),
              label: Text(
                l10n.practiceThisQuestion,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
