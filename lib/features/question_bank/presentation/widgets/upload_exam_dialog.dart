import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/question_entity.dart';
import '../cubit/question_bank_cubit.dart';

class UploadExamDialog extends StatefulWidget {
  const UploadExamDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlocProvider.value(
        value: context.read<QuestionBankCubit>(),
        child: const UploadExamDialog(),
      ),
    );
  }

  @override
  State<UploadExamDialog> createState() => _UploadExamDialogState();
}

class _UploadExamDialogState extends State<UploadExamDialog> {
  final List<PlatformFile> _examFiles = [];
  PlatformFile? _answerKeyFile;
  bool _rightsAttested = true;
  bool _isProcessing = false;
  String? _statusMessage;
  String? _errorMessage;

  // Post-Extraction State
  bool _isDone = false;
  List<QuestionEntity> _extractedQuestions = const [];
  String _extractedFilename = '';

  // Group Assignment State
  List<Map<String, dynamic>> _groups = [];
  String? _selectedGroupId;
  final TextEditingController _examTitleController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(
    text: '60',
  );
  bool _showAssignForm = false;
  bool _isAssigning = false;
  String? _publishedExamId;

  @override
  void initState() {
    super.initState();
    _fetchGroups();
  }

  @override
  void dispose() {
    _examTitleController.dispose();
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
        });
      }
    } catch (_) {
      // Ignored: groups can still be loaded if table is empty
    }
  }

  Future<void> _pickExamFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'doc', 'tst', 'bnk'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _examFiles.addAll(result.files);
      });
    }
  }

  Future<void> _pickAnswerKeyFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt', 'csv', 'png', 'jpg'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _answerKeyFile = result.files.first;
      });
    }
  }

  Future<void> _startReconstruction() async {
    if (_examFiles.isEmpty) return;
    if (!_rightsAttested) return;

    final primaryFile = _examFiles.first;
    final fileBytes = primaryFile.bytes ?? <int>[];

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _statusMessage = context.l10n.analyzingForensicStep;
    });

    try {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      setState(() {
        _statusMessage = context.l10n.extractingFormulasStep;
      });

      // Call the real ingestion pipeline that writes to qb_documents, qb_questions, qb_question_revisions
      final questions = await context
          .read<QuestionBankCubit>()
          .ingestExamDocument(
            filename: primaryFile.name,
            bytes: fileBytes,
            answerKeyFilename: _answerKeyFile?.name,
            rightsAttestation: {
              'rights_attested': _rightsAttested,
              'attested_at': DateTime.now().toIso8601String(),
            },
          );

      if (!mounted) return;
      setState(() {
        _statusMessage = context.l10n.savingQuestionsStep;
      });

      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _isDone = true;
        _extractedQuestions = questions;
        _extractedFilename = primaryFile.name;
        final cleanBase = primaryFile.name
            .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
            .replaceAll('_', ' ');
        _examTitleController.text = 'امتحان: $cleanBase';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _publishExamToGroup() async {
    if (_selectedGroupId == null || _examTitleController.text.trim().isEmpty) {
      return;
    }

    setState(() => _isAssigning = true);
    try {
      final examId = await context
          .read<QuestionBankCubit>()
          .createExamFromQuestions(
            groupId: _selectedGroupId!,
            title: _examTitleController.text.trim(),
            durationMinutes:
                int.tryParse(_durationController.text.trim()) ?? 60,
            questions: _extractedQuestions,
          );

      if (!mounted) return;
      setState(() {
        _isAssigning = false;
        _publishedExamId = examId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAssigning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to publish exam: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _isDone
                ? _buildSuccessAndActionView(context)
                : _buildUploadFormView(context),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VIEW 1: Upload and Extraction Form
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildUploadFormView(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
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
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              child: Icon(
                Icons.auto_awesome,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.uploadExamDialogTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    l10n.uploadExamDialogSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isProcessing)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),

        // Multi-file supported banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s12),
          decoration: BoxDecoration(
            color: AppColors.info.withAlpha(30),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.info.withAlpha(60)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 18),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  l10n.multiFileAcceptedNotice,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Exam Paper (Primary)
        Text(
          l10n.primaryExamFile,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        InkWell(
          onTap: _isProcessing ? null : _pickExamFiles,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _examFiles.isNotEmpty
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: _examFiles.isNotEmpty ? 1.5 : 1.0,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              color: _examFiles.isNotEmpty
                  ? theme.colorScheme.primaryContainer.withAlpha(30)
                  : theme.colorScheme.surface,
            ),
            child: Row(
              children: [
                Icon(
                  _examFiles.isNotEmpty
                      ? Icons.picture_as_pdf
                      : Icons.cloud_upload_outlined,
                  color: _examFiles.isNotEmpty
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _examFiles.isNotEmpty
                            ? l10n.selectedFilesCount(_examFiles.length)
                            : l10n.selectFileAction,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _examFiles.isNotEmpty
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                      if (_examFiles.isNotEmpty)
                        Text(
                          _examFiles.map((f) => f.name).join(', '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _isProcessing ? null : _pickExamFiles,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l10n.selectFileAction),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Separate Answer Key (Optional)
        Text(
          l10n.answerKeyFile,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        InkWell(
          onTap: _isProcessing ? null : _pickAnswerKeyFile,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              color: _answerKeyFile != null
                  ? AppColors.successLight.withAlpha(30)
                  : theme.colorScheme.surface,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.key_outlined,
                  color: _answerKeyFile != null
                      ? AppColors.success
                      : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    _answerKeyFile?.name ?? l10n.selectFileAction,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _answerKeyFile != null ? AppColors.success : null,
                      fontWeight: _answerKeyFile != null
                          ? FontWeight.bold
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_answerKeyFile != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _answerKeyFile = null),
                  )
                else
                  TextButton(
                    onPressed: _isProcessing ? null : _pickAnswerKeyFile,
                    child: Text(l10n.selectFileAction),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // Rights Attestation Checkbox
        CheckboxListTile(
          value: _rightsAttested,
          onChanged: _isProcessing
              ? null
              : (v) => setState(() => _rightsAttested = v ?? false),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            l10n.rightsAttestationPrompt,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Error Banner
        if (_errorMessage != null && !_isProcessing) ...[
          const SizedBox(height: AppSpacing.s12),
          Container(
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _errorMessage = null),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Processing Indicator
        if (_isProcessing) ...[
          const SizedBox(height: AppSpacing.s12),
          LinearProgressIndicator(borderRadius: BorderRadius.circular(4)),
          const SizedBox(height: AppSpacing.s8),
          Text(
            _statusMessage ?? '',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s20),

        // Footer Actions
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (!_isProcessing)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
            const SizedBox(width: AppSpacing.s12),
            AppButton(
              text: l10n.startReconstructionAction,
              icon: Icons.auto_awesome,
              isLoading: _isProcessing,
              onPressed:
                  (_examFiles.isNotEmpty && _rightsAttested && !_isProcessing)
                  ? _startReconstruction
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VIEW 2: Extraction Complete & Direct Group Assignment
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSuccessAndActionView(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success Celebration Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: AppColors.successLight.withAlpha(80),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.success.withAlpha(100)),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 28,
              ),
            ),
            const SizedBox(width: AppSpacing.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.extractionSuccessTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s4),
                  Text(
                    l10n.extractionSuccessDesc(
                      _extractedQuestions.length,
                      _extractedFilename,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s16),

        // Extracted Questions Preview Chips
        Text(
          l10n.extractedQuestionsPreview,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        Container(
          height: 72,
          padding: const EdgeInsets.all(AppSpacing.s8),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant.withAlpha(50),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _extractedQuestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.s8),
            itemBuilder: (context, idx) {
              final q = _extractedQuestions[idx];
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s10,
                  vertical: AppSpacing.s6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Q${idx + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          q.questionType == 'multiple_choice'
                              ? 'MCQ'
                              : 'Grid-in',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      q.sourceLabel,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.s20),

        // ── PATH 1: Deploy as Exam to Study Group ────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: _publishedExamId != null
                ? AppColors.successLight.withAlpha(40)
                : AppColors.primary.withAlpha(15),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: _publishedExamId != null
                  ? AppColors.success.withAlpha(80)
                  : AppColors.primary.withAlpha(60),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_publishedExamId != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        l10n.examPublishedSuccess,
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton(
                      text: l10n.goToExamsPage,
                      icon: Icons.assignment_turned_in_rounded,
                      variant: AppButtonVariant.primary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/teacher/exams');
                      },
                    ),
                  ],
                ),
              ] else if (!_showAssignForm) ...[
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.rocket_launch_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.assignAsExamAction,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            l10n.assignAsExamDesc,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      text: 'تعيين لمجموعة الآن',
                      variant: AppButtonVariant.primary,
                      onPressed: () => setState(() => _showAssignForm = true),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.assignAsExamAction,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _showAssignForm = false),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s10),

                // Group Selector Dropdown
                Text(
                  l10n.selectTargetGroup,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                DropdownButtonFormField<String>(
                  value: _selectedGroupId,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    hintText: l10n.selectTargetGroupHint,
                  ),
                  items: _groups.map((g) {
                    final name = g['name']?.toString() ?? 'Group';
                    final level = g['level']?.toString() ?? '';
                    return DropdownMenuItem<String>(
                      value: g['id'] as String,
                      child: Text(
                        '$name ($level)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedGroupId = v),
                ),
                const SizedBox(height: AppSpacing.s12),

                // Exam Title & Duration
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: AppTextField(
                        controller: _examTitleController,
                        label: l10n.examTitleLabel,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      flex: 1,
                      child: AppTextField(
                        controller: _durationController,
                        label: l10n.examDurationMinutesLabel,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _showAssignForm = false),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    AppButton(
                      text: l10n.publishExamToGroupAction,
                      icon: Icons.send_rounded,
                      isLoading: _isAssigning,
                      onPressed: (_selectedGroupId != null && !_isAssigning)
                          ? _publishExamToGroup
                          : null,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s16),

        // ── PATH 2: Keep in Question Bank for Review ─────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.saveToQuestionBankOnly,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.saveToQuestionBankDesc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppButton(
                text: 'العودة لبنك الأسئلة',
                variant: AppButtonVariant.outlined,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
