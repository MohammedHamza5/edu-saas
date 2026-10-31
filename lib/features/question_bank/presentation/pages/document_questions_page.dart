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
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../cubit/question_bank_cubit.dart';
import '../cubit/question_bank_state.dart';
import '../widgets/deploy_document_exam_dialog.dart';
import '../widgets/document_question_card.dart';
import '../widgets/document_questions_header.dart';

/// Shows the questions extracted from a specific document.
/// Drill-down from the documents list.
class DocumentQuestionsPage extends StatefulWidget {
  final String documentId;

  const DocumentQuestionsPage({super.key, required this.documentId});

  @override
  State<DocumentQuestionsPage> createState() => _DocumentQuestionsPageState();
}

class _DocumentQuestionsPageState extends State<DocumentQuestionsPage> {
  final ScrollController _scrollController = ScrollController();
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadQuestions();
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
      context.read<QuestionBankCubit>().loadMoreDocumentQuestions();
    }
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

          return CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Document Header ───────────────────────────────────────
              SliverToBoxAdapter(
                child: DocumentQuestionsHeader(
                  doc: doc,
                  questions: questions,
                  state: state,
                  selectedFilter: _selectedFilter,
                  onRefresh: _loadQuestions,
                  onFilterChanged: _onFilterChanged,
                  onDeployExam: () => _openDeployExamDialog(
                    context,
                    doc,
                    questions,
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
                      return DocumentQuestionCard(
                        key: ValueKey('q_${question.id}'),
                        question: question,
                        onDelete: () =>
                            _confirmDeleteQuestion(context, question),
                      );
                    }, childCount: questions.length),
                  ),
                ),

              if (state.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                    child: Center(
                      child: AppLoadingView.compact(size: 24),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.s32)),
            ],
          );
        },
      ),
    );
  }
}
