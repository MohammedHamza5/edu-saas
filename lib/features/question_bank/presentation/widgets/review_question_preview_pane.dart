import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/question_bank_cubit.dart';
import '../cubit/question_bank_state.dart';
import '../dialogs/review_console_dialogs.dart';
import 'math_content_view.dart';
import 'question_display_widgets.dart';

class ReviewQuestionPreviewPane extends StatelessWidget {
  final QuestionBankReviewLoaded state;
  final String? Function(String? raw) resolveStorageUrl;

  const ReviewQuestionPreviewPane({
    super.key,
    required this.state,
    required this.resolveStorageUrl,
  });

  @override
  Widget build(BuildContext context) {
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
          _buildStemSection(context),
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
                    optAssetUrl = resolveStorageUrl(rawOpt?.toString());
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

  /// بناء قسم نص السؤال
  Widget _buildStemSection(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final rev = state.revision;

    // لا يوجد محتوى بعد
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

    // يوجد blocks (الطريقة الجديدة من AI أو الهيكل الأصلي)
    if (rev.stemBlocks.isNotEmpty) {
      final wasEnriched = rev.flags.any(
        (Object? f) => f.toString().startsWith('ai_enriched'),
      );

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  resolveUrl: resolveStorageUrl,
                  fontSize: 15,
                ),

                // زر تعديل السؤال
                const SizedBox(height: AppSpacing.s8),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () =>
                        ReviewConsoleDialogs.showStemEditDialog(context, rev),
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

    // نص stemText بسيط (الطريقة القديمة)
    final isImage = QuestionStemView.isImageUrl(rev.stemText.trim());
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: isImage
          ? QuestionStemView(
              blocks: [
                {'type': 'image', 'value': rev.stemText.trim()}
              ],
              resolveUrl: resolveStorageUrl,
              fontSize: 15,
            )
          : MathContentView(text: rev.stemText),
    );
  }
}
