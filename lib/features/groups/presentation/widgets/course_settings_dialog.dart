import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/group_entity.dart';
import '../cubit/groups_cubit.dart';

class CourseSettingsDialog extends StatefulWidget {
  final GroupEntity group;

  const CourseSettingsDialog({super.key, required this.group});

  static Future<void> show(BuildContext context, GroupEntity group) {
    return showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<GroupsCubit>(),
        child: CourseSettingsDialog(group: group),
      ),
    );
  }

  @override
  State<CourseSettingsDialog> createState() => _CourseSettingsDialogState();
}

class _CourseSettingsDialogState extends State<CourseSettingsDialog> {
  late bool _enforceSequential;
  late TextEditingController _passingScoreController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _enforceSequential = widget.group.enforceSequentialLearning;
    _passingScoreController = TextEditingController(text: widget.group.defaultPassingScore.toString());
  }

  @override
  void dispose() {
    _passingScoreController.dispose();
    super.dispose();
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final passingScore = int.tryParse(_passingScoreController.text.trim()) ?? 60;
    
    final success = await context.read<GroupsCubit>().updateGroupSettings(
      groupId: widget.group.id,
      enforceSequentialLearning: _enforceSequential,
      defaultPassingScore: passingScore,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.courseSettingsTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: Text(context.l10n.enforceSequentialLearning),
              subtitle: Text(
                context.l10n.enforceSequentialLearningDesc,
                style: const TextStyle(fontSize: 12),
              ),
              value: _enforceSequential,
              onChanged: (v) => setState(() => _enforceSequential = v),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppSpacing.s16),
            TextFormField(
              controller: _passingScoreController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.l10n.defaultPassingScore,
                border: const OutlineInputBorder(),
                suffixText: '%',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.trim());
                if (n == null || n < 1 || n > 100) return 'Must be between 1 and 100';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _save,
          child: Text(context.l10n.save),
        ),
      ],
    );
  }
}
