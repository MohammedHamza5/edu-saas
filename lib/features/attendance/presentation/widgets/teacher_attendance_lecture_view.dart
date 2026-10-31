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

/// Detailed attendance view breakdown for a specific selected lecture.
class TeacherAttendanceLectureView extends StatefulWidget {
  final TeacherAttendanceLoaded loadedState;
  final String? selectedGroupId;
  final AttendanceCubit attendanceCubit;

  const TeacherAttendanceLectureView({
    super.key,
    required this.loadedState,
    required this.selectedGroupId,
    required this.attendanceCubit,
  });

  @override
  State<TeacherAttendanceLectureView> createState() =>
      _TeacherAttendanceLectureViewState();
}

class _TeacherAttendanceLectureViewState
    extends State<TeacherAttendanceLectureView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _lectureFilter; // 'all', 'completed', 'in_progress', 'not_started'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.loadedState.students;
    final stats = widget.loadedState.currentStats;

    // Filter students based on search and status chip
    final displayedStudents = students.where((s) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = s.studentName.toLowerCase().contains(q);
        final matchPhone = s.phone?.contains(q) ?? false;
        if (!matchName && !matchPhone) return false;
      }
      if (_lectureFilter != null) {
        if (_lectureFilter == 'completed' &&
            !(s.isCompleted || s.watchProgressPercent >= 80.0)) {
          return false;
        }
        if (_lectureFilter == 'in_progress' &&
            (s.isCompleted ||
                s.watchProgressPercent >= 80.0 ||
                s.watchProgressPercent <= 0.0)) {
          return false;
        }
        if (_lectureFilter == 'not_started' && s.watchProgressPercent > 0.0) {
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
                title: context.l10n.attendedLectureTitle,
                value: '${stats.presentCount}',
                subtitle: context.l10n.completedWatchSubtitle(
                  stats.totalSessions,
                ),
                color: AppColors.success,
                icon: Icons.check_circle_rounded,
              ),
              AttendanceStatCard(
                title: context.l10n.inProgressWatchTitle,
                value: '${stats.lateCount}',
                subtitle: context.l10n.partialWatchSubtitle,
                color: AppColors.warning,
                icon: Icons.play_circle_filled_rounded,
              ),
              AttendanceStatCard(
                title: context.l10n.notWatchedYetTitle,
                value: '${stats.absentCount}',
                subtitle: context.l10n.absentFromLectureSubtitle,
                color: AppColors.error,
                icon: Icons.cancel_outlined,
              ),
              AttendanceStatCard(
                title: context.l10n.attendanceRateTitle,
                value:
                    '${stats.averageWatchPercentage.toStringAsFixed(stats.averageWatchPercentage > 0 && stats.averageWatchPercentage < 10 ? 1 : 0)}%',
                subtitle: widget.loadedState.activeLecture != null
                    ? widget.loadedState.activeLecture!.title
                    : context.l10n.groupCommitmentRateSubtitle,
                color: AppColors.primary,
                icon: Icons.analytics_rounded,
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
                      selected: _lectureFilter == null,
                      selectedColor: AppColors.primaryLight.withValues(
                        alpha: 0.25,
                      ),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _lectureFilter == null
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: _lectureFilter == null
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _lectureFilter = null),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    FilterChip(
                      label: Text(
                        context.l10n.filterPresentCount(stats.presentCount),
                      ),
                      selected: _lectureFilter == 'completed',
                      selectedColor: AppColors.success.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.success,
                      labelStyle: TextStyle(
                        color: _lectureFilter == 'completed'
                            ? AppColors.success
                            : AppColors.textPrimary,
                        fontWeight: _lectureFilter == 'completed'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(
                        () => _lectureFilter =
                            _lectureFilter == 'completed' ? null : 'completed',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    FilterChip(
                      label: Text(
                        context.l10n.filterLateCount(stats.lateCount),
                      ),
                      selected: _lectureFilter == 'in_progress',
                      selectedColor: AppColors.warning.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.warning,
                      labelStyle: TextStyle(
                        color: _lectureFilter == 'in_progress'
                            ? AppColors.warning
                            : AppColors.textPrimary,
                        fontWeight: _lectureFilter == 'in_progress'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(
                        () => _lectureFilter = _lectureFilter == 'in_progress'
                            ? null
                            : 'in_progress',
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    FilterChip(
                      label: Text(
                        context.l10n.filterAbsentCount(stats.absentCount),
                      ),
                      selected: _lectureFilter == 'not_started',
                      selectedColor: AppColors.error.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.error,
                      labelStyle: TextStyle(
                        color: _lectureFilter == 'not_started'
                            ? AppColors.error
                            : AppColors.textPrimary,
                        fontWeight: _lectureFilter == 'not_started'
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(
                        () => _lectureFilter = _lectureFilter == 'not_started'
                            ? null
                            : 'not_started',
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
                      _lectureFilter = null;
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
                      isOverallView: false,
                      onNoteTap: () => TeacherAttendanceDialogs.showNoteDialog(
                        context,
                        student: student,
                        attendanceCubit: widget.attendanceCubit,
                      ),
                      onWhatsAppTap: () =>
                          TeacherAttendanceDialogs.showWhatsAppLectureNotice(
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
