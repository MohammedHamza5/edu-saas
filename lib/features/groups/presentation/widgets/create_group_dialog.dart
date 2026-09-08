import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../cubit/groups_cubit.dart';

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocProvider.value(
        value: context.read<GroupsCubit>(),
        child: const CreateGroupDialog(),
      ),
    );
  }

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _customLevelController = TextEditingController();

  static const List<String> _levels = [
    'SAT',
    'EST',
    'ACT',
    'Basics',
    'Advanced',
    'مخصص',
  ];

  String _selectedLevel = 'SAT';
  bool _allowPreviousContent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _customLevelController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final effectiveLevel = _selectedLevel == 'مخصص'
        ? _customLevelController.text.trim()
        : _selectedLevel;

    final success = await context.read<GroupsCubit>().createGroup(
          name: _nameController.text.trim(),
          level: effectiveLevel,
          description: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : null,
          previousContentAccess: _allowPreviousContent ? 'allow' : 'deny',
        );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'إضافة مجموعة دراسية جديدة',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop(false),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  AppTextField(
                    controller: _nameController,
                    labelText: 'اسم المجموعة',
                    hintText: 'مثال: SAT Math Intensive Level 1',
                    prefixIcon: const Icon(Icons.group_outlined, size: 20),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى إدخال اسم المجموعة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  const Text(
                    'مسار أو مستوى المجموعة:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Wrap(
                    spacing: AppSpacing.s8,
                    runSpacing: AppSpacing.s8,
                    children: _levels.map((level) {
                      final isSelected = _selectedLevel == level;
                      return ChoiceChip(
                        label: Text(level),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedLevel = level);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  if (_selectedLevel == 'مخصص') ...[
                    const SizedBox(height: AppSpacing.s12),
                    AppTextField(
                      controller: _customLevelController,
                      labelText: 'المسار أو التصنيف المخصص',
                      hintText: 'مثال: AP Calculus, الأولمبياد...',
                      prefixIcon: const Icon(Icons.edit_note_outlined, size: 20),
                      validator: (val) {
                        if (_selectedLevel == 'مخصص' &&
                            (val == null || val.trim().isEmpty)) {
                          return 'يرجى كتابة اسم المسار المخصص';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.s16),
                  AppTextField(
                    controller: _descController,
                    labelText: 'وصف المجموعة (اختياري)',
                    hintText: 'أهداف المجموعة ومواعيد المتابعة...',
                    maxLines: 2,
                    prefixIcon: const Icon(Icons.description_outlined, size: 20),
                  ),
                  const SizedBox(height: AppSpacing.s16),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'إتاحة المحتوى السابق للطلاب الجدد',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.s4),
                              Text(
                                _allowPreviousContent
                                    ? 'يستطيع الطالب الجديد رؤية ما نُشر قبل انضمامه'
                                    : 'يرى الطالب فقط المحتوى المنشور بعد انضمامه',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _allowPreviousContent,
                          activeColor: AppColors.primary,
                          onChanged: (val) {
                            setState(() => _allowPreviousContent = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                  AppButton(
                    text: 'إنشاء المجموعة',
                    isLoading: _isLoading,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
