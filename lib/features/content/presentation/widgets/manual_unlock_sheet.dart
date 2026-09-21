import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/course_progress_cubit.dart';

class ManualUnlockSheet extends StatefulWidget {
  final String groupId;
  final String studentId;
  final String contentId;
  final String contentTitle;
  final String studentName;
  final CourseProgressCubit cubit;

  const ManualUnlockSheet({
    super.key,
    required this.groupId,
    required this.studentId,
    required this.contentId,
    required this.contentTitle,
    required this.studentName,
    required this.cubit,
  });

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String studentId,
    required String contentId,
    required String contentTitle,
    required String studentName,
    required CourseProgressCubit cubit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualUnlockSheet(
        groupId: groupId,
        studentId: studentId,
        contentId: contentId,
        contentTitle: contentTitle,
        studentName: studentName,
        cubit: cubit,
      ),
    );
  }

  @override
  State<ManualUnlockSheet> createState() => _ManualUnlockSheetState();
}

class _ManualUnlockSheetState extends State<ManualUnlockSheet> {
  final _reasonController = TextEditingController();
  bool _isUnlocking = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    setState(() => _isUnlocking = true);
    await widget.cubit.manualUnlockLesson(
      studentId: widget.studentId,
      groupId: widget.groupId,
      contentId: widget.contentId,
      reason: _reasonController.text.trim(),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        top: AppSpacing.s24,
        left: AppSpacing.s24,
        right: AppSpacing.s24,
        bottom: bottomInset > 0 ? bottomInset + AppSpacing.s24 : AppSpacing.s48,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                ),
                child: const Icon(Icons.key_rounded, color: AppColors.warning),
              ),
              const SizedBox(width: AppSpacing.s12),
              Expanded(
                child: Text(
                  context.l10n.manualUnlockTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s24),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              children: [
                TextSpan(text: context.l10n.manualUnlockWarningText1),
                TextSpan(
                  text: ' "${widget.contentTitle}" ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(text: context.l10n.manualUnlockWarningText2),
                TextSpan(
                  text: ' "${widget.studentName}" ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(text: context.l10n.manualUnlockWarningText3),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s24),
          AppTextField(
            controller: _reasonController,
            label: context.l10n.manualUnlockReasonLabel,
            hintText: context.l10n.manualUnlockReasonHint,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.s24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s16),
            ),
            onPressed: _isUnlocking ? null : _unlock,
            child: _isUnlocking
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    context.l10n.manualUnlockConfirm,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
