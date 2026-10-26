import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../question_bank/presentation/widgets/question_display_widgets.dart';
import '../../domain/entities/exam_entity.dart';
import '../../domain/entities/saved_question_entity.dart';
import '../../../../core/utils/app_feedback.dart';
import '../widgets/exam_image_viewer.dart';
import '../extensions/exam_ui_extensions.dart';

class ExamReviewPage extends StatefulWidget {
  final String attemptId;
  final ExamEntity? exam;
  final ExamAttemptEntity? initialAttempt;
  final int initialQuestionIndex;

  const ExamReviewPage({
    super.key,
    required this.attemptId,
    this.exam,
    this.initialAttempt,
    this.initialQuestionIndex = 0,
  });

  @override
  State<ExamReviewPage> createState() => _ExamReviewPageState();
}

class _ExamReviewPageState extends State<ExamReviewPage> {
  ExamAttemptEntity? _attempt;
  bool _isLoading = true;
  String? _errorMessage;
  int _currentQuestionIndex = 0;
  final Set<String> _savedQuestionIds = {};

  @override
  void initState() {
    super.initState();
    _currentQuestionIndex = widget.initialQuestionIndex;
    _initSavedQuestions();
    if (widget.initialAttempt != null &&
        widget.initialAttempt!.questions.isNotEmpty) {
      _attempt = widget.initialAttempt;
      if (_currentQuestionIndex >= _attempt!.questions.length) {
        _currentQuestionIndex = 0;
      }
      _isLoading = false;
    } else {
      _loadReview();
    }
  }

