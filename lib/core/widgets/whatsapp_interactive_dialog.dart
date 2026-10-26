import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../extensions/localized_context_extension.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/whatsapp_report_generator.dart';

class WhatsAppInteractiveDialog extends StatefulWidget {
  final String studentName;
  final String initialReportText;
  final String? phone;
  final String? alternatePhone;
  final String? groupName;
  final double videoWatchRate;
  final int completedAssignments;
  final int totalAssignments;
  final int mockExamScore;
  final int targetScore;
  final int? activeStudyMinutes;
  final String? teacherName;

  static void show(
    BuildContext context, {
    required String studentName,
    required String reportText,
    String? phone,
    String? alternatePhone,
    String? groupName,
    double videoWatchRate = 0.0,
    int completedAssignments = 0,
    int totalAssignments = 0,
    int mockExamScore = 0,
    int targetScore = 100,
    int? activeStudyMinutes,
    String? teacherName = 'د. أنطونيوس أشرف',
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => WhatsAppInteractiveDialog(
        studentName: studentName,
        initialReportText: reportText,
        phone: phone,
        alternatePhone: alternatePhone,
        groupName: groupName,
        videoWatchRate: videoWatchRate,
        completedAssignments: completedAssignments,
        totalAssignments: totalAssignments,
        mockExamScore: mockExamScore,
        targetScore: targetScore,
        activeStudyMinutes: activeStudyMinutes,
        teacherName: teacherName,
      ),
    );
  }

  const WhatsAppInteractiveDialog({
    super.key,
    required this.studentName,
    required this.initialReportText,
    this.phone,
    this.alternatePhone,
    this.groupName,
    this.videoWatchRate = 0.0,
    this.completedAssignments = 0,
    this.totalAssignments = 0,
    this.mockExamScore = 0,
    this.targetScore = 100,
    this.activeStudyMinutes,
    this.teacherName,
  });

  @override
  State<WhatsAppInteractiveDialog> createState() =>
      _WhatsAppInteractiveDialogState();
}

class _WhatsAppInteractiveDialogState
    extends State<WhatsAppInteractiveDialog> {
  late final TextEditingController _textController;
  late String _selectedPhone;
  bool _isMonthly = false;
  String _currentCustomNote = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.initialReportText.trim().isNotEmpty
          ? widget.initialReportText
          : _generateActiveReport(),
    );
    _selectedPhone = (widget.phone != null && widget.phone!.trim().isNotEmpty)
        ? widget.phone!.trim()
        : (widget.alternatePhone?.trim() ?? '');
  }

  String _generateActiveReport() {
    if (_isMonthly) {
      return WhatsAppReportGenerator.generateNaturalMonthlyReport(
        studentName: widget.studentName,
        groupName: widget.groupName,
        videoWatchRate: widget.videoWatchRate,
        completedAssignments: widget.completedAssignments,
        totalAssignments: widget.totalAssignments,
        mockExamScore: widget.mockExamScore,
        targetScore: widget.targetScore,
        activeStudyMinutes: widget.activeStudyMinutes,
        teacherNotes: _currentCustomNote,
        teacherName: widget.teacherName,
      );
    }
    return WhatsAppReportGenerator.generateNaturalWeeklyReport(
      studentName: widget.studentName,
      groupName: widget.groupName,
      videoWatchRate: widget.videoWatchRate,
      completedAssignments: widget.completedAssignments,
      totalAssignments: widget.totalAssignments,
      mockExamScore: widget.mockExamScore,
      targetScore: widget.targetScore,
      activeStudyMinutes: widget.activeStudyMinutes,
      teacherNotes: _currentCustomNote,
      teacherName: widget.teacherName,
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _switchPeriod(bool isMonthly) {
    if (_isMonthly == isMonthly) return;
    setState(() {
      _isMonthly = isMonthly;
      _textController.text = _generateActiveReport();
    });
  }

  void _applyPresetNote(String preset) {
    setState(() {
      _currentCustomNote = preset;
      _textController.text = _generateActiveReport();
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
      // Fallback copy to clipboard if launch fails
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
        widget.phone != null && widget.phone!.trim().isNotEmpty;
    final hasAltPhone = widget.alternatePhone != null &&
        widget.alternatePhone!.trim().isNotEmpty;

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
                  l10n.whatsappReportDialogTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  widget.studentName,
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
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Period Toggle: Weekly vs Monthly
              Row(
                children: [
                  ChoiceChip(
                    avatar: Icon(
                      Icons.bolt_rounded,
                      size: 16,
                      color: !_isMonthly ? Colors.white : AppColors.primary,
                    ),
                    label: Text(l10n.whatsappPeriodWeekly),
                    selected: !_isMonthly,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: !_isMonthly ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) _switchPeriod(false);
                    },
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  ChoiceChip(
                    avatar: Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: _isMonthly ? Colors.white : AppColors.primary,
                    ),
                    label: Text(l10n.whatsappPeriodMonthly),
                    selected: _isMonthly,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _isMonthly ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) _switchPeriod(true);
                    },
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // Target Phone Selector if both exist
              if (hasParentPhone && hasAltPhone) ...[
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
                        '${l10n.whatsappTargetParent} (${widget.phone})',
                      ),
                      selected: _selectedPhone == widget.phone!.trim(),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPhone = widget.phone!.trim());
                        }
                      },
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    ChoiceChip(
                      label: Text(
                        '${l10n.whatsappTargetStudent} (${widget.alternatePhone})',
                      ),
                      selected: _selectedPhone == widget.alternatePhone!.trim(),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedPhone =
                              widget.alternatePhone!.trim());
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
                        fontSize: 12,
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

              // Quick Friendly Presets
              Text(
                l10n.whatsappTeacherNotesLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              Wrap(
                spacing: AppSpacing.s6,
                runSpacing: AppSpacing.s6,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.star_rounded,
                        size: 14, color: Color(0xFFF59E0B)),
                    label: Text(l10n.whatsappPresetFriendlyKeepUp,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () =>
                        _applyPresetNote(l10n.whatsappPresetFriendlyKeepUp),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.fitness_center_rounded,
                        size: 14, color: AppColors.primary),
                    label: Text(l10n.whatsappPresetFriendlyNeedsFocus,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () =>
                        _applyPresetNote(l10n.whatsappPresetFriendlyNeedsFocus),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.play_circle_outline_rounded,
                        size: 14, color: AppColors.info),
                    label: Text(l10n.whatsappPresetFriendlyCatchUp,
                        style: const TextStyle(fontSize: 11)),
                    onPressed: () =>
                        _applyPresetNote(l10n.whatsappPresetFriendlyCatchUp),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s12),

              // Editable Message Area
              TextField(
                controller: _textController,
                maxLines: 10,
                style: const TextStyle(
                  fontSize: 13,
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
