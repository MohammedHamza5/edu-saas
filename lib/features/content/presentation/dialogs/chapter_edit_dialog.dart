import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/chapter_entity.dart';
import '../cubit/content_cubit.dart';
import '../cubit/content_state.dart';

/// Modal dialog for renaming an existing chapter with duplicate name validation.
class ChapterEditDialog extends StatefulWidget {
  final ChapterEntity chapter;

  const ChapterEditDialog({
    super.key,
    required this.chapter,
  });

  /// Convenience launcher that returns `true` if the chapter was updated successfully.
  static Future<bool?> show(
    BuildContext context, {
    required ChapterEntity chapter,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChapterEditDialog(chapter: chapter),
    );
  }

  @override
  State<ChapterEditDialog> createState() => _ChapterEditDialogState();
}

class _ChapterEditDialogState extends State<ChapterEditDialog> {
  late final TextEditingController _controller;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.chapter.title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    if (text.toLowerCase() == widget.chapter.title.trim().toLowerCase()) {
      Navigator.of(context).pop(true);
      return;
    }

    final l10n = context.l10n;
    final currentState = context.read<ContentCubit>().state;
    if (currentState is ContentLoaded) {
      final isDuplicate = currentState.chapters.any(
        (c) =>
            c.id != widget.chapter.id &&
            c.title.trim().toLowerCase() == text.toLowerCase(),
      );
      if (isDuplicate) {
        setState(() {
          _errorMessage = l10n.chapterNameAlreadyExists;
        });
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await context.read<ContentCubit>().updateChapter(
          chapterId: widget.chapter.id,
          title: text,
        );

    if (mounted) {
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = l10n.chapterUpdateFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: AppColors.primary),
          const SizedBox(width: AppSpacing.s8),
          Text(l10n.editChapterTitle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chapterTitleLabel,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: AppSpacing.s8),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_isSubmitting,
            decoration: InputDecoration(
              labelText: l10n.chapterTitleLabel,
              errorText: _errorMessage,
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
            },
            onSubmitted: (_) {
              if (!_isSubmitting) unawaited(_submit());
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(false),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => unawaited(_submit()),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l10n.save),
        ),
      ],
    );
  }
}
