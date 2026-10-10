import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/whatsapp_report_generator.dart';
import '../../domain/entities/exam_parent_dispatch_entity.dart';

class ExamWhatsAppDispatchModal extends StatefulWidget {
  final ExamDispatchStudentEntity student;
  final ExamDispatchMetaEntity exam;
  final String teacherName;
  final VoidCallback onSent;
  final VoidCallback? onNext;
  final String? nextStudentName;
  final Future<bool> Function(String newPhone)? onUpdatePhone;

  const ExamWhatsAppDispatchModal({
    super.key,
    required this.student,
    required this.exam,
    this.teacherName = 'د. أنطونيوس أشرف',
    required this.onSent,
    this.onNext,
    this.nextStudentName,
    this.onUpdatePhone,
  });

  static Future<void> show({
    required BuildContext context,
    required ExamDispatchStudentEntity student,
    required ExamDispatchMetaEntity exam,
    String teacherName = 'د. أنطونيوس أشرف',
    required VoidCallback onSent,
    VoidCallback? onNext,
    String? nextStudentName,
    Future<bool> Function(String newPhone)? onUpdatePhone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      builder: (ctx) => ExamWhatsAppDispatchModal(
        student: student,
        exam: exam,
        teacherName: teacherName,
        onSent: onSent,
        onNext: onNext,
        nextStudentName: nextStudentName,
        onUpdatePhone: onUpdatePhone,
      ),
    );
  }

  @override
  State<ExamWhatsAppDispatchModal> createState() =>
      _ExamWhatsAppDispatchModalState();
}

