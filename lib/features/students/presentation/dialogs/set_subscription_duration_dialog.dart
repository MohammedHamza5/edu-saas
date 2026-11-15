import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/student_entity.dart';
import '../cubit/students_cubit.dart';

/// Modal dialog for teachers to set, extend, or clear a student's access duration.
class SetSubscriptionDurationDialog extends StatefulWidget {
  final StudentEntity student;

  const SetSubscriptionDurationDialog({super.key, required this.student});

  static Future<bool?> show(
    BuildContext context, {
    required StudentEntity student,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SetSubscriptionDurationDialog(student: student),
    );
  }

  @override
  State<SetSubscriptionDurationDialog> createState() =>
      _SetSubscriptionDurationDialogState();
}

class _SetSubscriptionDurationDialogState
    extends State<SetSubscriptionDurationDialog> {
  DateTime? _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.student.subscriptionExpiresAt;
  }

  void _applyPresetDays(int days) {
    final base =
        (widget.student.subscriptionExpiresAt != null &&
            widget.student.subscriptionExpiresAt!.isAfter(DateTime.now()))
        ? widget.student.subscriptionExpiresAt!
        : DateTime.now();

    setState(() {
      _selectedDate = base.add(Duration(days: days));
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final initial = _selectedDate != null && _selectedDate!.isAfter(now)
        ? _selectedDate!
        : now.add(const Duration(days: 30));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      // Set to 23:59:59 of that day
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);
    final l10n = context.l10n;
    final cubit = context.read<StudentsCubit>();

    final success = await cubit.setStudentSubscription(
      studentId: widget.student.id,
      expiresAt: _selectedDate,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      AppFeedback.showSuccess(context, l10n.subscriptionUpdateSuccess);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = DateTime.now();
    final isExpired = _selectedDate != null && now.isAfter(_selectedDate!);
    final daysRemaining = _selectedDate?.difference(now).inDays;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 32,
              offset: Offset(0, 16),
              spreadRadius: -4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_filled_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.setSubscriptionDialogTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.student.fullName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              l10n.setSubscriptionDialogDesc,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.s20),

            // Current / Selected Date Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedDate == null
                      ? AppColors.border
                      : (isExpired
                            ? AppColors.error.withValues(alpha: 0.5)
                            : AppColors.success.withValues(alpha: 0.5)),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedDate == null
                        ? Icons.all_inclusive_rounded
                        : Icons.event_available_rounded,
                    color: _selectedDate == null
                        ? AppColors.primary
                        : (isExpired ? AppColors.error : AppColors.success),
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDate == null
                              ? l10n.subscriptionUnlimited
                              : (isExpired
                                    ? l10n.subscriptionExpiredOn(
                                        DateFormat.yMMMd().format(
                                          _selectedDate!,
                                        ),
                                      )
                                    : l10n.subscriptionExpiresOn(
                                        DateFormat.yMMMd().format(
                                          _selectedDate!,
                                        ),
                                        daysRemaining ?? 0,
                                      )),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _selectedDate == null
                                ? AppColors.textPrimary
                                : (isExpired
                                      ? AppColors.error
                                      : AppColors.success),
                          ),
                        ),
                        Text(
                          _selectedDate == null
                              ? l10n.subscriptionUnlimitedSubtitle
                              : DateFormat(
                                  'EEEE, d MMMM yyyy',
                                ).format(_selectedDate!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // Quick Preset Chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l10n.subscriptionPreset30Days),
                  onPressed: _isLoading ? null : () => _applyPresetDays(30),
                  backgroundColor: AppColors.surface,
                ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l10n.subscriptionPreset60Days),
                  onPressed: _isLoading ? null : () => _applyPresetDays(60),
                  backgroundColor: AppColors.surface,
                ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: Text(l10n.subscriptionPreset90Days),
                  onPressed: _isLoading ? null : () => _applyPresetDays(90),
                  backgroundColor: AppColors.surface,
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                  label: Text(l10n.subscriptionCustomDate),
                  onPressed: _isLoading ? null : _pickCustomDate,
                  backgroundColor: AppColors.surface,
                ),
                ActionChip(
                  avatar: const Icon(Icons.all_inclusive_rounded, size: 16),
                  label: Text(l10n.subscriptionClearLimit),
                  onPressed: _isLoading
                      ? null
                      : () => setState(() => _selectedDate = null),
                  backgroundColor: AppColors.surface,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(context.l10n.cancelAction),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    text: l10n.saveSubscriptionAction,
                    isLoading: _isLoading,
                    onPressed: _isLoading ? null : _submit,
                    icon: Icons.check_circle_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
