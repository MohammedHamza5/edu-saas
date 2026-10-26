import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../cubit/question_bank_state.dart';
import 'question_display_widgets.dart';

/// Left-hand evidence and provenance inspection pane for reviewers.
class ReviewEvidencePane extends StatelessWidget {
  final QuestionBankReviewLoaded state;
  final String? Function(String?) resolveStorageUrl;

  const ReviewEvidencePane({
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
          Text(
            l10n.questionDetailsAndSource,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.s12),

          // High-level human readable details
          _buildInfoTile(context, l10n.questionSourceLabel, state.question.sourceLabel),
          _buildInfoTile(
            context,
            l10n.questionTypeLabel,
            state.question.questionType == 'multiple_choice'
                ? l10n.typeMultipleChoice
                : l10n.typeGridIn,
          ),
          _buildInfoTile(
            context,
            l10n.questionStatusLabel,
            _getLocalizedStatus(context, state.question.status),
          ),
          if (rev != null) ...[
            _buildInfoTile(context, l10n.answerKeyLabel, rev.answerKey ?? 'N/A'),
            _buildInfoTile(
              context,
              l10n.answerStatusLabel,
              _getLocalizedAnswerStatus(context, rev.answerStatus),
            ),
            Builder(
              builder: (context) {
                String? rawCrop =
                    rev.provenance['crop_url']?.toString() ??
                    rev.provenance['image_url']?.toString();

                if (rawCrop == null || rawCrop.isEmpty) {
                  for (final block in rev.stemBlocks) {
                    final type = block['type']?.toString();
                    if (type == 'asset' || type == 'image') {
                      final val = block['crop_asset'] ??
                          block['path'] ??
                          block['url'] ??
                          block['value'];
                      if (val != null && val.toString().isNotEmpty) {
                        rawCrop = val.toString();
                        break;
                      }
                    } else if (QuestionStemView.isImageUrl(
                        block['value']?.toString() ?? '')) {
                      rawCrop = block['value'].toString();
                      break;
                    }
                  }
                }

                if ((rawCrop == null || rawCrop.isEmpty) &&
                    QuestionStemView.isImageUrl(rev.stemText.trim())) {
                  rawCrop = rev.stemText.trim();
                }

                final cropUrl = resolveStorageUrl(rawCrop);
                if (cropUrl == null || cropUrl.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.s16,
                    bottom: AppSpacing.s16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.originalEvidence,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMedium),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxHeight: 320),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusMedium),
                            border: Border.all(
                                color: theme.colorScheme.outlineVariant),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CachedNetworkImage(
                            imageUrl: cropUrl,
                            memCacheWidth: 800,
                            memCacheHeight: 800,
                            maxWidthDiskCache: 1200,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  const Icon(Icons.broken_image_outlined,
                                      color: AppColors.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      l10n.imageNotAccessible,
                                      style: const TextStyle(
                                          color: AppColors.error, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
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
                  _buildInfoTile(context, l10n.questionIdLabel, state.question.id),
                  _buildInfoTile(
                    context,
                    l10n.activeRevisionLabel,
                    'v${rev.revNo} (${rev.createdVia ?? 'pipeline'})',
                  ),
                  _buildInfoTile(context, l10n.contentHashLabel, rev.contentHash),
                  if (rev.sourceRefs.isNotEmpty)
                    _buildInfoTile(
                      context,
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

  Widget _buildInfoTile(BuildContext context, String title, String value) {
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

  String _getLocalizedAnswerStatus(
      BuildContext context, String? answerStatus) {
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
}