  Future<void> _initSavedQuestions() async {
    try {
      final res = await InjectionContainer.savedQuestionsRepository.getSavedQuestions();
      if (res.isSuccess && res.dataOrNull != null && mounted) {
        setState(() {
          _savedQuestionIds.addAll(res.dataOrNull!.map((q) => q.questionId));
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSaveQuestionToVault(
    ExamQuestionEntity question,
    ExamAnswerEntity? answer,
    int qIndex,
  ) async {
    final isSaved = _savedQuestionIds.contains(question.id);
    if (isSaved) {
      setState(() => _savedQuestionIds.remove(question.id));
      await InjectionContainer.savedQuestionsRepository.removeSavedQuestion(question.id);
      if (!mounted || !context.mounted) return;
      AppFeedback.showInfo(context, context.l10n.removedFromVaultSuccess);
    } else {
      setState(() => _savedQuestionIds.add(question.id));
      final correctOpt = question.options.cast<QuestionOptionEntity?>().firstWhere(
        (QuestionOptionEntity? o) => o?.isCorrect == true,
        orElse: () => null,
      );
      final isMistake = answer?.isCorrect != true;

      final saved = SavedQuestionEntity(
        id: 'sq_${question.id}',
        questionId: question.id,
        examId: widget.exam?.id ?? _attempt?.examId ?? '',
        examTitle: widget.exam?.title ?? '',
        questionText: question.questionText,
        questionImageUrl: question.imageUrl,
        options: question.options,
        savedAt: DateTime.now(),
        userAnswerOptionId: answer?.selectedOptionId,
        correctOptionId: correctOpt?.id,
        questionIndex: qIndex + 1,
        isPdfQuestion: widget.exam?.hasAttachedPdf == true,
        pdfUrl: widget.exam?.pdfStoragePath,
        isMastered: !isMistake,
        difficultyRating: isMistake ? QuestionDifficultyRating.hard : QuestionDifficultyRating.easy,
      );
      await InjectionContainer.savedQuestionsRepository.saveQuestion(saved);
      if (!mounted || !context.mounted) return;
      AppFeedback.showSuccess(context, context.l10n.savedToMistakeVaultSuccess);
    }
  }

  Future<void> _loadReview() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await InjectionContainer.examsRepository.getAttemptDetails(
      widget.attemptId,
    );

    if (!mounted) return;

    res.when(
      onSuccess: (attempt) {
        setState(() {
          _attempt = attempt;
          if (_currentQuestionIndex >= attempt.questions.length &&
              attempt.questions.isNotEmpty) {
            _currentQuestionIndex = 0;
          }
          _isLoading = false;
        });
      },
      onFailure: (failure) {
        setState(() {
          _errorMessage = failure.message;
          _isLoading = false;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewExamTitle), centerTitle: true),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: AppLoadingView.signature());
    }

    if (_errorMessage != null) {
      return Center(
        child: AppErrorView(message: _errorMessage!, onRetry: _loadReview),
      );
    }

    final attempt = _attempt;
    if (attempt == null || attempt.questions.isEmpty) {
      return Center(
        child: AppEmptyView(
          message: context.l10n.noAnswersRecorded,
          icon: Icons.quiz_outlined,
        ),
      );
    }

    final questions = attempt.questions;
    final currentIndex = _currentQuestionIndex.clamp(0, questions.length - 1);
    final question = questions[currentIndex];
    final answer = attempt.answers.cast<ExamAnswerEntity?>().firstWhere(
      (a) => a?.questionId == question.id,
      orElse: () => null,
    );

    final maxScore =
        widget.exam?.maxScore ??
        questions.fold<int>(0, (sum, q) => sum + q.points);
    final passScore = widget.exam?.passingScore;
    final isPassed = attempt.isPassed(passScore);

    return Column(
      children: [
        // ── Top Summary Header Card ───────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.exam?.title ?? context.l10n.reviewExamTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (isPassed
                                            ? AppColors.success
                                            : AppColors.error)
                                        .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isPassed
                                    ? context.l10n.statusCompleted
                                    : context.l10n.statusFailed,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isPassed
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: attempt.submissionReason.color
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    attempt.submissionReason.icon,
                                    size: 11,
                                    color: attempt.submissionReason.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    attempt.submissionReason.localizedLabel(context),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: attempt.submissionReason.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Text(
                              '${attempt.score ?? 0} / $maxScore (${(attempt.percentage ?? 0).toStringAsFixed(1)}%)',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // ── Question Jump Pills ─────────────────────────────────────
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: questions.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.s8),
                  itemBuilder: (ctx, idx) {
                    final q = questions[idx];
                    final qAns = attempt.answers
                        .cast<ExamAnswerEntity?>()
                        .firstWhere(
                          (a) => a?.questionId == q.id,
                          orElse: () => null,
                        );
                    final isAnsCorrect = qAns?.isCorrect == true;
                    final isCurrent = idx == currentIndex;

                    final bg = isAnsCorrect
                        ? AppColors.success.withValues(alpha: 0.15)
                        : AppColors.error.withValues(alpha: 0.15);
                    final borderCol = isCurrent
                        ? AppColors.primary
                        : (isAnsCorrect ? AppColors.success : AppColors.error);
                    final textCol = isAnsCorrect
                        ? AppColors.success
                        : AppColors.error;

                    return InkWell(
                      onTap: () => setState(() => _currentQuestionIndex = idx),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                          border: Border.all(
                            color: borderCol,
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '${idx + 1}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent
                                  ? FontWeight.w900
                                  : FontWeight.bold,
                              color: isCurrent ? AppColors.primary : textCol,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // ── Question Content ──────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question Header Card
                AppCard(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.l10n.reviewQuestionIndex(
                              currentIndex + 1,
                              questions.length,
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: (answer?.isCorrect == true
                                          ? AppColors.success
                                          : AppColors.error)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  context.l10n.pointsEarnedOutOf(
                                    (answer?.pointsEarned ?? 0).toInt(),
                                    question.points,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: answer?.isCorrect == true
                                        ? AppColors.success
                                        : AppColors.error,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              IconButton(
                                icon: Icon(
                                  _savedQuestionIds.contains(question.id)
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  color: _savedQuestionIds.contains(question.id)
                                      ? AppColors.warning
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                                tooltip: _savedQuestionIds.contains(question.id)
                                    ? context.l10n.removeFromVault
                                    : context.l10n.saveToMistakeVaultAction,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _toggleSaveQuestionToVault(
                                  question,
                                  answer,
                                  currentIndex,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          final hasExplicitImage = question.imageUrl != null &&
                              question.imageUrl!.trim().isNotEmpty;
                          final isTextAnImageUrl = QuestionStemView.isImageUrl(
                            question.questionText.trim(),
                          );
                          final effectiveImageUrl = hasExplicitImage
                              ? question.imageUrl!
                              : (isTextAnImageUrl
                                    ? question.questionText.trim()
                                    : null);
                          final shouldShowText =
                              question.questionText.trim().isNotEmpty &&
                              !isTextAnImageUrl;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (shouldShowText) ...[
                                const SizedBox(height: AppSpacing.s12),
                                Text(
                                  question.questionText,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                              if (effectiveImageUrl != null &&
                                  effectiveImageUrl.isNotEmpty)
                                ExamImageViewer(
                                  key: ValueKey(
                                    'review_q_${question.id}_$effectiveImageUrl',
                                  ),
                                  imageUrl: effectiveImageUrl,
                                  imageMeta: question.imageMeta,
                                  caption: context.l10n.reviewQuestionIndex(
                                    currentIndex + 1,
                                    questions.length,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s16),

                if (answer == null || answer.selectedOptionId == null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: AppSpacing.s12),
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      border: Border.all(color: AppColors.warning),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            context.l10n.unansweredQuestion,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Options List ──────────────────────────────────────────
                ...question.options.asMap().entries.map((entry) {
                  final optIndex = entry.key;
                  final opt = entry.value;

                  final isChosen = opt.id == answer?.selectedOptionId;
                  final isModelCorrect = opt.isCorrect == true;

                  Color borderCol = AppColors.border;
                  Color bgCol = AppColors.surface;
                  Widget? statusBadge;

                  if (isChosen && isModelCorrect) {
                    borderCol = AppColors.success;
                    bgCol = AppColors.success.withValues(alpha: 0.08);
                    statusBadge = _buildBadge(
                      context.l10n.yourCorrectAnswer,
                      Icons.check_circle_rounded,
                      AppColors.success,
                    );
                  } else if (isChosen && !isModelCorrect) {
                    borderCol = AppColors.error;
                    bgCol = AppColors.error.withValues(alpha: 0.08);
                    statusBadge = _buildBadge(
                      context.l10n.yourWrongAnswer,
                      Icons.cancel_rounded,
                      AppColors.error,
                    );
                  } else if (isModelCorrect) {
                    borderCol = AppColors.success;
                    bgCol = AppColors.success.withValues(alpha: 0.05);
                    statusBadge = _buildBadge(
                      context.l10n.correctAnswerLabel,
                      Icons.check_circle_outline_rounded,
                      AppColors.success,
                    );
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.s10),
                    padding: const EdgeInsets.all(AppSpacing.s14),
                    decoration: BoxDecoration(
                      color: bgCol,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      border: Border.all(
                        color: borderCol,
                        width: (isChosen || isModelCorrect) ? 1.8 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: (isChosen || isModelCorrect)
                                    ? borderCol
                                    : AppColors.surfaceVariant,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _getOptionLetter(context, optIndex),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: (isChosen || isModelCorrect)
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Text(
                                opt.optionText,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: (isChosen || isModelCorrect)
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (opt.imageUrl != null &&
                            opt.imageUrl!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.s8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSmall,
                            ),
                            child: CachedNetworkImage(
                              imageUrl: opt.imageUrl!,
                              height: 120,
                              memCacheWidth: 400,
                              memCacheHeight: 250,
                              maxWidthDiskCache: 600,
                              fit: BoxFit.contain,
                              placeholder: (ctx, _) => Container(
                                height: 120,
                                color: AppColors.surfaceVariant.withValues(alpha: 0.3),
                                child: const Center(
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                        ],
                        if (statusBadge != null) ...[
                          const SizedBox(height: AppSpacing.s8),
                          statusBadge,
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // ── Bottom Navigation Bar ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s12,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              if (currentIndex > 0)
                Expanded(
                  child: AppButton(
                    text: context.l10n.previousQuestion,
                    icon: Icons.arrow_back_rounded,
                    variant: AppButtonVariant.secondary,
                    onPressed: () {
                      setState(() => _currentQuestionIndex = currentIndex - 1);
                    },
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: AppSpacing.s12),
              if (currentIndex < questions.length - 1)
                Expanded(
                  child: AppButton(
                    text: context.l10n.nextQuestion,
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () {
                      setState(() => _currentQuestionIndex = currentIndex + 1);
                    },
                  ),
                )
              else
                Expanded(
                  child: AppButton(
                    text: context.l10n.backToExamsList,
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getOptionLetter(BuildContext context, int index) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final labels = isAr
        ? const ['أ', 'ب', 'ج', 'د', 'هـ', 'و']
        : const ['A', 'B', 'C', 'D', 'E', 'F'];
    if (index >= 0 && index < labels.length) {
      return labels[index];
    }
    return '${index + 1}';
  }
}
