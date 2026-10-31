import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/whatsapp_report_generator.dart';
import '../../domain/entities/exam_parent_dispatch_entity.dart';
import 'exam_whatsapp_composer_section.dart';
import 'exam_whatsapp_modal_footer.dart';
import 'exam_whatsapp_recipient_section.dart';

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

class _ExamWhatsAppDispatchModalState extends State<ExamWhatsAppDispatchModal> {
  late final TextEditingController _customNoteController;
  late final TextEditingController _phoneInputController;
  late String _selectedTargetPhone;
  bool _useParentPhone = true;
  String? _selectedPreset;

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
    final l10n = context.l10n;
    final messageText = _generateMessage();

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
                          : l10n.studentInitialFallback,
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
                  // 1. Result Summary Banner
                  _buildResultSummaryBanner(context),
                  const SizedBox(height: AppSpacing.s16),

                  // 2. Recipient Section
                  ExamWhatsAppRecipientSection(
                    student: widget.student,
                    phoneController: _phoneInputController,
                    useParentPhone: _useParentPhone,
                    onRecipientTypeChanged: (useParent) {
                      setState(() => _useParentPhone = useParent);
                    },
                    onPhoneChanged: (phone) {
                      setState(() => _selectedTargetPhone = phone);
                    },
                    onUpdatePhone: widget.onUpdatePhone,
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // 3. Message Composer Section
                  ExamWhatsAppComposerSection(
                    presetNotes: _presetNotes,
                    selectedPreset: _selectedPreset,
                    customNoteController: _customNoteController,
                    messageText: messageText,
                    onPresetSelected: (preset) {
                      setState(() {
                        _selectedPreset = preset;
                        _customNoteController.clear();
                      });
                    },
                    onCustomNoteChanged: () => setState(() {}),
                    onCopied: widget.onSent,
                  ),
                ],
              ),
            ),

            // Footer Actions
            ExamWhatsAppModalFooter(
              messageText: messageText,
              selectedTargetPhone: _selectedTargetPhone,
              onSent: widget.onSent,
              onNext: widget.onNext,
              nextStudentName: widget.nextStudentName,
            ),
          ],
        );
      },
    );
  }

  Widget _buildResultSummaryBanner(BuildContext context) {
    final l10n = context.l10n;
    final isSubmitted = widget.student.isSubmitted;
    final bestScore = widget.student.bestScore;
    final maxScore = widget.exam.maxScore;
    final pct = widget.student.bestPercentage ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: isSubmitted
            ? (widget.student.isPassed
                ? AppColors.success.withValues(alpha: 0.08)
                : AppColors.error.withValues(alpha: 0.08))
            : AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
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
                      ? l10n.examStudentScoreLabel(
                          '$bestScore / $maxScore (${pct.toStringAsFixed(1)}%)',
                        )
                      : l10n.examStudentNotTakenNotice,
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
                          ? l10n.examRatingExcellent
                          : (pct >= 65
                              ? l10n.examRatingVeryGood
                              : l10n.examRatingNeedsFocus))
                      : l10n.examStudentNotTakenHint,
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
    );
  }
}
