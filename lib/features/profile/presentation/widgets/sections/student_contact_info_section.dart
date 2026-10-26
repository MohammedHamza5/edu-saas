import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../domain/entities/student_profile_entity.dart';
import '../dialogs/confirm_parent_phone_dialog.dart';

class StudentContactInfoSection extends StatefulWidget {
  final StudentProfileEntity profile;
  final bool isSaving;
  final Future<void> Function({
    required String fullName,
    String? phone,
    String? parentPhone,
  }) onSave;

  const StudentContactInfoSection({
    super.key,
    required this.profile,
    required this.isSaving,
    required this.onSave,
  });

  @override
  State<StudentContactInfoSection> createState() => _StudentContactInfoSectionState();
}

class _StudentContactInfoSectionState extends State<StudentContactInfoSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _parentPhoneController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.fullName);
    _phoneController = TextEditingController(text: widget.profile.phone ?? '');
    _parentPhoneController = TextEditingController(text: widget.profile.parentPhone ?? '');
  }

  @override
  void didUpdateWidget(covariant StudentContactInfoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile) {
      if (_nameController.text != widget.profile.fullName) {
        _nameController.text = widget.profile.fullName;
      }
      if (_phoneController.text != (widget.profile.phone ?? '')) {
        _phoneController.text = widget.profile.phone ?? '';
      }
      if (_parentPhoneController.text != (widget.profile.parentPhone ?? '')) {
        _parentPhoneController.text = widget.profile.parentPhone ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final trimmedParentPhone = _parentPhoneController.text.trim();
    final originalParentPhone = (widget.profile.parentPhone ?? '').trim();

    // If parent phone was changed, require explicit confirmation modal
    if (trimmedParentPhone.isNotEmpty && trimmedParentPhone != originalParentPhone) {
      final confirmed = await ConfirmParentPhoneDialog.show(
        context,
        newParentPhone: trimmedParentPhone,
      );
      if (!confirmed) return;
    }

    if (!mounted) return;

    await widget.onSave(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      parentPhone: trimmedParentPhone.isEmpty ? null : trimmedParentPhone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.s20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.person_pin_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.s8),
                Text(
                  context.l10n.studentContactDetailsTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),

            // 1. Full Name
            Text(
              context.l10n.studentFullNameLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s12,
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return context.l10n.validationRequiredField;
                }
                if (val.trim().length < 3) {
                  return context.l10n.validationMinLength(3);
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.s6),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    context.l10n.studentNameNotice,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),

            // 2. Student Phone
            Text(
              context.l10n.studentPhoneLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_rounded, size: 20),
                hintText: '01xxxxxxxxx',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s12,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // 3. Parent Phone
            Text(
              context.l10n.studentParentPhoneLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            TextFormField(
              controller: _parentPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.contact_phone_rounded, size: 20),
                hintText: '01xxxxxxxxx',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s12,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      context.l10n.studentParentPhoneNotice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // 4. Email (Read-Only)
            Text(
              context.l10n.studentEmailReadOnlyLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.s6),
            TextFormField(
              initialValue: widget.profile.email,
              readOnly: true,
              enabled: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s12,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            Text(
              context.l10n.studentEmailReadOnlyNote,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.s20),

            // Submit Button
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s24,
                    vertical: AppSpacing.s12,
                  ),
                ),
                onPressed: widget.isSaving ? null : _handleSave,
                icon: widget.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  context.l10n.studentSaveProfileBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
