import 'package:flutter/material.dart';

import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../dialogs/teacher_attendance_dialogs.dart';
import 'attendance_stat_card.dart';
import 'student_attendance_row_card.dart';

/// Overall Student Progress & Engagement View for Teachers.
class TeacherAttendanceOverallView extends StatefulWidget {
  final TeacherAttendanceLoaded loadedState;
  final String? selectedGroupId;
  final AttendanceCubit attendanceCubit;

  const TeacherAttendanceOverallView({
    super.key,
    required this.loadedState,
    required this.selectedGroupId,
    required this.attendanceCubit,
  });

  @override
  State<TeacherAttendanceOverallView> createState() =>
      _TeacherAttendanceOverallViewState();
}

class _TeacherAttendanceOverallViewState
    extends State<TeacherAttendanceOverallView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _overallFilter; // 'all', 'committed', 'moderate', 'needs_followup'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.loadedState.students;

    // Overall Computed Metrics across all published lectures in the group
    int committedCount = 0;
    int moderateCount = 0;
    int needsFollowupCount = 0;
    double totalProgressSum = 0.0;

    for (final s in students) {
      final total = s.totalLecturesCount > 0 ? s.totalLecturesCount : 1;
      final ratio = s.completedLecturesCount / total;
      totalProgressSum += ratio;

      if (ratio >= 0.75) {
        committedCount++;
      } else if (ratio >= 0.35) {
        moderateCount++;
      } else {
        needsFollowupCount++;
      }
    }

    final avgCommitmentRate = students.isNotEmpty
        ? (totalProgressSum / students.length) * 100.0
        : 0.0;

    // Filter students
    final displayedStudents = students.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = s.studentName.toLowerCase().contains(q);
        final matchPhone = s.phone?.contains(q) ?? false;
        if (!matchName && !matchPhone) return false;
      }
      if (_overallFilter != null) {
        final total = s.totalLecturesCount > 0 ? s.totalLecturesCount : 1;
        final ratio = s.completedLecturesCount / total;
        if (_overallFilter == 'committed' && ratio < 0.75) return false;
        if (_overallFilter == 'moderate' && (ratio < 0.35 || ratio >= 0.75)) {
          return false;
        }
        if (_overallFilter == 'needs_followup' && ratio >= 0.35) {
          return false;
        }
      }
      return true;
    }).toList();

    return Column(
      children: [
        // 4 Responsive Analytics Cards
        Padding(
          padding: const EdgeInsets.all(AppSpacing.s16),
          child: ResponsiveGrid(
            mobileColumns: 2,
            tabletColumns: 4,
            desktopColumns: 4,
            spacing: AppSpacing.s8,
            runSpacing: AppSpacing.s8,
            children: [
              AttendanceStatCard(
                title: context.l10n.totalEnrolledStudents,
                value: '${students.length}',
                subtitle: widget.loadedState.availableLectures.isNotEmpty
                    ? '${widget.loadedState.availableLectures.length} محاضرات'
                    : context.l10n.allLecturesOverview,
                color: AppColors.primary,
                icon: Icons.groups_rounded,
              ),
              AttendanceStatCard(
                title: context.l10n.groupCommitmentRate,
                value: '${avgCommitmentRate.toStringAsFixed(0)}%',
                subtitle: context.l10n.groupCommitmentRateSubtitle,
                color: AppColors.primary,
                icon: Icons.auto_graph_rounded,
              ),
              AttendanceStatCard(
                title: context.l10n.committedStudentsCount,
                value: '$committedCount',
                subtitle: 'أنجزوا ≥ 75% من المحتوى',
                color: AppColors.success,
                icon: Icons.verified_rounded,
              ),
              AttendanceStatCard(
                title: context.l10n.needsFollowupCount,
                value: '$needsFollowupCount',
                subtitle: 'أنجزوا < 35% من المحتوى',
                color: AppColors.error,
                icon: Icons.notification_important_rounded,
              ),
            ],
          ),
        ),

        // Live Search & Filter Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.l10n.searchStudentOrPhoneHint,
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s12,
                    vertical: AppSpacing.s8,
                  ),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val.trim());
                },
              ),
              const SizedBox(height: AppSpacing.s8),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: Text(
                        context.l10n.filterAllCount(students.length),
                      ),
                      selected: _overallFilter == null,
                      selectedColor: AppColors.primaryLight.withValues(
                        alpha: 0.25,
                      ),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _overallFilter == null
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: _overallFilter == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _overallFilter = null),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    FilterChip(
                      label: Text(
                        context.l10n.filterCommitted(committedCount),
                      ),
                      selected: _overallFilter == 'committed',
                      selectedColor: AppColors.success.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.success,
                      labelStyle: TextStyle(
                        color: _overallFilter == 'committed'
                            ? AppColors.success
                            : AppColors.textPrimary,
                        fontWeight: _overallFilter == 'committed'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(
                        () => _overallFilter =
                            _overallFilter == 'committed' ? null : 'committed',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    FilterChip(
                      label: Text(
                        context.l10n.filterModerate(moderateCount),
                      ),
                      selected: _overallFilter == 'moderate',
                      selectedColor: AppColors.warning.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.warning,
                      labelStyle: TextStyle(
                        color: _overallFilter == 'moderate'
                            ? AppColors.warning
                            : AppColors.textPrimary,
                        fontWeight: _overallFilter == 'moderate'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(
                        () => _overallFilter =
                            _overallFilter == 'moderate' ? null : 'moderate',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    FilterChip(
                      label: Text(
                        context.l10n.filterNeedsFollowup(needsFollowupCount),
                      ),
                      selected: _overallFilter == 'needs_followup',
                      selectedColor: AppColors.error.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.error,
                      labelStyle: TextStyle(
                        color: _overallFilter == 'needs_followup'
                            ? AppColors.error
                            : AppColors.textPrimary,
                        fontWeight: _overallFilter == 'needs_followup'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(
                        () => _overallFilter =
                            _overallFilter == 'needs_followup'
                            ? null
                            : 'needs_followup',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.s8),

        // Students List
        Expanded(
          child: displayedStudents.isEmpty
              ? AppEmptyView(
                  message: context.l10n.noStudentsMatchFilterMessage,
                  actionText: context.l10n.resetFiltersAction,
                  onAction: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _overallFilter = null;
                    });
                  },
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.s16),
                  itemCount: displayedStudents.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.s8),
                  itemBuilder: (context, index) {
                    final student = displayedStudents[index];
                    return StudentAttendanceRowCard(
                      student: student,
                      isOverallView: true,
                      onNoteTap: () => TeacherAttendanceDialogs.showNoteDialog(
                        context,
                        student: student,
                        attendanceCubit: widget.attendanceCubit,
                      ),
                      onWhatsAppTap: () =>
                          TeacherAttendanceDialogs.showWhatsAppOverallNotice(
                        context,
                        student: student,
                        loadedState: widget.loadedState,
                        selectedGroupId: widget.selectedGroupId,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
