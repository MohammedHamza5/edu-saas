import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../cubit/attendance_state.dart';

/// Available view modes for the Teacher Engagement Dashboard.
enum EngagementViewMode {
  byLecture,
  overall,
}

/// Header bar containing the group selector dropdown, view mode toggle,
/// and horizontal lecture selection chips.
class TeacherAttendanceHeaderBar extends StatelessWidget {
  final String? selectedGroupId;
  final ValueChanged<String?> onGroupChanged;
  final EngagementViewMode viewMode;
  final ValueChanged<EngagementViewMode> onViewModeChanged;
  final AttendanceState attendanceState;
  final ValueChanged<String?> onLectureSelected;

  const TeacherAttendanceHeaderBar({
    super.key,
    required this.selectedGroupId,
    required this.onGroupChanged,
    required this.viewMode,
    required this.onViewModeChanged,
    required this.attendanceState,
    required this.onLectureSelected,
  });

  @override
  Widget build(BuildContext context) {
    final groupSelector = BlocBuilder<GroupsCubit, GroupsState>(
      builder: (context, groupsState) {
        if (groupsState is GroupsInitial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.read<GroupsCubit>().loadGroups();
          });
        }

        if (groupsState is GroupsLoaded) {
          final groups = groupsState.groups;
          if (groups.isNotEmpty && selectedGroupId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                onGroupChanged(groups.first.id);
              }
            });
          }

          final currentValue = groups.any((g) => g.id == selectedGroupId)
              ? selectedGroupId
              : (groups.isNotEmpty ? groups.first.id : null);

          return DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: currentValue,
            decoration: InputDecoration(
              labelText: context.l10n.studyGroupLabel,
              prefixIcon: const Icon(
                Icons.groups_rounded,
                color: AppColors.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s8,
              ),
            ),
            items: groups.map((g) {
              return DropdownMenuItem<String>(
                value: g.id,
                child: Text(
                  '${g.name} (${g.level})',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
            onChanged: onGroupChanged,
          );
        }
        return SizedBox(
          height: 48,
          child: Center(
            child: Text(
              context.l10n.loadingGroups,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );

    // View Mode Toggle Segmented Pills
    final viewModeToggle = Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewModePill(
            context,
            mode: EngagementViewMode.byLecture,
            label: context.l10n.viewByLecture,
            icon: Icons.play_circle_outline_rounded,
          ),
          _buildViewModePill(
            context,
            mode: EngagementViewMode.overall,
            label: context.l10n.viewByStudentOverview,
            icon: Icons.bar_chart_rounded,
          ),
        ],
      ),
    );

    Widget? lectureSelectorSection;
    final state = attendanceState;
    if (viewMode == EngagementViewMode.byLecture &&
        state is TeacherAttendanceLoaded &&
        state.availableLectures.isNotEmpty) {
      final lectures = state.availableLectures;
      final selectedId = state.selectedLectureContentId;

      lectureSelectorSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.s12),
          Row(
            children: [
              const Icon(
                Icons.video_library_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.s6),
              Text(
                context.l10n.lectureSelectionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.apps_rounded, size: 14),
                      const SizedBox(width: 4),
                      Text(context.l10n.allLecturesOverview),
                    ],
                  ),
                  selected: selectedId == null,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: selectedId == null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: selectedId == null
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                  onSelected: (val) {
                    if (val) onLectureSelected(null);
                  },
                ),
                const SizedBox(width: AppSpacing.s8),
                ...lectures.map((lec) {
                  final isSelected = selectedId == lec.contentId;
                  final durStr = lec.formattedDuration;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.s8),
                    child: ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.play_circle_outline_rounded,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(lec.title),
                          if (durStr.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              '($durStr)',
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                      onSelected: (val) {
                        if (val) onLectureSelected(lec.contentId);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 680;

        return Container(
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isCompact) ...[
                groupSelector,
                const SizedBox(height: AppSpacing.s10),
                viewModeToggle,
              ] else ...[
                Row(
                  children: [
                    Expanded(flex: 3, child: groupSelector),
                    const SizedBox(width: AppSpacing.s16),
                    viewModeToggle,
                  ],
                ),
              ],
              if (lectureSelectorSection != null) lectureSelectorSection,
            ],
          ),
        );
      },
    );
  }

  Widget _buildViewModePill(
    BuildContext context, {
    required EngagementViewMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = viewMode == mode;
    return InkWell(
      onTap: () {
        if (viewMode != mode) {
          onViewModeChanged(mode);
        }
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s14,
          vertical: AppSpacing.s8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.s6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
