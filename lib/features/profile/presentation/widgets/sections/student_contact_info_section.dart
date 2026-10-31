import 'package:flutter/material.dart';
import '../../../../../core/extensions/localized_context_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/app_text_field.dart';
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

    return AppCard(
      variant: AppCardVariant.standard,
      padding: const EdgeInsets.all(AppSpacing.s20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
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
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.s16),

            // 1. Full Name
            AppTextField(
              controller: _nameController,
              label: context.l10n.studentFullNameLabel,
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return context.l10n.studentNameRequired;
                }
                if (val.trim().length < 3) {
                  return context.l10n.studentNameTooShort;
                }
                return null;
              },
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    context.l10n.studentNameNotice,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),

            // 2. Student Phone
            AppTextField(
              controller: _phoneController,
              label: context.l10n.studentPhoneLabel,
              keyboardType: TextInputType.phone,
              hintText: '01xxxxxxxxx',
              prefixIcon: const Icon(
                Icons.phone_iphone_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // 3. Parent Phone
            AppTextField(
              controller: _parentPhoneController,
              label: context.l10n.studentParentPhoneLabel,
              keyboardType: TextInputType.phone,
              hintText: '01xxxxxxxxx',
              prefixIcon: const Icon(
                Icons.contact_phone_outlined,
                size: 20,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Text(
                      context.l10n.studentParentPhoneNotice,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s16),

            // 4. Email (Read-Only)
            TextFormField(
              initialValue: widget.profile.email,
              readOnly: true,
              enabled: false,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                labelText: context.l10n.studentEmailReadOnlyLabel,
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant.withValues(alpha: 0.45),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s14,
                  vertical: AppSpacing.s12,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.studentEmailReadOnlyNote,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.s24),

            // Submit Button
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppButton(
                text: context.l10n.studentSaveProfileBtn,
                icon: Icons.check_circle_outline_rounded,
                isLoading: widget.isSaving,
                onPressed: widget.isSaving ? null : _handleSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
