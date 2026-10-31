import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../groups/domain/entities/group_entity.dart';

class GroupCustomizationState {
  final String groupId;
  PlatformFile? customHandoutFile;
  Uint8List? customHandoutBytes;
  String? existingFileId;
  String? existingFileName;
  String? selectedExamId;
  String? selectedExamTitle;
  bool isSequentialLockEnabled;
  String? prerequisiteExamId;
  String? prerequisiteExamTitle;
  int sortOrder;
  int? passingScoreOverride;

  GroupCustomizationState({
    required this.groupId,
    this.existingFileId,
    this.existingFileName,
    this.selectedExamId,
    this.selectedExamTitle,
    this.isSequentialLockEnabled = true,
    this.prerequisiteExamId,
    this.prerequisiteExamTitle,
    this.sortOrder = 1,
    this.passingScoreOverride,
  });
}

class AssignGroupsSmartCard extends StatelessWidget {
  final GroupEntity group;
  final bool isSelected;
  final GroupCustomizationState customState;
  final List<Map<String, dynamic>> availableExams;
  final ValueChanged<bool?> onSelectionChanged;
  final VoidCallback onPickHandout;
  final void Function(String? id, String? title) onExamChanged;
  final ValueChanged<bool> onLockToggled;
  final void Function(String? id, String? title) onPrereqExamChanged;
  final ValueChanged<int> onSortOrderChanged;
  final ValueChanged<int?> onPassingScoreOverrideChanged;

  const AssignGroupsSmartCard({
    super.key,
    required this.group,
    required this.isSelected,
    required this.customState,
    required this.availableExams,
    required this.onSelectionChanged,
    required this.onPickHandout,
    required this.onExamChanged,
    required this.onLockToggled,
    required this.onPrereqExamChanged,
    required this.onSortOrderChanged,
    required this.onPassingScoreOverrideChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header checkbox row
          InkWell(
            onTap: () => onSelectionChanged(!isSelected),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: onSelectionChanged,
                    activeColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.name,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (group.level.isNotEmpty)
                          Text(
                            group.level,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      l10n.enrolledStudentsCountLabel(group.membersCount),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Contextual customization panel (shows only when group is checked)
          if (isSelected) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s12),
              color: AppColors.surfaceVariant.withValues(alpha: 0.2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Group-specific PDF Handout
                  Row(
                    children: [
                      const Icon(
                        Icons.picture_as_pdf_rounded,
                        size: 16,
                        color: Color(0xFFEA580C),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.groupHandoutPdfLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            customState.customHandoutFile != null
                                ? customState.customHandoutFile!.name
                                : customState.existingFileName != null
                                ? customState.existingFileName!
                                : l10n.uploadPdfFileTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  (customState.customHandoutFile != null ||
                                      customState.existingFileName != null)
                                  ? AppColors.textPrimary
                                  : AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onPickHandout,
                        icon: const Icon(Icons.upload_file_rounded, size: 16),
                        label: Text(
                          l10n.uploadFirstPdfAction,
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // 2. Group-specific Lesson Quiz
                  Row(
                    children: [
                      const Icon(
                        Icons.quiz_rounded,
                        size: 16,
                        color: Color(0xFF6366F1),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.groupExamLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    initialValue:
                        availableExams.any(
                          (e) => e['id'] == customState.selectedExamId,
                        )
                        ? customState.selectedExamId
                        : null,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    hint: Text(
                      l10n.noExamSelected,
                      style: const TextStyle(fontSize: 12),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          l10n.noExamSelected,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      ...availableExams.map((ex) {
                        return DropdownMenuItem<String?>(
                          value: ex['id'] as String,
                          child: Text(
                            ex['title'] as String? ?? '',
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      final selectedTitle =
                          availableExams
                                  .where((e) => e['id'] == val)
                                  .firstOrNull?['title']
                              as String?;
                      onExamChanged(val, selectedTitle);
                    },
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // 3. Sequential Lock Prerequisite
                  Row(
                    children: [
                      Switch.adaptive(
                        value: customState.isSequentialLockEnabled,
                        onChanged: onLockToggled,
                        activeThumbColor: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.lockUntilPreviousQuizPassed,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.s12),

                  // 4. Passing Score Override
                  Row(
                    children: [
                      const Icon(
                        Icons.score_rounded,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.passingScoreOverride,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue:
                              customState.passingScoreOverride?.toString() ??
                              '',
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                            hintText: l10n.passingScoreDefaultHint,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            final score = int.tryParse(val.trim());
                            onPassingScoreOverrideChanged(score);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
