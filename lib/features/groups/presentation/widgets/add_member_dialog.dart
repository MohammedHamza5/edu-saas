import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/groups_cubit.dart';

class AddMemberDialog extends StatefulWidget {
  final String groupId;

  const AddMemberDialog({super.key, required this.groupId});

  static Future<bool?> show(BuildContext context, String groupId) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: context.read<GroupsCubit>(),
        child: AddMemberDialog(groupId: groupId),
      ),
    );
  }

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await context.read<GroupsCubit>().addMember(
      groupId: widget.groupId,
      studentId: _studentIdController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.studentAddedToGroupSuccess),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusSmall,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Text(
                        context.l10n.addStudentToGroupTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s16),
                Text(
                  context.l10n.addStudentToGroupDesc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.s16),
                AppTextField(
                  controller: _studentIdController,
                  labelText: context.l10n.studentIdLabel,
                  hintText: context.l10n.studentIdHint,
                  prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.l10n.studentIdRequired;
                    }
                    if (value.trim().length < 8) {
                      return context.l10n.invalidStudentId;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.s24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(context.l10n.cancel),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    AppButton(
                      text: context.l10n.addStudentSubmit,
                      isLoading: _isLoading,
                      onPressed: _submit,
                      icon: Icons.check_rounded,
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
