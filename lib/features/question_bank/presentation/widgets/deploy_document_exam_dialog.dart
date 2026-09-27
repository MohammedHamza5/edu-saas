import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/document_entity.dart';
import '../../domain/entities/question_entity.dart';
import '../cubit/question_bank_cubit.dart';

/// Modal dialog allowing the teacher to deploy questions from a processed document
/// directly as a published exam assigned to an active student group.
class DeployDocumentExamDialog extends StatefulWidget {
  final DocumentEntity document;
  final List<QuestionEntity> questions;

  const DeployDocumentExamDialog({
    super.key,
    required this.document,
    required this.questions,
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required DocumentEntity document,
    required List<QuestionEntity> questions,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<QuestionBankCubit>(),
        child: DeployDocumentExamDialog(
          document: document,
          questions: questions,
        ),
      ),
    );
  }

  @override
  State<DeployDocumentExamDialog> createState() =>
      _DeployDocumentExamDialogState();
}

class _DeployDocumentExamDialogState extends State<DeployDocumentExamDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _durationController;

  List<Map<String, dynamic>> _groups = [];
  String? _selectedGroupId;
  bool _isLoadingGroups = true;
  bool _isDeploying = false;
  bool _approvedOnly = false;
  String? _errorMessage;

  List<QuestionEntity> get _targetQuestions {
    if (_approvedOnly) {
      final filtered = widget.questions
          .where((q) => q.status == 'approved' || q.status == 'published')
          .toList();
      return filtered.isNotEmpty ? filtered : widget.questions;
    }
    return widget.questions;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.document.displayName);
    _durationController = TextEditingController(text: '60');
    _fetchGroups();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _fetchGroups() async {
    try {
      final res = await Supabase.instance.client
          .from('groups')
          .select('id, name, level')
          .eq('status', 'active')
          .order('name');
      final list = res as List<dynamic>;
      if (mounted) {
        setState(() {
          _groups = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (_groups.isNotEmpty) {
            _selectedGroupId = _groups.first['id'] as String;
          }
          _isLoadingGroups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingGroups = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _deployExam() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGroupId == null) return;
    if (_targetQuestions.isEmpty) return;

    setState(() {
      _isDeploying = true;
      _errorMessage = null;
    });

    try {
      final duration = int.tryParse(_durationController.text.trim()) ?? 60;
      final title = _titleController.text.trim();

      final examId = await context
          .read<QuestionBankCubit>()
          .createExamFromQuestions(
            groupId: _selectedGroupId!,
            title: title,
            durationMinutes: duration,
            questions: _targetQuestions,
          );

      if (mounted) {
        Navigator.of(context).pop({
          'examId': examId,
          'groupId': _selectedGroupId!,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeploying = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final count = _targetQuestions.length;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.createInstantExamTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.createInstantExamDesc,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_isDeploying)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),

                // Error alert if any
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],

                // Group selector
                if (_isLoadingGroups)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.s16),
                    child: Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (_groups.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMedium,
                      ),
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
                            l10n.noGroupsAvailable,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Text(
                    l10n.selectGroupModalTitle,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s6),
                  DropdownButtonFormField<String>(
                    value: _selectedGroupId,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                      ),
                    ),
                    items: _groups.map((g) {
                      final name = g['name'] as String? ?? 'Group';
                      final level = g['level'] as String? ?? '';
                      return DropdownMenuItem<String>(
                        value: g['id'] as String,
                        child: Text(
                          level.isNotEmpty ? '$name ($level)' : name,
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                    onChanged: _isDeploying
                        ? null
                        : (val) => setState(() => _selectedGroupId = val),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                ],

                // Exam Title
                AppTextField(
                  controller: _titleController,
                  labelText: l10n.examTitleLabel,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return l10n.fieldRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                // Duration
                AppTextField(
                  controller: _durationController,
                  labelText: l10n.durationMinutesField,
                  keyboardType: TextInputType.number,
                  prefixIcon: const Icon(Icons.timer_outlined),
                  validator: (v) {
                    final num = int.tryParse(v ?? '');
                    if (num == null || num <= 0) {
                      return l10n.positiveNumberRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s16),

                // Scope Filter Checkbox (if document has questions)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: _approvedOnly,
                  activeColor: AppColors.primary,
                  title: Text(
                    '${l10n.filterApproved} & ${l10n.filterPublished}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '$count ${l10n.questionType}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  onChanged: _isDeploying
                      ? null
                      : (val) => setState(() => _approvedOnly = val ?? false),
                ),
                const SizedBox(height: AppSpacing.s20),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!_isDeploying)
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          MaterialLocalizations.of(context).cancelButtonLabel,
                        ),
                      ),
                    const SizedBox(width: AppSpacing.s12),
                    AppButton(
                      text: l10n.createInstantExamAction,
                      icon: Icons.bolt_rounded,
                      isLoading: _isDeploying,
                      onPressed:
                          (_selectedGroupId != null &&
                              count > 0 &&
                              !_isDeploying)
                          ? _deployExam
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