class _ExamWhatsAppDispatchModalState
    extends State<ExamWhatsAppDispatchModal> {
  late final TextEditingController _customNoteController;
  late final TextEditingController _phoneInputController;
  late String _selectedTargetPhone;
  bool _useParentPhone = true;
  String? _selectedPreset;
  bool _isSavingPhone = false;

  @override
  void initState() {
    super.initState();
    _customNoteController = TextEditingController();
    _phoneInputController = TextEditingController(
      text: widget.student.parentPhone ?? widget.student.studentPhone ?? '',
    );

    if (widget.student.hasParentPhone) {
      _selectedTargetPhone = widget.student.parentPhone!;
      _useParentPhone = true;
    } else if (widget.student.hasStudentPhone) {
      _selectedTargetPhone = widget.student.studentPhone!;
      _useParentPhone = false;
    } else {
      _selectedTargetPhone = '';
      _useParentPhone = true;
    }

    // Set default preset based on student status
    if (!widget.student.isSubmitted) {
      _selectedPreset = 'لم يؤدِ الاختبار حتى الآن، يرجى التنبيه عليه.';
    } else {
      final pct = widget.student.bestPercentage ?? 0.0;
      if (pct >= 85) {
        _selectedPreset = 'أداء استثنائي ومستوى مشرف جداً، استمر!';
      } else if (pct >= 65) {
        _selectedPreset = 'مستوى ممتاز، اجتاز الاختبار بنجاح واقتدار.';
      } else {
        _selectedPreset = 'الدرجة أقل من المتوقع، يرجى متابعة مذاكرة الدرس.';
      }
    }
  }

  @override
  void dispose() {
    _customNoteController.dispose();
    _phoneInputController.dispose();
    super.dispose();
  }

  String _generateMessage() {
    final note = _customNoteController.text.trim().isNotEmpty
        ? _customNoteController.text.trim()
        : _selectedPreset;

    return WhatsAppReportGenerator.generateExamResultReport(
      studentName: widget.student.studentName,
      examTitle: widget.exam.title,
      score: (widget.student.bestScore ?? 0).toDouble(),
      maxScore: widget.exam.maxScore.toDouble(),
      percentage: widget.student.bestPercentage ?? 0.0,
      groupName: widget.student.groupName,
      teacherNotes: note,
      teacherName: widget.teacherName,
      isNotTaken: !widget.student.isSubmitted,
    );
  }

  List<String> get _presetNotes {
    if (!widget.student.isSubmitted) {
      return [
        'لم يؤدِ الاختبار حتى الآن، يرجى التنبيه عليه.',
        'يرجى التنبيه بضرورة أداء الاختبار لتقييم المستوى.',
        'تأخر في أداء الاختبار، يرجى المتابعة العاجلة.',
      ];
    }
    return [
      'أداء استثنائي ومستوى مشرف جداً، استمر!',
      'مستوى ممتاز، اجتاز الاختبار بنجاح واقتدار.',
      'مستوى جيد مع حاجة لمراجعة بعض المسائل الهامة.',
      'الدرجة أقل من المتوقع، يرجى متابعة مذاكرة الدرس.',
      'يرجى من ولي الأمر التواصل مع المدرس للمتابعة.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitted = widget.student.isSubmitted;
    final bestScore = widget.student.bestScore;
    final maxScore = widget.exam.maxScore;
    final pct = widget.student.bestPercentage ?? 0.0;
    final messageText = _generateMessage();
    final hasPhone = _selectedTargetPhone.trim().isNotEmpty;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // Handle bar
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.s12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s16,
                vertical: AppSpacing.s12,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      widget.student.studentName.characters.isNotEmpty
                          ? widget.student.studentName.characters.first
                          : context.l10n.studentInitialFallback,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.studentName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.exam.title} • ${widget.student.groupName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Content List
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(AppSpacing.s16),
                children: [
                  // ── 1. Result Summary Banner ──────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: isSubmitted
                          ? (widget.student.isPassed
                              ? AppColors.success.withValues(alpha: 0.08)
                              : AppColors.error.withValues(alpha: 0.08))
                          : AppColors.warning.withValues(alpha: 0.08),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(
                        color: isSubmitted
                            ? (widget.student.isPassed
                                ? AppColors.success.withValues(alpha: 0.3)
                                : AppColors.error.withValues(alpha: 0.3))
                            : AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSubmitted
                              ? (widget.student.isPassed
                                  ? Icons.verified_rounded
                                  : Icons.info_outline_rounded)
                              : Icons.schedule_rounded,
                          color: isSubmitted
                              ? (widget.student.isPassed
                                  ? AppColors.success
                                  : AppColors.error)
                              : AppColors.warning,
                          size: 24,
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSubmitted
                                    ? context.l10n.examStudentScoreLabel(
                                        '$bestScore / $maxScore (${pct.toStringAsFixed(1)}%)',
                                      )
                                    : context.l10n.examStudentNotTakenNotice,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isSubmitted
                                      ? (widget.student.isPassed
                                          ? AppColors.success
                                          : AppColors.error)
                                      : AppColors.warning,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isSubmitted
                                    ? (pct >= 85
                                        ? context.l10n.examRatingExcellent
                                        : (pct >= 65
                                            ? context.l10n.examRatingVeryGood
                                            : context.l10n.examRatingNeedsFocus))
                                    : context.l10n.examStudentNotTakenHint,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── 2. Target Phone Selector / Input ──────────────────────
                  Text(
                    context.l10n.dispatchRecipientPhoneTitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),

                  if (widget.student.hasParentPhone ||
                      widget.student.hasStudentPhone) ...[
                    Row(
                      children: [
                        if (widget.student.hasParentPhone)
                          Expanded(
                            child: _buildPhoneChoiceChip(
                              label: context.l10n.parentPhoneRecipientLabel,
                              phone: widget.student.parentPhone!,
                              isSelected: _useParentPhone,
                              onTap: () {
                                setState(() {
                                  _useParentPhone = true;
                                  _selectedTargetPhone =
                                      widget.student.parentPhone!;
                                  _phoneInputController.text =
                                      widget.student.parentPhone!;
                                });
                              },
                            ),
                          ),
                        if (widget.student.hasParentPhone &&
                            widget.student.hasStudentPhone)
                          const SizedBox(width: AppSpacing.s8),
                        if (widget.student.hasStudentPhone)
                          Expanded(
                            child: _buildPhoneChoiceChip(
                              label: context.l10n.studentPhoneRecipientLabel,
                              phone: widget.student.studentPhone!,
                              isSelected: !_useParentPhone,
                              onTap: () {
                                setState(() {
                                  _useParentPhone = false;
                                  _selectedTargetPhone =
                                      widget.student.studentPhone!;
                                  _phoneInputController.text =
                                      widget.student.studentPhone!;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s8),
                  ],

                  // Inline update / add phone field
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _phoneInputController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: context.l10n.enterParentPhoneHint,
                            prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() => _selectedTargetPhone = val.trim());
                          },
                        ),
                      ),
                      if (widget.onUpdatePhone != null) ...[
                        const SizedBox(width: AppSpacing.s8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceVariant,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: 14,
                            ),
                          ),
                          onPressed: _isSavingPhone ||
                                  _phoneInputController.text.trim().isEmpty
                              ? null
                              : () async {
                                  setState(() => _isSavingPhone = true);
                                  final newPhone =
                                      _phoneInputController.text.trim();
                                  final messenger =
                                      ScaffoldMessenger.of(context);
                                  final l10n = context.l10n;
                                  final success = await widget.onUpdatePhone!(
                                    newPhone,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _isSavingPhone = false;
                                      _selectedTargetPhone = newPhone;
                                    });
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? l10n.parentPhoneSavedSuccess
                                              : l10n.parentPhoneSaveFailed,
                                        ),
                                        backgroundColor: success
                                            ? AppColors.success
                                            : AppColors.error,
                                      ),
                                    );
                                  }
                                },
                          child: _isSavingPhone
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  context.l10n.savePhoneAction,
                                  style: const TextStyle(fontSize: 12),
                                ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── 3. Quick Feedback Presets ─────────────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        size: 16,
                        color: Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.quickTeacherPresetsTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _presetNotes.map((preset) {
                      final isSelected = _selectedPreset == preset &&
                          _customNoteController.text.trim().isEmpty;
                      return ChoiceChip(
                        label: Text(
                          preset,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withValues(alpha: 0.12),
                        backgroundColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedPreset = selected ? preset : null;
                            _customNoteController.clear();
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // ── 4. Custom Note Field ──────────────────────────────────
                  TextField(
                    controller: _customNoteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: context.l10n.customTeacherNoteHint,
                      contentPadding: const EdgeInsets.all(AppSpacing.s12),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMedium),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── 5. Live WhatsApp Preview Box ──────────────────────────
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.l10n.liveWhatsAppPreviewTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        tooltip: context.l10n.copyMessageAction,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: messageText));
                          widget.onSent();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.messageCopiedToast),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s8),

                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4), // Gentle WhatsApp tint
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      messageText,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: Color(0xFF14532D),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Action Buttons Footer ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        // Copy Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(context.l10n.copyActionShort),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: messageText));
                            widget.onSent();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.messageCopiedToast),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: AppSpacing.s8),

                        // Launch WhatsApp Button
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF22C55E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.s12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              context.l10n.sendViaWhatsAppNowAction,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            onPressed: !hasPhone
                                ? () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          context.l10n.missingPhoneWarningToast,
                                        ),
                                        backgroundColor: AppColors.warning,
                                      ),
                                    );
                                  }
                                : () async {
                                    final messenger =
                                        ScaffoldMessenger.of(context);
                                    final l10n = context.l10n;
                                    final launched =
                                        await WhatsAppReportGenerator
                                            .launchWhatsApp(
                                      phone: _selectedTargetPhone,
                                      message: messageText,
                                    );
                                    widget.onSent();
                                    if (!launched && mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            l10n.whatsAppLaunchFailedToast,
                                          ),
                                          backgroundColor: AppColors.error,
                                        ),
                                      );
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),

                    // Next student runner button (if in queue)
                    if (widget.onNext != null &&
                        widget.nextStudentName != null) ...[
                      const SizedBox(height: AppSpacing.s8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: Text(
                            context.l10n.nextStudentInQueueAction(
                              widget.nextStudentName!,
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            widget.onNext!();
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhoneChoiceChip({
    required String label,
    required String phone,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s10,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.surfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
