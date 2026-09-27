import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../cubit/question_bank_cubit.dart';
import '../cubit/question_bank_state.dart';
import '../widgets/deploy_document_exam_dialog.dart';

/// Shows the questions extracted from a specific document.
/// Drill-down from the documents list.
class DocumentQuestionsPage extends StatefulWidget {
  final String documentId;

  const DocumentQuestionsPage({super.key, required this.documentId});

  @override
  State<DocumentQuestionsPage> createState() => _DocumentQuestionsPageState();
}

class _DocumentQuestionsPageState extends State<DocumentQuestionsPage> {
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  void _loadQuestions() {
    context.read<QuestionBankCubit>().loadDocumentQuestions(
      widget.documentId,
      statusFilter: _selectedFilter,
    );
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    context.read<QuestionBankCubit>().loadDocumentQuestions(
      widget.documentId,
      statusFilter: filter,
    );
  }

  Future<void> _confirmDeleteQuestion(
    BuildContext context,
    QuestionEntity question,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteQuestionTitle),
        content: Text(l10n.deleteQuestionConfirm(question.sourceLabel)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.deleteAction),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<QuestionBankCubit>().deleteQuestion(question.id);
    }
  }

  Future<void> _openDeployExamDialog(
    BuildContext context,
    DocumentEntity doc,
    List<QuestionEntity> questions,
  ) async {
    final result = await DeployDocumentExamDialog.show(
      context,
      document: doc,
      questions: questions,
    );

    if (result != null && context.mounted) {
      final examId = result['examId'];
      final groupId = result['groupId'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.examCreatedSuccess),
          backgroundColor: AppColors.success,
          action: SnackBarAction(
            label: context.l10n.view,
            textColor: Colors.white,
            onPressed: () {
              context.push(
                '${AppRoutes.teacherExams}?groupId=$groupId&examId=$examId',
              );
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: BlocConsumer<QuestionBankCubit, QuestionBankState>(
        listener: (context, state) {
          if (state is QuestionBankError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is QuestionBankLoading) {
            return const Center(
              child: AppLoadingView.cardsGrid(count: 6, columns: 2),
            );
          }

          if (state is QuestionBankError) {
            return AppErrorView(
              message: state.message,
              onRetry: _loadQuestions,
            );
          }

          if (state is! QuestionBankDocumentQuestionsLoaded) {
            return const Center(
              child: AppLoadingView.cardsGrid(count: 6, columns: 2),
            );
          }

          final doc = state.document;
          final questions = state.questions;
          final dateFormat = DateFormat('yyyy/MM/dd  HH:mm');

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Document Header ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.s24,
                    AppSpacing.s16,
                    AppSpacing.s24,
                    AppSpacing.s16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back button + Document name
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_rounded),
                            onPressed: () {
                              context.read<QuestionBankCubit>().loadDocuments();
                              context.pop();
                            },
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  doc.displayName,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${doc.originalFilename}  •  ${dateFormat.format(doc.createdAt)}'
                                  '${doc.pageCount != null ? '  •  ${l10n.pageCountBadge(doc.pageCount!)}' : ''}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (questions.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.s8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s12,
                                  vertical: AppSpacing.s8,
                                ),
                              ),
                              icon: const Icon(Icons.bolt_rounded, size: 18),
                              label: Text(l10n.createInstantExamAction),
                              onPressed: () => _openDeployExamDialog(
                                context,
                                doc,
                                questions,
                              ),
                            ),
                          ],
                          const SizedBox(width: AppSpacing.s8),
                          IconButton.filledTonal(
                            tooltip: l10n.refreshTooltip,
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            onPressed: _loadQuestions,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(
                              label: l10n.filterAll,
                              count: state.questions.length,
                              isSelected: _selectedFilter == 'all',
                              onSelected: () => _onFilterChanged('all'),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            _buildFilterChip(
                              label: l10n.filterExtracted,
                              count: state.extractedCount,
                              isSelected: _selectedFilter == 'extracted',
                              onSelected: () => _onFilterChanged('extracted'),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            _buildFilterChip(
                              label: l10n.filterReviewRequired,
                              count: state.reviewCount,
                              isSelected: _selectedFilter == 'review_required',
                              activeColor: AppColors.warning,
                              onSelected: () =>
                                  _onFilterChanged('review_required'),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            _buildFilterChip(
                              label: l10n.filterApproved,
                              count: state.approvedCount,
                              isSelected: _selectedFilter == 'approved',
                              activeColor: AppColors.primary,
                              onSelected: () => _onFilterChanged('approved'),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            _buildFilterChip(
                              label: l10n.filterPublished,
                              count: state.publishedCount,
                              isSelected: _selectedFilter == 'published',
                              activeColor: AppColors.success,
                              onSelected: () => _onFilterChanged('published'),
                            ),
                            const SizedBox(width: AppSpacing.s6),
                            _buildFilterChip(
                              label: l10n.statusQuarantined,
                              count: state.quarantinedCount,
                              isSelected: _selectedFilter == 'quarantined',
                              activeColor: AppColors.error,
                              onSelected: () => _onFilterChanged('quarantined'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s16)),

              // ── Questions Grid ────────────────────────────────────────
              if (questions.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: AppEmptyView(
                      icon: Icons.quiz_outlined,
                      message: l10n.noQuestionsInDocumentTitle,
                      subtitle: l10n.noQuestionsInDocumentSubtitle,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 460,
                          mainAxisSpacing: AppSpacing.s16,
                          crossAxisSpacing: AppSpacing.s16,
                          mainAxisExtent: 200,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final question = questions[index];
                      return _QuestionCard(
                        key: ValueKey('q_${question.id}'),
                        question: question,
                        onDelete: () =>
                            _confirmDeleteQuestion(context, question),
                      );
                    }, childCount: questions.length),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s32)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required int count,
    required bool isSelected,
    required VoidCallback onSelected,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? AppColors.primary;

    return FilterChip(
      selected: isSelected,
      selectedColor: effectiveColor.withValues(alpha: 0.15),
      checkmarkColor: effectiveColor,
      side: BorderSide(color: isSelected ? effectiveColor : AppColors.border),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? effectiveColor : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: isSelected
                  ? effectiveColor
                  : AppColors.surfaceVariant.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      onSelected: (_) => onSelected(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Question Card (within document context)
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  final QuestionEntity question;
  final VoidCallback onDelete;

  const _QuestionCard({
    super.key,
    required this.question,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isMcq = question.questionType == 'multiple_choice';
    final dateFormat = DateFormat('yyyy/MM/dd');

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s12),
      onTap: () => context.push('/teacher/question-bank/review/${question.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Top: Icon + Label + Status ──────────────────────────────
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isMcq
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Icon(
                        isMcq
                            ? Icons.format_list_bulleted_rounded
                            : Icons.pin_outlined,
                        color: isMcq ? AppColors.primary : AppColors.warning,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.sourceLabel.isNotEmpty
                              ? question.sourceLabel
                              : 'Question',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          isMcq ? l10n.multipleChoice : l10n.gridIn,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(context, question.status),
                ],
              ),
              const SizedBox(height: AppSpacing.s8),

              // Context badges
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (question.priorityScore > 0)
                    _Badge(
                      icon: Icons.priority_high_rounded,
                      text: l10n.priorityScoreBadge(
                        question.priorityScore.toStringAsFixed(1),
                      ),
                      color: AppColors.error,
                    ),
                  if (question.requiresSecondReview)
                    _Badge(
                      icon: Icons.rate_review_rounded,
                      text: l10n.secondReviewRequiredBadge,
                      color: AppColors.warning,
                    ),
                  if (question.duplicateClusterId != null)
                    _Badge(
                      icon: Icons.content_copy_rounded,
                      text: l10n.duplicateClusterTitle,
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ],
          ),

          // ── Bottom: Date + Actions ────────────────────────────────
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 12,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dateFormat.format(question.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => context.push(
                  '/teacher/question-bank/review/${question.id}',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tune_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n.reviewAndAuditAction,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    final l10n = context.l10n;
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (status) {
      case 'published':
        bg = AppColors.success.withValues(alpha: 0.12);
        fg = AppColors.success;
        icon = Icons.check_circle_outline_rounded;
        label = l10n.statusPublished;
      case 'approved':
        bg = AppColors.primary.withValues(alpha: 0.12);
        fg = AppColors.primary;
        icon = Icons.verified_outlined;
        label = l10n.statusApproved;
      case 'review_required':
        bg = AppColors.warning.withValues(alpha: 0.12);
        fg = AppColors.warning;
        icon = Icons.rate_review_outlined;
        label = l10n.statusReviewRequired;
      case 'quarantined':
        bg = AppColors.error.withValues(alpha: 0.12);
        fg = AppColors.error;
        icon = Icons.warning_amber_rounded;
        label = l10n.statusQuarantined;
      default:
        bg = AppColors.surfaceVariant;
        fg = AppColors.textSecondary;
        icon = Icons.auto_awesome_outlined;
        label = l10n.statusExtracted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Badge({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
