import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';
import 'package:edu_saas/core/theme/app_spacing.dart';
import 'package:edu_saas/core/widgets/app_button.dart';
import 'package:edu_saas/core/widgets/app_empty_view.dart';
import 'package:edu_saas/core/widgets/app_error_view.dart';
import 'package:edu_saas/core/widgets/app_loading_view.dart';
import 'package:edu_saas/features/exams/domain/entities/saved_question_entity.dart';
import 'package:edu_saas/features/exams/presentation/cubit/saved_questions_cubit.dart';
import 'package:edu_saas/features/exams/presentation/cubit/saved_questions_state.dart';
import 'package:edu_saas/features/exams/presentation/widgets/vault/edit_personal_note_dialog.dart';
import 'package:edu_saas/features/exams/presentation/widgets/vault/saved_question_card.dart';
import 'package:edu_saas/features/exams/presentation/widgets/vault/spaced_repetition_header_card.dart';
import 'smart_practice_page.dart';

class SavedQuestionsVaultPage extends StatefulWidget {
  const SavedQuestionsVaultPage({super.key});

  @override
  State<SavedQuestionsVaultPage> createState() => _SavedQuestionsVaultPageState();
}

class _SavedQuestionsVaultPageState extends State<SavedQuestionsVaultPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<SavedQuestionsCubit>().loadSavedQuestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openPracticeSession(BuildContext context, List<SavedQuestionEntity> questions, {int initialIndex = 0}) {
    if (questions.isEmpty) return;
    final cubit = context.read<SavedQuestionsCubit>();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: SmartPracticePage(questions: questions, initialIndex: initialIndex),
        ),
      ),
    );
  }

  Future<void> _handleEditNote(BuildContext context, SavedQuestionEntity question) async {
    final updatedNote = await showEditPersonalNoteDialog(context, question.personalNote);
    if (updatedNote != null && context.mounted) {
      await context.read<SavedQuestionsCubit>().updateNote(question.questionId, updatedNote);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.savedQuestionsVaultTitle)),
      body: BlocBuilder<SavedQuestionsCubit, SavedQuestionsState>(
        builder: (context, state) {
          if (state is SavedQuestionsLoading) return const AppLoadingView();
          if (state is SavedQuestionsError) {
            return AppErrorView(
              message: state.message,
              onRetry: () => context.read<SavedQuestionsCubit>().loadSavedQuestions(),
            );
          }
          if (state is SavedQuestionsEmpty) {
            return AppEmptyView(
              message: context.l10n.emptyVaultTitle,
              subtitle: context.l10n.tacticalMistakeVaultSubtitle,
            );
          }
          if (state is SavedQuestionsLoaded) return _buildLoadedContent(context, state);
          return const SizedBox.shrink();
        },
      ),
      bottomNavigationBar: BlocBuilder<SavedQuestionsCubit, SavedQuestionsState>(
        builder: (context, state) {
          if (state is SavedQuestionsLoaded && state.filteredQuestions.isNotEmpty) {
            final targetList = state.dueTodayCount > 0 ? state.dueTodayQuestions : state.filteredQuestions;
            final buttonText = state.dueTodayCount > 0
                ? context.l10n.startDuePracticeAction(state.dueTodayCount)
                : context.l10n.startPracticeSession;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.s16),
                child: AppButton(
                  text: buttonText,
                  icon: state.dueTodayCount > 0 ? Icons.bolt_rounded : Icons.play_arrow_rounded,
                  onPressed: () => _openPracticeSession(context, targetList),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildLoadedContent(BuildContext context, SavedQuestionsLoaded state) {
    final filtered = state.filteredQuestions;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s12, AppSpacing.s12, 0),
          child: SpacedRepetitionHeaderCard(
            state: state,
            onStartDueReview: () => _openPracticeSession(context, state.dueTodayQuestions),
            onPracticeAll: () => _openPracticeSession(context, state.questions),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => context.read<SavedQuestionsCubit>().searchQuestions(val),
            decoration: InputDecoration(
              hintText: context.l10n.searchSavedQuestions,
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMedium)),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
          child: Row(
            children: [
              FilterChip(
                label: Text('${context.l10n.filterDueToday} (${state.dueTodayCount})'),
                selected: state.activeFilter == VaultFilterType.dueToday,
                onSelected: (_) => context.read<SavedQuestionsCubit>().filterByVaultType(VaultFilterType.dueToday),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilterChip(
                label: Text('${context.l10n.filterUpcoming} (${state.upcomingCount})'),
                selected: state.activeFilter == VaultFilterType.upcoming,
                onSelected: (_) => context.read<SavedQuestionsCubit>().filterByVaultType(VaultFilterType.upcoming),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilterChip(
                label: Text('${context.l10n.filterMastered} (${state.masteredCount})'),
                selected: state.activeFilter == VaultFilterType.mastered,
                onSelected: (_) => context.read<SavedQuestionsCubit>().filterByVaultType(VaultFilterType.mastered),
              ),
              const SizedBox(width: AppSpacing.s8),
              FilterChip(
                label: Text('${context.l10n.filterAllQuestions} (${state.questions.length})'),
                selected: state.activeFilter == VaultFilterType.all,
                onSelected: (_) => context.read<SavedQuestionsCubit>().filterByVaultType(VaultFilterType.all),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(context.l10n.emptyVaultTitle))
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s10),
                  itemBuilder: (ctx, idx) => SavedQuestionCard(
                    question: filtered[idx],
                    onRemove: () => unawaited(context.read<SavedQuestionsCubit>().removeQuestion(filtered[idx].questionId)),
                    onEditNote: () => unawaited(_handleEditNote(context, filtered[idx])),
                    onSolve: () => _openPracticeSession(context, filtered, initialIndex: idx),
                  ),
                ),
        ),
      ],
    );
  }
}
