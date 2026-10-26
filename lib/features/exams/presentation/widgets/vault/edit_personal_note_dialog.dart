import 'package:flutter/material.dart';
import 'package:edu_saas/core/extensions/localized_context_extension.dart';

Future<String?> showEditPersonalNoteDialog(BuildContext context, String? initialNote) {
  final noteController = TextEditingController(text: initialNote ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(context.l10n.personalNote),
      content: TextField(
        controller: noteController,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: context.l10n.addNoteHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(context.l10n.cancel)),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(noteController.text.trim()),
          child: Text(context.l10n.saveNote),
        ),
      ],
    ),
  );
}
