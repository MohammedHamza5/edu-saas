import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../question_bank/domain/entities/document_entity.dart';
import '../../../question_bank/domain/entities/question_entity.dart';
import '../../../question_bank/domain/entities/question_revision_entity.dart';

/// Interactive modal sheet allowing teachers to browse Question Bank documents
/// and select questions to import directly into the Exam Builder.
class QuestionBankPickerSheet extends StatefulWidget {
  const QuestionBankPickerSheet({super.key});

  static Future<List<QuestionRevisionEntity>?> show(
    BuildContext context,
  ) {
    return showModalBottomSheet<List<QuestionRevisionEntity>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (_) => const QuestionBankPickerSheet(),
    );
  }

  @override
  State<QuestionBankPickerSheet> createState() =>
      _QuestionBankPickerSheetState();
}

class _QuestionBankPickerSheetState extends State<QuestionBankPickerSheet> {
  bool _isLoadingDocs = true;
  bool _isLoadingQuestions = false;
  bool _isImporting = false;

  List<DocumentEntity> _documents = [];
  DocumentEntity? _selectedDocument;

  List<QuestionEntity> _questions = [];
  final Map<String, QuestionRevisionEntity> _revisionsCache = {};
  final Set<String> _selectedQuestionIds = {};

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoadingDocs = true);
    try {
      final repo = InjectionContainer.questionBankRepository;
      final docs = await repo.getDocuments();
      if (mounted) {
        setState(() {
          _documents = docs.where((d) => d.isDone).toList();
          _isLoadingDocs = false;
        });
        // Auto-select if only 1 document exists
        if (_documents.length == 1) {
          unawaited(_selectDocument(_documents.first));
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingDocs = false);
    }
  }

  Future<void> _selectDocument(DocumentEntity doc) async {
    setState(() {
      _selectedDocument = doc;
      _isLoadingQuestions = true;
      _questions = [];
      _selectedQuestionIds.clear();
    });

    try {
      final repo = InjectionContainer.questionBankRepository;
      final questions = await repo.getQuestionsByDocument(doc.id);
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoadingQuestions = false;
        });
        unawaited(_preloadRevisions(questions));
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingQuestions = false);
    }
  }

  Future<void> _preloadRevisions(List<QuestionEntity> questions) async {
    final repo = InjectionContainer.questionBankRepository;
    for (final q in questions) {
      if (!_revisionsCache.containsKey(q.id)) {
        try {
          final rev = await repo.getLatestRevision(q.id);
          if (rev != null && mounted) {
            setState(() {
              _revisionsCache[q.id] = rev;
            });
          }
        } catch (_) {}
      }
    }
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedQuestionIds.length == _questions.length) {
        _selectedQuestionIds.clear();
      } else {
        _selectedQuestionIds.addAll(_questions.map((q) => q.id));
      }
    });
  }

  Future<void> _confirmImport() async {
    if (_selectedQuestionIds.isEmpty) return;
    setState(() => _isImporting = true);

    try {
      final repo = InjectionContainer.questionBankRepository;
      final List<QuestionRevisionEntity> result = [];

      for (final qId in _selectedQuestionIds) {
        QuestionRevisionEntity? rev = _revisionsCache[qId];
        rev ??= await repo.getLatestRevision(qId);
        if (rev != null) {
          result.add(rev);
        }
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusSmall,
                      ),
                    ),
                    child: const Icon(
                      Icons.functions_rounded,
                      color: Color(0xFF0EA5E9),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.importFromQuestionBankAction,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _selectedDocument != null
                            ? _selectedDocument!.displayName
                            : l10n.selectDocumentToBrowse,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s16),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.s12),

          // Main View: Documents selector or Questions list
          Expanded(
            child: _isLoadingDocs
                ? const Center(child: AppLoadingView())
                : _documents.isEmpty
                ? AppEmptyView(
                    icon: Icons.folder_open_rounded,
                    message: l10n.emptyDocumentsTitle,
                    subtitle: l10n.emptyDocumentsSubtitle,
                  )
                : _selectedDocument == null
                ? _buildDocumentsList(context)
                : _buildQuestionsView(context),
          ),

          // Bottom Action Bar (when questions are loaded)
          if (_selectedDocument != null && _questions.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                if (_documents.length > 1) ...[
                  OutlinedButton.icon(
                    onPressed: _isImporting
                        ? null
                        : () => setState(() {
                            _selectedDocument = null;
                            _selectedQuestionIds.clear();
                          }),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(l10n.backTooltip),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                ],
                Expanded(
                  child: AppButton(
                    onPressed:
                        _selectedQuestionIds.isEmpty || _isImporting
                            ? null
                            : _confirmImport,
                    isLoading: _isImporting,
                    text: l10n.importSelectedQuestionsAction(
                      _selectedQuestionIds.length,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentsList(BuildContext context) {
    return ListView.separated(
      itemCount: _documents.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
      itemBuilder: (context, index) {
        final doc = _documents[index];
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            side: const BorderSide(color: AppColors.border),
          ),
          leading: const CircleAvatar(
            backgroundColor: Color(0xFFE0F2FE),
            child: Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF0284C7)),
          ),
          title: Text(
            doc.displayName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${doc.questionCount} ${context.l10n.questionType} • ${context.l10n.pageCountBadge(doc.pageCount ?? 0)}',
          ),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
          onTap: () => _selectDocument(doc),
        );
      },
    );
  }

  Widget _buildQuestionsView(BuildContext context) {
    if (_isLoadingQuestions) {
      return const Center(child: AppLoadingView());
    }

    if (_questions.isEmpty) {
      return AppEmptyView(
        icon: Icons.inventory_2_outlined,
        message: context.l10n.noQuestionsInDocumentTitle,
        subtitle: context.l10n.noQuestionsInDocumentSubtitle,
      );
    }

    final isAllSelected = _selectedQuestionIds.length == _questions.length;

    return Column(
      children: [
        // Select All / Stats row
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.selectQuestionsToImport,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              TextButton.icon(
                onPressed: _toggleSelectAll,
                icon: Icon(
                  isAllSelected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: Text(context.l10n.selectAllQuestions),
              ),
            ],
          ),
        ),

        // Questions list
        Expanded(
          child: ListView.separated(
            itemCount: _questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
            itemBuilder: (context, index) {
              final q = _questions[index];
              final rev = _revisionsCache[q.id];
              final isSelected = _selectedQuestionIds.contains(q.id);

              return InkWell(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedQuestionIds.remove(q.id);
                    } else {
                      _selectedQuestionIds.add(q.id);
                    }
                  });
                },
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.05)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusMedium,
                    ),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: isSelected,
                        activeColor: AppColors.primary,
                        onChanged: (_) {
                          setState(() {
                            if (isSelected) {
                              _selectedQuestionIds.remove(q.id);
                            } else {
                              _selectedQuestionIds.add(q.id);
                            }
                          });
                        },
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight.withValues(
                                      alpha: 0.2,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    q.sourceLabel,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Text(
                                  q.questionType == 'multiple_choice'
                                      ? context.l10n.typeMultipleChoice
                                      : context.l10n.typeGridIn,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                if (rev?.answerKey != null) ...[
                                  const Spacer(),
                                  Text(
                                    '${context.l10n.correctAnswer}: ${rev!.answerKey}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              rev?.stemText.isNotEmpty == true
                                  ? rev!.stemText
                                  : '...',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
