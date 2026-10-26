import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../dialogs/teacher_attendance_dialogs.dart';
import '../widgets/attendance_stat_card.dart';
import '../widgets/student_attendance_row_card.dart';
import '../widgets/teacher_attendance_header_bar.dart';
import '../widgets/teacher_attendance_hero_header.dart';
import '../widgets/teacher_attendance_overall_view.dart';

export '../widgets/teacher_attendance_header_bar.dart' show EngagementViewMode;

class TeacherAttendancePage extends StatefulWidget {
  final String? initialGroupId;
  final AttendanceCubit? attendanceCubit;

  const TeacherAttendancePage({
    super.key,
    this.initialGroupId,
    this.attendanceCubit,
  });

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  late final AttendanceCubit _attendanceCubit;
  String? _selectedGroupId;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  EngagementViewMode _viewMode = EngagementViewMode.byLecture;

  // Filter keys
  String? _lectureFilter; // 'all', 'completed', 'in_progress', 'not_started'

  @override
  void initState() {
    super.initState();
    _attendanceCubit =
        widget.attendanceCubit ?? InjectionContainer.createAttendanceCubit();

    final initialId =
        widget.initialGroupId ?? TeacherGroupFilterBar.lastSelectedGroupId;
    final groupsState = context.read<GroupsCubit>().state;
    if (initialId != null) {
      _selectedGroupId = initialId;
    } else if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
      _selectedGroupId = groupsState.groups.first.id;
    }

    if (_selectedGroupId != null) {
      _loadAttendance();
    }

