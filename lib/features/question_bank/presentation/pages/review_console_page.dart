import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../cubit/question_bank_cubit.dart';
import '../cubit/question_bank_state.dart';
import '../widgets/math_content_view.dart';
import '../widgets/review_action_bar.dart';
import '../widgets/review_evidence_pane.dart';
import '../widgets/review_history_metadata_section.dart';
import '../widgets/review_question_preview_pane.dart';
import '../widgets/review_validation_banners.dart';

class ReviewConsolePage extends StatefulWidget {
  final String questionId;

  const ReviewConsolePage({super.key, required this.questionId});

  @override
  State<ReviewConsolePage> createState() => _ReviewConsolePageState();
}

class _ReviewConsolePageState extends State<ReviewConsolePage> {
  @override
  void initState() {
    super.initState();
    context.read<QuestionBankCubit>().loadQuestionReview(widget.questionId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocConsumer<QuestionBankCubit, QuestionBankState>(
      listener: (context, state) {
        if (state is QuestionBankReviewLoaded && state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionMessage!),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is QuestionBankLoading) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.reviewConsoleTitle)),
            body: const Center(child: AppLoadingView()),
          );
        }

        if (state is QuestionBankError) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.reviewConsoleTitle)),
            body: AppErrorView(
              message: state.message,
              onRetry: () => context
                  .read<QuestionBankCubit>()
                  .loadQuestionReview(widget.questionId),
            ),
          );
        }

        if (state is QuestionBankReviewLoaded) {
          final isFastMode = state.isFastDiffMode;

          return Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Text(l10n.reviewConsoleTitle),
                  const SizedBox(width: AppSpacing.s12),
                  _buildTriageStateBadge(context, state),
                  const SizedBox(width: AppSpacing.s8),
                  _buildPriorityChip(context, state),
                ],
              ),
              actions: [
                // Fast Mode (Diff Overlay) toggle
                TextButton.icon(
                  onPressed: () =>
                      context.read<QuestionBankCubit>().toggleFastDiffMode(),
                  icon: Icon(
                    isFastMode ? Icons.view_sidebar : Icons.difference,
                    size: 18,
                  ),
                  label: Text(
                    isFastMode ? l10n.standardMode : l10n.fastDiffMode,
                  ),
                ),
                // Second review sampling action
                if (!state.question.requiresSecondReview)
                  IconButton(
                    tooltip: l10n.secondReviewRequiredBadge,
                    icon: const Icon(Icons.rate_review_outlined),
                    onPressed: () =>
                        context.read<QuestionBankCubit>().sampleSecondReview(),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(
                      child: Chip(
                        avatar: const Icon(
                          Icons.check,
                          size: 14,
                          color: AppColors.info,
                        ),
                        label: Text(
                          l10n.secondReviewRequiredBadge,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.info,
                          ),
                        ),
                        backgroundColor: AppColors.info.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                const SizedBox(width: AppSpacing.s8),
              ],
            ),
            body: Column(
              children: [
                // Validation Banners
                ReviewValidationBanners(state: state),

                // Main Area: Split Pane or Fast Diff Overlay
                Expanded(
                  child: isFastMode
                      ? _buildFastDiffOverlay(context, state)
                      : _buildSplitView(context, state),
                ),

                // Bottom Collapsible Section: History & Confidence
                ReviewHistoryMetadataSection(state: state),

                // Bottom Action Bar
                ReviewActionBar(state: state),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildTriageStateBadge(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final l10n = context.l10n;
    Color bg;
    Color fg;
    String label = state.question.policyState;

    switch (state.question.policyState) {
      case 'BLOCKED':
        bg = AppColors.errorLight;
        fg = AppColors.error;
        label = l10n.reviewBlockedBadge;
        break;
      case 'REVIEW_FAST':
        bg = AppColors.successLight;
        fg = AppColors.success;
        label = l10n.reviewFastBadge;
        break;
      default:
        bg = AppColors.info.withValues(alpha: 0.15);
        fg = AppColors.info;
        label = l10n.reviewStandardBadge;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPriorityChip(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final score = state.question.priorityScore;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        context.l10n.priorityScoreBadge(score.toStringAsFixed(1)),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSplitView(BuildContext context, QuestionBankReviewLoaded state) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 850;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: ReviewEvidencePane(
                    state: state,
                    resolveStorageUrl: _resolveStorageUrl,
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  flex: 5,
                  child: ReviewQuestionPreviewPane(
                    state: state,
                    resolveStorageUrl: _resolveStorageUrl,
                  ),
                ),
              ],
            );
          } else {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                ReviewQuestionPreviewPane(
                  state: state,
                  resolveStorageUrl: _resolveStorageUrl,
                ),
                const Divider(height: 32),
                ReviewEvidencePane(
                  state: state,
                  resolveStorageUrl: _resolveStorageUrl,
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildFastDiffOverlay(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final theme = Theme.of(context);
    final rev = state.revision;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.s24),
        padding: const EdgeInsets.all(AppSpacing.s24),
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(color: AppColors.info, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flash_on, color: AppColors.warning),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  'Fast Review Mode (< 15s inspection)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            MathContentView(text: rev?.stemText ?? ''),
            const SizedBox(height: AppSpacing.s16),
            Text(
              'Answer: ${rev?.answerKey ?? 'Unknown'} (${rev?.answerStatus})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  String? _resolveStorageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    var clean = raw.startsWith('/') ? raw.substring(1) : raw;

    // Normalize crop URLs to the current question's real documentId
    try {
      final state = context.read<QuestionBankCubit>().state;
      if (state is QuestionBankReviewLoaded && clean.startsWith('crops/')) {
        final parts = clean.split('/');
        if (parts.length >= 3) {
          final filename = parts.sublist(2).join('/');
          clean = 'crops/${state.question.documentId}/$filename';
        }
      }
    } catch (_) {}

    return '${AppConfig.supabaseUrl}/storage/v1/object/public/qb-documents/$clean';
  }
}
