import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/document_entity.dart';
import '../cubit/question_bank_cubit.dart';
import '../cubit/question_bank_state.dart';
import '../widgets/question_bank_document_card.dart';
import '../widgets/question_bank_header.dart';
import '../widgets/question_bank_stats_deck.dart';
import '../widgets/upload_exam_dialog.dart';

/// Document-Centric Question Bank — Main Screen.
/// Shows uploaded documents as cards with status, question count, and actions.
class QuestionBankPage extends StatefulWidget {
  const QuestionBankPage({super.key});

  @override
  State<QuestionBankPage> createState() => _QuestionBankPageState();
}

class _QuestionBankPageState extends State<QuestionBankPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<QuestionBankCubit>().loadDocuments();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      context.read<QuestionBankCubit>().loadMoreDocuments();
    }
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
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── Header & Stats Deck ──────────────────────────────────
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
                        QuestionBankHeader(
                          onReload: _reload,
                          onManualEntry: () =>
                              context.push('/teacher/question-bank/new'),
                          onUploadExam: () => UploadExamDialog.show(context),
                        ),
                        const SizedBox(height: AppSpacing.s16),
                        QuestionBankStatsDeck(
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
                      return QuestionBankDocumentCard(
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

                if (state is QuestionBankDocumentsLoaded &&
                    state.isLoadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                      child: Center(
                        child: AppLoadingView.compact(size: 24),
                      ),
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
}
