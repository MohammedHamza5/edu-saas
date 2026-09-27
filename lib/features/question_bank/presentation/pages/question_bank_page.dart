import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/document_entity.dart';
import '../cubit/question_bank_cubit.dart';
import '../cubit/question_bank_state.dart';
import '../widgets/upload_exam_dialog.dart';

/// Document-Centric Question Bank — Main Screen.
/// Shows uploaded documents as cards with status, question count, and actions.
class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key});

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  @override
  void initState() {
    super.initState();
    context.read<QuestionBankCubit>().loadDocuments();
  }

  void _reload() {
    context.read<QuestionBankCubit>().loadDocuments();
  }

  Future<void> _confirmDeleteDocument(
    BuildContext context,
    DocumentEntity doc,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDocumentTitle),
        content: Text(l10n.deleteDocumentConfirm(doc.displayName)),
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
      await context.read<QuestionBankCubit>().deleteDocument(doc.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
              child: AppLoadingView.cardsGrid(count: 4, columns: 2),
            );
          }

          if (state is QuestionBankError) {
            return AppErrorView(message: state.message, onRetry: _reload);
          }

          final documents = state is QuestionBankDocumentsLoaded
              ? state.documents
              : <DocumentEntity>[];
          final lastUploadId = state is QuestionBankDocumentsLoaded
              ? state.lastUploadedDocumentId
              : null;

          if (documents.isEmpty && state is QuestionBankDocumentsLoaded) {
            return Center(
              child: AppEmptyView(
                icon: Icons.folder_open_rounded,
                message: l10n.emptyDocumentsTitle,
                subtitle: l10n.emptyDocumentsSubtitle,
                actionText: l10n.uploadExamFile,
                onAction: () => UploadExamDialog.show(context),
              ),
            );
          }

          // Stats
          final totalDocs = documents.length;
          final totalQuestions = documents.fold<int>(
            0,
            (sum, d) => sum + d.questionCount,
          );
          final doneDocs = documents.where((d) => d.isDone).length;
          final failedDocs = documents.where((d) => d.isFailed).length;
          final pendingDocs = documents
              .where((d) => d.isPending || d.isProcessing)
              .length;

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.surface,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.s24,
                      AppSpacing.s20,
                      AppSpacing.s24,
                      AppSpacing.s16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: AppSpacing.s16),
                        _buildStatsDeck(
                          context,
                          totalDocs: totalDocs,
                          totalQuestions: totalQuestions,
                          done: doneDocs,
                          failed: failedDocs,
                          pending: pendingDocs,
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.s16),
                ),

                // ── Documents Grid ──────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s24,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 500,
                          mainAxisSpacing: AppSpacing.s16,
                          crossAxisSpacing: AppSpacing.s16,
                          mainAxisExtent: 195,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final doc = documents[index];
                      final isHighlighted = doc.id == lastUploadId;
                      return _DocumentCard(
                        key: ValueKey('doc_${doc.id}'),
                        document: doc,
                        isHighlighted: isHighlighted,
                        onTap: doc.isDone
                            ? () => context.push(
                                '/teacher/question-bank/documents/${doc.id}',
                              )
                            : null,
                        onDelete: () => _confirmDeleteDocument(context, doc),
                        onRetry: doc.isFailed
                            ? () => context
                                  .read<QuestionBankCubit>()
                                  .retryDocumentIngestion(doc.id)
                            : null,
                      );
                    }, childCount: documents.length),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.s32),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;

        final titleColumn = Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                Icons.functions_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.s8,
                    runSpacing: 4,
                    children: [
                      Text(
                        l10n.questionBankTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          l10n.satDomainTag,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.questionBankSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final actionButtons = Wrap(
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AppButton(
              text: l10n.manualQuestionEntry,
              icon: Icons.add_rounded,
              variant: AppButtonVariant.outlined,
              onPressed: () => context.push('/teacher/question-bank/new'),
            ),
            AppButton(
              text: l10n.uploadExamFile,
              icon: Icons.upload_file_rounded,
              variant: AppButtonVariant.primary,
              onPressed: () => UploadExamDialog.show(context),
            ),
            IconButton.filledTonal(
              tooltip: l10n.refreshTooltip,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _reload,
            ),
          ],
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: AppSpacing.s12),
              actionButtons,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleColumn),
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _buildStatsDeck(
    BuildContext context, {
    required int totalDocs,
    required int totalQuestions,
    required int done,
    required int failed,
    required int pending,
  }) {
    final l10n = context.l10n;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        final items = [
          _StatDeckItem(
            label: l10n.statTotalDocuments,
            value: totalDocs,
            icon: Icons.description_outlined,
            color: AppColors.primary,
          ),
          _StatDeckItem(
            label: l10n.statTotalQuestions,
            value: totalQuestions,
            icon: Icons.quiz_outlined,
            color: AppColors.textPrimary,
          ),
          _StatDeckItem(
            label: l10n.statDocumentsDone,
            value: done,
            icon: Icons.check_circle_outline_rounded,
            color: AppColors.success,
          ),
          _StatDeckItem(
            label: l10n.statDocumentsPending,
            value: pending,
            icon: Icons.hourglass_top_rounded,
            color: AppColors.warning,
          ),
          _StatDeckItem(
            label: l10n.statDocumentsFailed,
            value: failed,
            icon: Icons.error_outline_rounded,
            color: AppColors.error,
          ),
        ];

        if (isNarrow) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppSpacing.s8,
                      ),
                      child: SizedBox(width: 155, child: item),
                    ),
                  )
                  .toList(),
            ),
          );
        }

        return Row(
          children: items
              .map(
                (item) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: item,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Deck Item
// ─────────────────────────────────────────────────────────────────────────────

class _StatDeckItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;

  const _StatDeckItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$value',
                  style: AppTypography.statFigureSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Document Card
// ─────────────────────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final DocumentEntity document;
  final bool isHighlighted;
  final VoidCallback? onTap;
  final VoidCallback onDelete;
  final VoidCallback? onRetry;

  const _DocumentCard({
    super.key,
    required this.document,
    this.isHighlighted = false,
    this.onTap,
    required this.onDelete,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dateFormat = DateFormat('yyyy/MM/dd  HH:mm');

    return AppCard(
      variant: AppCardVariant.elevated,
      padding: const EdgeInsets.all(AppSpacing.s16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // ── Top: Icon + Filename + Status ──────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(_statusIcon, color: _statusColor, size: 22),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      document.originalFilename,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusBadge(context),
            ],
          ),

          const SizedBox(height: AppSpacing.s8),

          // ── Middle: Metadata badges ────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (document.isDone)
                _MetadataBadge(
                  icon: Icons.quiz_outlined,
                  text: l10n.questionCountBadge(document.questionCount),
                  color: AppColors.primary,
                ),
              if (document.pageCount != null)
                _MetadataBadge(
                  icon: Icons.description_outlined,
                  text: l10n.pageCountBadge(document.pageCount!),
                  color: AppColors.textSecondary,
                ),
              if (document.fileSizeLabel.isNotEmpty)
                _MetadataBadge(
                  icon: Icons.storage_rounded,
                  text: document.fileSizeLabel,
                  color: AppColors.textSecondary,
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
                  dateFormat.format(document.createdAt),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              if (document.isFailed && onRetry != null) ...[
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onRetry,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.refresh_rounded,
                          size: 14,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.retryAction,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (document.isDone)
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: onTap,
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
                          Icons.visibility_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.viewQuestionsAction,
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

  Color get _statusColor {
    switch (document.status) {
      case 'done':
        return AppColors.success;
      case 'failed':
        return AppColors.error;
      case 'processing':
        return AppColors.primary;
      default:
        return AppColors.warning;
    }
  }

  IconData get _statusIcon {
    switch (document.status) {
      case 'done':
        return Icons.check_circle_rounded;
      case 'failed':
        return Icons.error_rounded;
      case 'processing':
        return Icons.sync_rounded;
      default:
        return Icons.hourglass_top_rounded;
    }
  }

  Widget _buildStatusBadge(BuildContext context) {
    final l10n = context.l10n;
    String label;
    switch (document.status) {
      case 'done':
        label = l10n.statusDone;
        break;
      case 'failed':
        label = l10n.statusFailed;
        break;
      case 'processing':
        label = l10n.statusProcessing;
        break;
      default:
        label = l10n.statusPending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _statusColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (document.isProcessing)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: _statusColor,
                ),
              ),
            )
          else
            Icon(_statusIcon, size: 12, color: _statusColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: _statusColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metadata Badge
// ─────────────────────────────────────────────────────────────────────────────

class _MetadataBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _MetadataBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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