    // Load groups if needed
    context.read<GroupsCubit>().loadGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.attendanceCubit == null) {
      _attendanceCubit.close();
    }
    super.dispose();
  }

  void _onGroupChanged(String? newGroupId) {
    if (newGroupId == null || newGroupId == _selectedGroupId) return;
    TeacherGroupFilterBar.lastSelectedGroupId = newGroupId;
    setState(() {
      _selectedGroupId = newGroupId;
      _lectureFilter = null;
    });
    _loadAttendance();
  }

  Future<void> _loadAttendance({bool forceRefresh = false}) async {
    if (_selectedGroupId == null) return;
    await _attendanceCubit.loadGroupAttendance(
      groupId: _selectedGroupId!,
      date: DateTime.now(),
      forceRefresh: forceRefresh,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _attendanceCubit,
      child: Scaffold(
        body: Builder(
          builder: (context) {
            GroupsCubit? groupsCubit;
            try {
              groupsCubit = context.read<GroupsCubit>();
            } catch (_) {
              groupsCubit = null;
            }

            Widget bodyContent = BlocBuilder<AttendanceCubit, AttendanceState>(
              builder: (context, attendanceState) {
                return ResponsiveContainer(
                  child: Column(
                      children: [
                        // Automated Modern SaaS Hero Header (Zero Manual Save Button!)
                        TeacherAttendanceHeroHeader(
                          onRefresh: () => _loadAttendance(forceRefresh: true),
                        ),

                        // Filter & View Mode Switcher Header
                        TeacherAttendanceHeaderBar(
                          selectedGroupId: _selectedGroupId,
                          onGroupChanged: _onGroupChanged,
                          viewMode: _viewMode,
                          onViewModeChanged: (mode) {
                            setState(() {
                              _viewMode = mode;
                              _lectureFilter = null;
                            });
                          },
                          attendanceState: attendanceState,
                          onLectureSelected: (lecId) =>
                              _attendanceCubit.selectLecture(lecId),
                        ),

                        // Main Content (Statistics + Filter Chips + Automated Student Cards)
                        Expanded(
                          child: _buildAttendanceContent(
                            context,
                            attendanceState,
                          ),
                        ),
                      ],
                    ),
                  );
              },
            );

            if (groupsCubit != null) {
              return BlocConsumer<GroupsCubit, GroupsState>(
                bloc: groupsCubit,
                listener: (context, groupsState) {
                  if (groupsState is GroupsLoaded &&
                      groupsState.groups.isNotEmpty) {
                    if (_selectedGroupId == null ||
                        !groupsState.groups.any(
                          (g) => g.id == _selectedGroupId,
                        )) {
                      final targetGroup =
                          (widget.initialGroupId != null &&
                              groupsState.groups.any(
                                (g) => g.id == widget.initialGroupId,
                              ))
                          ? groupsState.groups.firstWhere(
                              (g) => g.id == widget.initialGroupId,
                            )
                          : groupsState.groups.first;
                      TeacherGroupFilterBar.lastSelectedGroupId =
                          targetGroup.id;
                      setState(() {
                        _selectedGroupId = targetGroup.id;
                      });
                      _loadAttendance();
                    }
                  }
                },
                builder: (context, groupsState) {
                  if (groupsState is GroupsLoaded &&
                      groupsState.groups.isEmpty) {
                    return ResponsiveContainer(
                      child: Column(
                          children: [
                            TeacherAttendanceHeroHeader(
                              onRefresh: () =>
                                  _loadAttendance(forceRefresh: true),
                            ),
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.s24),
                                  child: Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.s32,
                                    ),
                                    constraints: const BoxConstraints(
                                      maxWidth: 480,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusLarge,
                                      ),
                                      border: Border.all(
                                        color: AppColors.border,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.03,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(
                                            AppSpacing.s16,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.1,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.group_add_rounded,
                                            size: 48,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(height: AppSpacing.s20),
                                        Text(
                                          context.l10n.noGroupsYet,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.textPrimary,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: AppSpacing.s8),
                                        Text(
                                          context.l10n.noGroupsCreatedYetDesc,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.textSecondary,
                                            height: 1.4,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: AppSpacing.s24),
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              CreateGroupDialog.show(context),
                                          icon: const Icon(
                                            Icons.add_rounded,
                                            size: 20,
                                          ),
                                          label: Text(
                                            context.l10n.createGroupAction,
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.s24,
                                              vertical: AppSpacing.s12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppSpacing.radiusMedium,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                  }
                  return bodyContent;
                },
              );
            }

            return bodyContent;
          },
        ),
      ),
    );
  }

  Widget _buildAttendanceContent(
    BuildContext context,
    AttendanceState attendanceState,
  ) {
    if (_selectedGroupId == null) {
      final groupsState = context.read<GroupsCubit>().state;
      if (groupsState is GroupsLoading || groupsState is GroupsInitial) {
        return _buildSkeletonLoading();
      }
      return AppEmptyView(
        message: context.l10n.selectGroupToViewAttendanceMessage,
        icon: Icons.groups_rounded,
      );
    }

    if (attendanceState is AttendanceLoading ||
        attendanceState is AttendanceInitial) {
      return _buildSkeletonLoading();
    }

    if (attendanceState is AttendanceError) {
      return AppErrorView(
        message: attendanceState.message,
        onRetry: () => _loadAttendance(forceRefresh: true),
      );
    }

    if (attendanceState is TeacherAttendanceLoaded) {
      final students = attendanceState.students;
      if (students.isEmpty) {
        return AppEmptyView(
          message: context.l10n.noStudentsInGroupMessage,
          icon: Icons.person_off_rounded,
        );
      }

      // Render based on selected View Mode
      if (_viewMode == EngagementViewMode.byLecture) {
        return _buildByLectureView(context, attendanceState);
      } else {
        return TeacherAttendanceOverallView(
          loadedState: attendanceState,
          selectedGroupId: _selectedGroupId,
          attendanceCubit: _attendanceCubit,
        );
      }
    }

    return const SizedBox.shrink();
  }

  /// View Mode 1: By Lecture View
  Widget _buildByLectureView(
    BuildContext context,
    TeacherAttendanceLoaded loadedState,
  ) {
    final students = loadedState.students;
    final stats = loadedState.currentStats;

    // Filter students
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
                subtitle: loadedState.activeLecture != null
                    ? loadedState.activeLecture!.title
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
                        attendanceCubit: _attendanceCubit,
                      ),
                      onWhatsAppTap: () =>
                          TeacherAttendanceDialogs.showWhatsAppLectureNotice(
                        context,
                        student: student,
                        loadedState: loadedState,
                        selectedGroupId: _selectedGroupId,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSkeletonLoading() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.s16),
      children: [
        ResponsiveGrid(
          mobileColumns: 2,
          tabletColumns: 4,
          desktopColumns: 4,
          spacing: AppSpacing.s8,
          runSpacing: AppSpacing.s8,
          children: List.generate(
            4,
            (_) => AppCard(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: AcademicShimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s8),
                    Container(
                      width: 40,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s16),
        ...List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: AppCard(
              padding: const EdgeInsets.all(AppSpacing.s16),
              child: AcademicShimmer(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFFE2E8F0),
                    ),
                    const SizedBox(width: AppSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
