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
  @override
  void initState() {
    super.initState();
    context.read<MistakesCubit>().loadMistakes();
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
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                },
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
            final summary = state.summary;
            final questions = state.questions;

            return RefreshIndicator(
              onRefresh: () => context.read<MistakesCubit>().loadMistakes(),
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
                        summary,
                        state.selectedExamId,
                      ),
                      const SizedBox(height: AppSpacing.s24),

                      // Stats Row
                      _buildStatsRow(context, summary),
                      const SizedBox(height: AppSpacing.s24),

                      // Filter Bar (Status & Source)
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
    MistakeSummaryEntity summary,
    String? selectedExamId,
  ) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hasUnresolved = summary.unresolvedCount > 0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withValues(alpha: 0.85),
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 12,
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
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
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
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          if (hasUnresolved)
            ElevatedButton.icon(
              onPressed: () {
                final query = selectedExamId != null
                    ? '?examId=$selectedExamId'
                    : '';
                context.push('${AppRoutes.mistakesPractice}$query');
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
                  horizontal: AppSpacing.s24,
                  vertical: AppSpacing.s16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                elevation: 0,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, MistakeSummaryEntity summary) {
    final l10n = context.l10n;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            label: l10n.unresolvedMistakesCount,
            count: summary.unresolvedCount,
            color: AppColors.warning,
            icon: Icons.pending_actions_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: _buildStatCard(
            context,
            label: l10n.resolvedMistakesCount,
            count: summary.resolvedCount,
            color: AppColors.success,
            icon: Icons.check_circle_rounded,
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: _buildStatCard(
            context,
            label: l10n.totalMistakesCount,
            count: summary.totalMistakes,
            color: AppColors.info,
            icon: Icons.analytics_outlined,
          ),
        ),
      ],
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
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(l10n.filterUnresolved),
                selected: state.onlyUnresolved,
                onSelected: (_) => cubit.toggleResolvedFilter(true),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilterChip(
                label: Text(l10n.filterResolved),
                selected: !state.onlyUnresolved,
                onSelected: (_) => cubit.toggleResolvedFilter(false),
              ),
            ],
          ),
        ),

        // Exam Sources Dropdown (if multiple exams exist)
        if (summary.sources.length > 1) ...[
          const SizedBox(height: AppSpacing.s8),
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
              : AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status badge & Source Exam
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  q.sourceExamTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s8,
                  vertical: AppSpacing.s4 / 2,
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
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),

          // Failure counter & Date
          Row(
            children: [
              Text(
                l10n.timesFailedLabel(q.failureCount),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
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
          const Divider(height: AppSpacing.s16),

          // Question Stem
          if (q.questionText.isNotEmpty) ...[
            Text(
              q.questionText,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
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
                  child: Image.network(
                    q.imageUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.s16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const Padding(
                      padding: EdgeInsets.all(AppSpacing.s16),
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],

          // Options List
          ...q.options.map((opt) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s4),
              child: Row(
                children: [
                  const Icon(
                    Icons.radio_button_unchecked,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Expanded(
                    child: Text(
                      opt.optionText,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
