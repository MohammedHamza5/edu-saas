import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/whatsapp_report_generator.dart';
import '../../domain/entities/student_academic_report_entity.dart';
import '../cubit/students_cubit.dart';
import '../widgets/academic_report_decision_chips.dart';
import '../widgets/academic_report_period_selector.dart';
import '../widgets/academic_report_stats_bar.dart';

/// Dialog for verified, period-aware, and customizable student academic progress reports
class AcademicReportDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String? parentPhone;
  final String? studentPhone;
  final String? initialGroupName;
  final String? teacherName;

  static void show(
    BuildContext context, {
    required String studentId,
    required String studentName,
    String? parentPhone,
    String? studentPhone,
    String? initialGroupName,
    String? teacherName = 'د. أنطونيوس أشرف',
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AcademicReportDialog(
        studentId: studentId,
        studentName: studentName,
        parentPhone: parentPhone,
        studentPhone: studentPhone,
        initialGroupName: initialGroupName,
        teacherName: teacherName,
      ),
    );
  }

  const AcademicReportDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    this.parentPhone,
    this.studentPhone,
    this.initialGroupName,
    this.teacherName = 'د. أنطونيوس أشرف',
  });

  @override
  State<AcademicReportDialog> createState() => _AcademicReportDialogState();
}

class _AcademicReportDialogState extends State<AcademicReportDialog> {
  late final TextEditingController _textController;
  int? _selectedPeriodDays = 14; // Default to last 14 days (2 weeks)
  bool _isLoading = true;
  StudentAcademicReportEntity? _reportData;
  late String _selectedPhone;
  String _selectedDecision = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _selectedPhone =
        (widget.parentPhone != null && widget.parentPhone!.trim().isNotEmpty)
            ? widget.parentPhone!.trim()
            : (widget.studentPhone?.trim() ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _selectedDecision = context.l10n.whatsappDecisionConsistent;
        _fetchReport(_selectedPeriodDays);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _fetchReport(int? days) async {
    setState(() {
      _selectedPeriodDays = days;
      _isLoading = true;
    });

    StudentAcademicReportEntity? data;
    try {
      data = await context.read<StudentsCubit>().loadStudentAcademicReport(
        widget.studentId,
        days: days,
      );
    } catch (_) {
      try {
        final res = await InjectionContainer.studentsRepository.getStudentAcademicReport(
          widget.studentId,
          days: days,
        );
        data = res.dataOrNull;
      } catch (_) {}
    }

    if (!mounted) return;

    data ??= StudentAcademicReportEntity(
      studentId: widget.studentId,
      studentName: widget.studentName,
      parentPhone: widget.parentPhone,
      studentPhone: widget.studentPhone,
      groupNames: widget.initialGroupName,
      periodDays: days,
    );

    setState(() {
      _reportData = data;
      _isLoading = false;
      _updateReportText();
    });
  }

  String _getPeriodLabel(int? days) {
    final l10n = context.l10n;
    return switch (days) {
      7 => l10n.whatsappPeriod7Days,
      14 => l10n.whatsappPeriod14Days,
      30 => l10n.whatsappPeriod30Days,
      _ => l10n.whatsappPeriodAllTime,
    };
  }

  void _updateReportText() {
    if (_reportData == null) return;
    final text = WhatsAppReportGenerator.generateFactualAcademicReport(
      report: _reportData!,
      periodLabel: _getPeriodLabel(_selectedPeriodDays),
      academicDecision: _selectedDecision,
      teacherName: widget.teacherName,
    );
    _textController.text = text;
  }

  void _applyDecision(String decision) {
    setState(() {
      _selectedDecision = decision;
      _updateReportText();
    });
  }

  Future<void> _handleSendWhatsApp() async {
    final l10n = context.l10n;
    if (_selectedPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.whatsappParentPhoneMissing),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSending = true);
    final text = _textController.text.trim();
    final launched = await WhatsAppReportGenerator.launchWhatsApp(
      phone: _selectedPhone,
      message: text,
    );
    if (!mounted) return;
    setState(() => _isSending = false);

    if (launched) {
      Navigator.of(context).pop();
    } else {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted || !context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.whatsappOpenError),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleCopy() {
    final text = _textController.text.trim();
    Clipboard.setData(ClipboardData(text: text));
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.whatsappCopiedSuccess(widget.studentName)),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasParentPhone =
        widget.parentPhone != null && widget.parentPhone!.trim().isNotEmpty;
    final hasStudentPhone =
        widget.studentPhone != null && widget.studentPhone!.trim().isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s20,
        AppSpacing.s20,
        AppSpacing.s8,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s8,
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.s8),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_chat_read_rounded,
              color: Color(0xFF25D366),
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.whatsappReportHeaderTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${widget.studentName}${widget.initialGroupName != null ? ' | ${widget.initialGroupName}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Period Selector Chips
              AcademicReportPeriodSelector(
                selectedPeriodDays: _selectedPeriodDays,
                onPeriodSelected: _fetchReport,
              ),
              const SizedBox(height: AppSpacing.s12),

              // 2. Real Telemetry Quick Stats Badge Bar
              AcademicReportStatsBar(
                isLoading: _isLoading,
                reportData: _reportData,
              ),
              const SizedBox(height: AppSpacing.s12),

              // 3. Target Phone Selector
              if (hasParentPhone && hasStudentPhone) ...[
                Text(
                  l10n.whatsappTargetPhoneLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.s6),
                Row(
                  children: [
                    ChoiceChip(
                      label: Text(
                        '${l10n.whatsappTargetParent} (${widget.parentPhone})',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _selectedPhone == widget.parentPhone!.trim(),
                      onSelected: (selected) {
                        if (selected) {
                          setState(
                            () => _selectedPhone = widget.parentPhone!.trim(),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    ChoiceChip(
                      label: Text(
                        '${l10n.whatsappTargetStudent} (${widget.studentPhone})',
                        style: const TextStyle(fontSize: 11),
                      ),
                      selected: _selectedPhone == widget.studentPhone!.trim(),
                      onSelected: (selected) {
                        if (selected) {
                          setState(
                            () => _selectedPhone = widget.studentPhone!.trim(),
                          );
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
              ] else if (_selectedPhone.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.phone_iphone_rounded,
                      size: 14,
                      color: Color(0xFF25D366),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${l10n.whatsappTargetPhoneLabel}: $_selectedPhone',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.warning,
                        size: 16,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          l10n.whatsappParentPhoneMissing,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
              ],

              // 4. Academic Directives / Quick Decision Chips
              AcademicReportDecisionChips(
                onDecisionSelected: _applyDecision,
              ),
              const SizedBox(height: AppSpacing.s12),

              // 5. Editable Message Area
              TextField(
                controller: _textController,
                maxLines: 10,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.textPrimary,
                  fontFamily: 'Cairo',
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.all(AppSpacing.s12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.s20,
        AppSpacing.s8,
        AppSpacing.s20,
        AppSpacing.s16,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: Text(l10n.whatsappCopyButton),
          onPressed: _handleCopy,
        ),
        ElevatedButton.icon(
          icon: _isSending
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.send_rounded, size: 16),
          label: Text(l10n.whatsappSendButton),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
          onPressed: _isSending ? null : _handleSendWhatsApp,
        ),
      ],
    );
  }
}
