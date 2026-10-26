import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/chapter_entity.dart';
import '../cubit/content_cubit.dart';

/// Modal dialog for quickly creating a new chapter within the Lesson Studio.
class QuickCreateChapterDialog extends StatefulWidget {
  final String groupId;

  const QuickCreateChapterDialog({
    super.key,
    required this.groupId,
  });

  /// Convenience launcher that returns the newly created [ChapterEntity], or null if canceled.
  static Future<ChapterEntity?> show(
    BuildContext context, {
    required String groupId,
  }) {
    return showDialog<ChapterEntity>(
      context: context,
      builder: (_) => QuickCreateChapterDialog(groupId: groupId),
    );
  }

  @override
  State<QuickCreateChapterDialog> createState() =>
      _QuickCreateChapterDialogState();
}

class _QuickCreateChapterDialogState extends State<QuickCreateChapterDialog> {
  late final TextEditingController _titleController;
  bool _isPublished = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSubmitting = true);
    final chapter = await context.read<ContentCubit>().createChapter(
          groupId: widget.groupId,
          title: title,
          isPublished: _isPublished,
        );

    if (mounted) {
      Navigator.of(context).pop(chapter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.create_new_folder_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Text(l10n.newChapterDialogTitle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _titleController,
            labelText: l10n.chapterTitleLabel,
            hintText: l10n.chapterTitleHint,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.s16),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Icon(
                  _isPublished
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  color: _isPublished ? AppColors.success : AppColors.warning,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.s10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.lecturePublishStatus,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _isPublished
                            ? l10n.chapterVisibilityPublished
                            : l10n.chapterVisibilityDraft,
                        style: TextStyle(
                          fontSize: 11,
                          color: _isPublished
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isPublished,
                  activeColor: AppColors.success,
                  onChanged: (val) => setState(() => _isPublished = val),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        AppButton(
          text: l10n.save,
          isLoading: _isSubmitting,
          onPressed: _handleSave,
        ),
      ],
    );
  }
}
