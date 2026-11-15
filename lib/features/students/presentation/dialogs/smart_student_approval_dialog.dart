import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/student_entity.dart';

/// Carries both the target groups and subscription expiration chosen by the teacher.
class StudentApprovalResult {
  final Set<String> groupIds;
  final DateTime? subscriptionExpiresAt;

  const StudentApprovalResult({
    required this.groupIds,
    this.subscriptionExpiresAt,
  });
}

/// Dialog that presents groups list and subscription duration for approving a pending student.
class SmartStudentApprovalDialog extends StatefulWidget {
  final StudentEntity student;

  const SmartStudentApprovalDialog({super.key, required this.student});

  /// Displays the approval dialog and returns the configuration, or null if cancelled.
  static Future<StudentApprovalResult?> show(
    BuildContext context,
    StudentEntity student,
  ) {
    return showDialog<StudentApprovalResult>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SmartStudentApprovalDialog(student: student),
    );
  }

  @override
  State<SmartStudentApprovalDialog> createState() =>
      _SmartStudentApprovalDialogState();
}

class _SmartStudentApprovalDialogState
    extends State<SmartStudentApprovalDialog> {
  final Set<String> _selectedGroupIds = <String>{};
  DateTime? _selectedSubscriptionDate;
  int? _selectedPresetDays;

  @override
  void initState() {
    super.initState();
    // Default preset 40 days as specified in teacher workflow
    _applyPresetDays(40);
  }

  void _applyPresetDays(int days) {
    final now = DateTime.now();
    final target = now.add(Duration(days: days));
    setState(() {
      _selectedPresetDays = days;
      _selectedSubscriptionDate = DateTime(
        target.year,
        target.month,
        target.day,
        23,
        59,
        59,
      );
    });
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final initial = _selectedSubscriptionDate != null &&
            _selectedSubscriptionDate!.isAfter(now)
        ? _selectedSubscriptionDate!
        : now.add(const Duration(days: 40));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 3)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedPresetDays = null;
        _selectedSubscriptionDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          23,
          59,
          59,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final groupsState = context.watch<GroupsCubit>().state;
    final List<GroupEntity> groups = groupsState is GroupsLoaded
        ? groupsState.groups
        : <GroupEntity>[];

    final now = DateTime.now();
    final daysRemaining = _selectedSubscriptionDate?.difference(now).inDays;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 32,
              offset: Offset(0, 16),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Color(0x2610B981),
              blurRadius: 24,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.how_to_reg_rounded,
                      color: Color(0xFF22C55E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.smartApproveTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.student.fullName} • ${widget.student.email}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, null),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textMuted,
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.s16),

              // 2. Subscription Validity Duration Section
              Container(
                padding: const EdgeInsets.all(AppSpacing.s14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        Text(
                          l10n.approvalSubscriptionSectionTitle,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.approvalSubscriptionSectionSubtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Preset Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildPresetChip(
                          label: l10n.subscriptionPreset30Days,
                          days: 30,
                        ),
                        _buildPresetChip(
                          label: l10n.subscriptionPreset40Days,
                          days: 40,
                          isHighlight: true,
                        ),
                        _buildPresetChip(
                          label: l10n.subscriptionPreset60Days,
                          days: 60,
                        ),
                        _buildPresetChip(
                          label: l10n.subscriptionPreset90Days,
                          days: 90,
                        ),
                        ActionChip(
                          avatar: const Icon(Icons.event_rounded, size: 14),
                          label: Text(
                            l10n.subscriptionCustomDate,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: _pickCustomDate,
                          backgroundColor: _selectedPresetDays == null &&
                                  _selectedSubscriptionDate != null
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.surface,
                        ),
                        ActionChip(
                          avatar:
                              const Icon(Icons.all_inclusive_rounded, size: 14),
                          label: Text(
                            l10n.subscriptionClearLimit,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          onPressed: () => setState(() {
                            _selectedPresetDays = null;
                            _selectedSubscriptionDate = null;
                          }),
                          backgroundColor: _selectedSubscriptionDate == null
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.surface,
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.s10),

                    // Preview Status Box
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s12,
                        vertical: AppSpacing.s8,
                      ),
                      decoration: BoxDecoration(
                        color: _selectedSubscriptionDate == null
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedSubscriptionDate == null
                              ? AppColors.primary.withValues(alpha: 0.25)
                              : AppColors.success.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedSubscriptionDate == null
                                ? Icons.all_inclusive_rounded
                                : Icons.verified_rounded,
                            size: 16,
                            color: _selectedSubscriptionDate == null
                                ? AppColors.primary
                                : AppColors.success,
                          ),
                          const SizedBox(width: AppSpacing.s8),
                          Expanded(
                            child: Text(
                              _selectedSubscriptionDate == null
                                  ? l10n.subscriptionUnlimited
                                  : l10n.subscriptionExpiresOn(
                                      DateFormat.yMMMd().format(
                                        _selectedSubscriptionDate!,
                                      ),
                                      daysRemaining ?? 0,
                                    ),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedSubscriptionDate == null
                                    ? AppColors.primary
                                    : AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s16),

              // 3. Select Groups Instruction
              Text(
                l10n.smartApproveSelectGroupPrompt,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s8),

              // 4. Groups List
              if (groupsState is GroupsLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (groups.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          l10n.smartApproveNoGroupsWarning,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: Scrollbar(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (listCtx, index) {
                        final g = groups[index];
                        final isSelected = _selectedGroupIds.contains(g.id);

                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedGroupIds.remove(g.id);
                              } else {
                                _selectedGroupIds.add(g.id);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.s12,
                              vertical: AppSpacing.s8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.08)
                                  : AppColors.surfaceVariant.withValues(
                                      alpha: 0.4,
                                    ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedGroupIds.add(g.id);
                                      } else {
                                        _selectedGroupIds.remove(g.id);
                                      }
                                    });
                                  },
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      if (g.level.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          g.level,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    g.level,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

              const SizedBox(height: AppSpacing.s12),

              // Notice
              Container(
                padding: const EdgeInsets.all(AppSpacing.s8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 15,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        l10n.smartApproveEnrollNotice,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF0369A1),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s16),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      text: l10n.cancel,
                      variant: AppButtonVariant.outlined,
                      onPressed: () => Navigator.pop(context, null),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 48),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSmall,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          StudentApprovalResult(
                            groupIds: _selectedGroupIds,
                            subscriptionExpiresAt: _selectedSubscriptionDate,
                          ),
                        );
                      },
                      child: Text(
                        l10n.smartApproveAndEnrollAction,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    required int days,
    bool isHighlight = false,
  }) {
    final isSelected = _selectedPresetDays == days;

    return ActionChip(
      avatar: Icon(
        isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline,
        size: 14,
        color: isSelected ? Colors.white : AppColors.primary,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      backgroundColor: isSelected
          ? (isHighlight ? const Color(0xFF10B981) : AppColors.primary)
          : AppColors.surface,
      side: BorderSide(
        color: isSelected
            ? Colors.transparent
            : (isHighlight
                ? const Color(0xFF10B981).withValues(alpha: 0.5)
                : AppColors.border),
      ),
      onPressed: () => _applyPresetDays(days),
    );
  }
}
