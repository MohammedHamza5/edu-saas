import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/teacher_attendance_header_bar.dart';
import '../widgets/teacher_attendance_hero_header.dart';
import '../widgets/teacher_attendance_lecture_view.dart';
import '../widgets/teacher_attendance_no_groups_view.dart';
import '../widgets/teacher_attendance_overall_view.dart';
import '../widgets/teacher_attendance_skeleton_view.dart';

export '../widgets/teacher_attendance_header_bar.dart' show EngagementViewMode;

/// Teacher Attendance Page coordinator supporting by-lecture and overall engagement views.
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
  EngagementViewMode _viewMode = EngagementViewMode.byLecture;

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
                    return TeacherAttendanceNoGroupsView(
                      onRefresh: () => _loadAttendance(forceRefresh: true),
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
        return const TeacherAttendanceSkeletonView();
      }
      return AppEmptyView(
        message: context.l10n.selectGroupToViewAttendanceMessage,
        icon: Icons.groups_rounded,
      );
    }

    if (attendanceState is AttendanceLoading ||
        attendanceState is AttendanceInitial) {
      return const TeacherAttendanceSkeletonView();
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
        return TeacherAttendanceLectureView(
          loadedState: attendanceState,
          selectedGroupId: _selectedGroupId,
          attendanceCubit: _attendanceCubit,
        );
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
}
