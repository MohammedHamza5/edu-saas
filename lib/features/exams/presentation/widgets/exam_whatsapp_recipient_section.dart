import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/exam_parent_dispatch_entity.dart';

class ExamWhatsAppRecipientSection extends StatefulWidget {
  final ExamDispatchStudentEntity student;
  final TextEditingController phoneController;
  final bool useParentPhone;
  final ValueChanged<bool> onRecipientTypeChanged;
  final ValueChanged<String> onPhoneChanged;
  final Future<bool> Function(String newPhone)? onUpdatePhone;

  const ExamWhatsAppRecipientSection({
    super.key,
    required this.student,
    required this.phoneController,
    required this.useParentPhone,
    required this.onRecipientTypeChanged,
    required this.onPhoneChanged,
    this.onUpdatePhone,
  });

  @override
  State<ExamWhatsAppRecipientSection> createState() =>
      _ExamWhatsAppRecipientSectionState();
}

class _ExamWhatsAppRecipientSectionState
    extends State<ExamWhatsAppRecipientSection> {
  bool _isSavingPhone = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dispatchRecipientPhoneTitle,
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
                    label: l10n.parentPhoneRecipientLabel,
                    phone: widget.student.parentPhone!,
                    isSelected: widget.useParentPhone,
                    onTap: () {
                      widget.onRecipientTypeChanged(true);
                      widget.phoneController.text =
                          widget.student.parentPhone!;
                      widget.onPhoneChanged(widget.student.parentPhone!);
                    },
                  ),
                ),
              if (widget.student.hasParentPhone &&
                  widget.student.hasStudentPhone)
                const SizedBox(width: AppSpacing.s8),
              if (widget.student.hasStudentPhone)
                Expanded(
                  child: _buildPhoneChoiceChip(
                    label: l10n.studentPhoneRecipientLabel,
                    phone: widget.student.studentPhone!,
                    isSelected: !widget.useParentPhone,
                    onTap: () {
                      widget.onRecipientTypeChanged(false);
                      widget.phoneController.text =
                          widget.student.studentPhone!;
                      widget.onPhoneChanged(widget.student.studentPhone!);
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
                controller: widget.phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: l10n.enterParentPhoneHint,
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
                  widget.onPhoneChanged(val.trim());
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
                        widget.phoneController.text.trim().isEmpty
                    ? null
                    : () async {
                        setState(() => _isSavingPhone = true);
                        final newPhone = widget.phoneController.text.trim();
                        final messenger = ScaffoldMessenger.of(context);
                        final success = await widget.onUpdatePhone!(newPhone);

                        if (!mounted) return;
                        setState(() => _isSavingPhone = false);
                        widget.onPhoneChanged(newPhone);

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
                      },
                child: _isSavingPhone
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        l10n.savePhoneAction,
                        style: const TextStyle(fontSize: 12),
                      ),
              ),
            ],
          ],
        ),
      ],
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
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
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
