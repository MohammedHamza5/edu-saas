import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/question_revision_entity.dart';
import '../../domain/entities/validation_issue_entity.dart';
import '../cubit/question_bank_cubit.dart';
import '../cubit/question_bank_state.dart';
import '../widgets/math_content_view.dart';
import '../widgets/question_display_widgets.dart';

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
                // Top Issues Banner
                if (state.issues.isNotEmpty)
                  _buildIssuesBanner(context, state)
                else
                  _buildCleanBanner(context, state),

                // Duplicate Cluster Notice (if detected)
                if (state.question.duplicateClusterId != null)
                  _buildDuplicateClusterBanner(context, state),

                // Main Area: Split Pane or Fast Diff Overlay
                Expanded(
                  child: isFastMode
                      ? _buildFastDiffOverlay(context, state)
                      : _buildSplitView(context, state),
                ),

                // Bottom Collapsible Section: History & Confidence
                _buildHistoryAndMetadataSection(context, state),

                // Bottom Action Bar
                _buildActionBar(context, state),
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

  Widget _buildCleanBanner(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final l10n = context.l10n;
    final rev = state.revision;
    final hasAnswer =
        rev != null && rev.answerKey != null && rev.answerKey!.isNotEmpty;
    final hasStem =
        rev != null &&
        (rev.stemText.trim().isNotEmpty || rev.stemBlocks.isNotEmpty);

    if (!hasAnswer || !hasStem) {
      return Container(
        width: double.infinity,
        color: AppColors.info.withAlpha(40),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s16,
          vertical: AppSpacing.s8,
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.info, size: 20),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text(
                l10n.statusReviewRequired,
                style: const TextStyle(
                  color: AppColors.info,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: AppColors.successLight.withAlpha(50),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              l10n.noBlockersMessage,
              style: const TextStyle(
                color: AppColors.success,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDuplicateClusterBanner(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      color: AppColors.warningLight.withAlpha(60),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s6,
      ),
      child: Row(
        children: [
          const Icon(Icons.copy_outlined, color: AppColors.warning, size: 18),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              '${l10n.possibleDuplicateNotice} cluster [${state.question.duplicateClusterId}]',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuesBanner(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    return Container(
      width: double.infinity,
      color: state.hasBlockers
          ? AppColors.errorLight.withAlpha(45)
          : AppColors.warningLight.withAlpha(45),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                state.hasBlockers ? Icons.block : Icons.warning_amber_rounded,
                color: state.hasBlockers ? AppColors.error : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                l10n.validationBlockers,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: state.hasBlockers
                      ? AppColors.error
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: AppSpacing.s6,
            runSpacing: AppSpacing.s6,
            children: state.issues.map((issue) {
              final isAcked =
                  state.acknowledgedIssueIds.contains(issue.id) ||
                  issue.isResolved;
              final isBlocker = issue.isBlocker && !isAcked;

              return ActionChip(
                avatar: CircleAvatar(
                  backgroundColor: isAcked
                      ? AppColors.success
                      : (isBlocker ? AppColors.error : AppColors.warning),
                  radius: 10,
                  child: Icon(
                    isAcked ? Icons.check : Icons.priority_high,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
                label: Text(
                  '${issue.ruleId}: ${issue.getLocalizedMessage(locale)}',
                  style: TextStyle(
                    fontSize: 12,
                    decoration: isAcked ? TextDecoration.lineThrough : null,
                  ),
                ),
                onPressed: () => _showIssueAcknowledgmentDialog(context, issue),
              );
            }).toList(),
          ),
        ],
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
                Expanded(flex: 5, child: _buildEvidencePane(context, state)),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(flex: 5, child: _buildPreviewPane(context, state)),
              ],
            );
          } else {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                _buildPreviewPane(context, state),
                const Divider(height: 32),
                _buildEvidencePane(context, state),
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

  Widget _buildEvidencePane(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final rev = state.revision;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.questionDetailsAndSource,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // High-level human readable details
          _buildInfoTile(l10n.questionSourceLabel, state.question.sourceLabel),
          _buildInfoTile(
            l10n.questionTypeLabel,
            state.question.questionType == 'multiple_choice'
                ? l10n.typeMultipleChoice
                : l10n.typeGridIn,
          ),
          _buildInfoTile(
            l10n.questionStatusLabel,
            _getLocalizedStatus(context, state.question.status),
          ),
          if (rev != null) ...[
            _buildInfoTile(l10n.answerKeyLabel, rev.answerKey ?? 'N/A'),
            _buildInfoTile(
              l10n.answerStatusLabel,
              _getLocalizedAnswerStatus(context, rev.answerStatus),
            ),
            Builder(
              builder: (context) {
                final rawCrop =
                    rev.provenance['crop_url']?.toString() ??
                    rev.provenance['image_url']?.toString();
                final cropUrl = rawCrop;
                if (cropUrl == null || cropUrl.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.s12,
                    bottom: AppSpacing.s12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.originalEvidence,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      MathContentView(text: '', assetUrl: cropUrl),
                    ],
                  ),
                );
              },
            ),

            // Collapsible technical details for developers/auditors
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  l10n.technicalAuditDetails,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  _buildInfoTile(l10n.questionIdLabel, state.question.id),
                  _buildInfoTile(
                    l10n.activeRevisionLabel,
                    'v${rev.revNo} (${rev.createdVia ?? 'pipeline'})',
                  ),
                  _buildInfoTile(l10n.contentHashLabel, rev.contentHash),
                  if (rev.sourceRefs.isNotEmpty)
                    _buildInfoTile(
                      l10n.sourceRefsLabel,
                      rev.sourceRefs.join(', '),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreviewPane(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final rev = state.revision;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── عنوان القسم ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.studentPreview,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (state.question.isPublished)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    l10n.statusPublished,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),

          // ── نص السؤال (Stem) ──────────────────────────────────
          // الآن: اللوجة (AI) حوّلته لنص رقمي نظيف، الصور تظهر فقط للرسوم الحقيقية
          _buildStemSection(context, state),
          const SizedBox(height: AppSpacing.s24),

          // ── الخيارات A-D ──────────────────────────────────────
          if (rev != null && rev.options.isNotEmpty) ...[
            Row(
              children: [
                Text(
                  l10n.optionsLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                // إشعار للمدرس باختيار الإجابة
                if (rev.answerStatus == 'unknown')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.info.withAlpha(20),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.info.withAlpha(60),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.touch_app_rounded,
                            size: 13, color: AppColors.info),
                        const SizedBox(width: 4),
                        Text(
                          l10n.tapToSelectAnswer,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (rev.answerStatus == 'teacher_confirmed')
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 13, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          l10n.teacherConfirmedStatus,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s12),

            ...rev.options.map((opt) {
              final key = opt['key']?.toString() ?? '';
              final isCorrect = key == rev.answerKey;
              final contentList = opt['content'];
              String text = '';
              String? optAssetUrl;
              if (contentList is List && contentList.isNotEmpty) {
                final first = contentList.first;
                if (first is Map) {
                  text = first['latex']?.toString() ??
                      first['value']?.toString() ??
                      '';
                  if (first['type'] == 'asset') {
                    final rawOpt =
                        first['crop_asset'] ?? first['path'] ?? first['url'];
                    optAssetUrl = _resolveStorageUrl(rawOpt?.toString());
                  }
                }
              }

              return OptionCard(
                optionKey: key,
                text: text,
                assetUrl: optAssetUrl,
                isSelected: isCorrect,
                isInteractive: rev.answerStatus == 'unknown' ||
                    rev.answerStatus == 'ai_proposed' ||
                    rev.answerStatus == 'conflict',
                onTap: () =>
                    context.read<QuestionBankCubit>().selectAnswer(key),
              );
            }),
          ],
        ],
      ),
    );
  }

  /// بناء قسم نص السؤال — الآن يستخدم QuestionStemView الجديد
  Widget _buildStemSection(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final rev = state.revision;

    // ── الحالة: لا يوجد محتوى بعد ──
    if (rev == null || (rev.stemBlocks.isEmpty && rev.stemText.trim().isEmpty)) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: AppColors.warningLight.withAlpha(30),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(color: AppColors.warning.withAlpha(60)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppColors.warning, size: 20),
            const SizedBox(width: AppSpacing.s8),
            Text(
              l10n.stemNotExtracted,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ],
        ),
      );
    }

    // ── الحالة: يوجد blocks (الطريقة الجديدة من AI أو الهيكل الأصلي) ──
    if (rev.stemBlocks.isNotEmpty) {
      // فحص إذا كان AI عمل تحويل (توجد flag)
      final wasEnriched = rev.flags.any(
        (Object? f) => f.toString().startsWith('ai_enriched'),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge إذا AI عمل على السؤال
          if (wasEnriched)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 14,
                      color: theme.colorScheme.primary.withAlpha(180)),
                  const SizedBox(width: 4),
                  Text(
                    l10n.aiEnrichedBadge,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary.withAlpha(180),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // السؤال كاملاً — QuestionStemView يعرض كل block بطريقته الصحيحة
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: theme.colorScheme.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(8),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // رقم السؤال
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        state.question.sourceLabel
                            .replaceAll(RegExp(r'[^0-9]'), ''),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Text(
                      state.question.sourceLabel,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),

                // نص السؤال الكامل
                QuestionStemView(
                  blocks: rev.stemBlocks
                      .map((b) => Map<String, dynamic>.from(b as Map))
                      .toList(),
                  resolveUrl: _resolveStorageUrl,
                  fontSize: 15,
                ),

                // زر تعديل السؤال
                const SizedBox(height: AppSpacing.s8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () => _showStemEditDialog(context, rev),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: Text(l10n.editStemAction),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ── الحالة: نص stemText بسيط (الطريقة القديمة) ──
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: MathContentView(text: rev.stemText),
    );
  }

  /// ديالوج تعديل نص السؤال كاملاً
  void _showStemEditDialog(
    BuildContext context,
    QuestionRevisionEntity rev,
  ) {
    // نجمع كل blocks نصية في controller واحد للتعديل السريع
    final allText = rev.stemBlocks
        .where((Map<String, dynamic> b) => (b['type'] ?? 'text') == 'text')
        .map((Map<String, dynamic> b) => b['value']?.toString() ?? '')
        .join('\n')
        .trim();

    final firstBlock = rev.stemBlocks.isNotEmpty
        ? rev.stemBlocks[0]['id']?.toString() ?? 'stem_1'
        : 'stem_1';

    _showBlockEditDialog(context, firstBlock, allText);
  }

  Widget _buildHistoryAndMetadataSection(
    BuildContext context,
    QuestionBankReviewLoaded state,
  ) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    if (state.revisionHistory.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 70,
      color: theme.colorScheme.surfaceContainerHighest.withAlpha(30),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s8,
      ),
      child: Row(
        children: [
          Text(
            l10n.revisionHistoryTitle,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: state.revisionHistory.length,
              itemBuilder: (context, index) {
                final rev = state.revisionHistory[index];
                final isCurrent = rev.id == state.revision?.id;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    avatar: CircleAvatar(
                      radius: 8,
                      backgroundColor: isCurrent
                          ? AppColors.primary
                          : Colors.grey,
                      child: Text(
                        '${rev.revNo}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                        ),
                      ),
                    ),
                    label: Text(
                      'v${rev.revNo} ${rev.createdVia ?? ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCurrent
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onPressed: isCurrent
                        ? null
                        : () => context
                              .read<QuestionBankCubit>()
                              .restoreRevision(rev.id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalizedStatus(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
      case 'published':
        return l10n.statusPublished;
      case 'approved':
        return l10n.statusApproved;
      case 'review_required':
        return l10n.statusReviewRequired;
      case 'quarantined':
        return l10n.statusQuarantined;
      default:
        return l10n.statusExtracted;
    }
  }

  String _getLocalizedAnswerStatus(BuildContext context, String? answerStatus) {
    final l10n = context.l10n;
    switch (answerStatus) {
      case 'teacher_confirmed':
        return l10n.teacherConfirmedStatus;
      case 'solver_verified':
        return l10n.solverVerifiedStatus;
      case 'source_extracted':
        return l10n.sourceExtractedStatus;
      default:
        return answerStatus ?? 'N/A';
    }
  }

  Widget _buildActionBar(BuildContext context, QuestionBankReviewLoaded state) {
    final l10n = context.l10n;
    final rev = state.revision;
    final isApproved = state.question.isApproved || state.question.isPublished;
    final isPublished = state.question.isPublished;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side structural actions: Merge, Split, Unreadable
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _confirmMerge(context),
                icon: const Icon(Icons.merge_type, size: 16),
                label: Text(l10n.mergeWithNextAction),
              ),
              const SizedBox(width: AppSpacing.s8),
              OutlinedButton.icon(
                onPressed: () => _confirmSplit(context),
                icon: const Icon(Icons.call_split, size: 16),
                label: Text(l10n.splitQuestionAction),
              ),
              const SizedBox(width: AppSpacing.s8),
              OutlinedButton.icon(
                onPressed: () => _confirmMarkUnreadable(context),
                icon: const Icon(Icons.visibility_off, size: 16),
                label: Text(l10n.markUnreadableAction),
              ),
            ],
          ),

          // Right side approval / publish actions
          Row(
            children: [
              if (!isApproved) ...[
                AppButton(
                  text: l10n.approveRevision,
                  icon: Icons.thumb_up,
                  isLoading: state.isActionLoading,
                  onPressed: state.hasBlockers || rev == null
                      ? null
                      : () {
                          context.read<QuestionBankCubit>().approveRevision(
                            revisionId: rev.id,
                            contentHash: rev.contentHash,
                          );
                        },
                ),
                const SizedBox(width: AppSpacing.s16),
              ],
              if (!isPublished) ...[
                AppButton(
                  text: l10n.publishToStudents,
                  icon: Icons.send,
                  isLoading: state.isActionLoading,
                  onPressed: !isApproved || state.hasBlockers || rev == null
                      ? null
                      : () {
                          context.read<QuestionBankCubit>().publishRevision(
                            revisionId: rev.id,
                          );
                        },
                ),
              ] else ...[
                Chip(
                  avatar: const Icon(
                    Icons.check,
                    color: AppColors.success,
                    size: 18,
                  ),
                  label: Text(
                    l10n.statusPublished,
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  backgroundColor: AppColors.successLight,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String? _resolveStorageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return '${AppConfig.supabaseUrl}/storage/v1/object/public/qb-documents/$clean';
  }

  void _showIssueAcknowledgmentDialog(
    BuildContext context,
    ValidationIssueEntity issue,
  ) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).languageCode;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${l10n.confirmIssueDialogTitle}: ${issue.ruleId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(issue.getLocalizedMessage(locale)),
            const SizedBox(height: 12),
            Text(
              l10n.confirmIssuePrompt,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(l10n.cancelAction),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              context.read<QuestionBankCubit>().acknowledgeIssue(issue.id);
            },
            child: Text(l10n.acknowledgeIssueAction),
          ),
        ],
      ),
    );
  }

  void _showBlockEditDialog(
    BuildContext context,
    String blockId,
    String initialValue,
  ) {
    final l10n = context.l10n;
    final isCropPath = initialValue.startsWith('crops/');
    final textController = TextEditingController(
      text: isCropPath ? '' : initialValue,
    );
    String selectedReason = 'ocr_error';

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${l10n.editBlockDialogTitle} [$blockId]'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: textController,
                maxLines: 4,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: l10n.blockContentLabel,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedReason,
                decoration: InputDecoration(
                  labelText: l10n.editReasonLabel,
                  border: const OutlineInputBorder(),
                ),
                items: [
                  DropdownMenuItem(
                    value: 'ocr_error',
                    child: Text(l10n.ocrErrorCorrection),
                  ),
                  DropdownMenuItem(
                    value: 'source_image_correction',
                    child: Text(l10n.sourceImageCorrection),
                  ),
                  DropdownMenuItem(
                    value: 'source_typo_fix',
                    child: Text(l10n.sourceTypoFix),
                  ),
                  DropdownMenuItem(
                    value: 'teacher_answer_confirmation',
                    child: Text(l10n.teacherAnswerConfirmation),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setDialogState(() => selectedReason = val);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.cancelAction),
            ),
            ElevatedButton(
              onPressed: () {
                final text = textController.text.trim();
                Navigator.pop(dialogCtx);
                context.read<QuestionBankCubit>().editBlock(
                  blockId: blockId,
                  newValue: text,
                  reason: selectedReason,
                );
              },
              child: Text(l10n.saveNewRevision),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmMerge(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmMergeDialogTitle),
        content: Text(l10n.confirmMergeDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<QuestionBankCubit>().mergeWithNext();
            },
            child: Text(l10n.mergeAction),
          ),
        ],
      ),
    );
  }

  void _confirmSplit(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmSplitDialogTitle),
        content: Text(l10n.confirmSplitDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<QuestionBankCubit>().splitQuestion(splitIndex: 1);
            },
            child: Text(l10n.splitAction),
          ),
        ],
      ),
    );
  }

  void _confirmMarkUnreadable(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.confirmUnreadableDialogTitle),
        content: Text(l10n.confirmUnreadableDialogBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancelAction),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<QuestionBankCubit>().markSourceUnreadable(
                reason: 'Source unreadable/truncated',
              );
            },
            child: Text(l10n.quarantineAction),
          ),
        ],
      ),
    );
  }
}
