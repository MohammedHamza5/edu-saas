import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/attendance_entity.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/attendance_stat_card.dart';
import '../widgets/student_attendance_row_card.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';

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
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  AttendanceStatus? _statusFilter;


  @override
  void initState() {
    super.initState();
    _attendanceCubit =
        widget.attendanceCubit ?? InjectionContainer.createAttendanceCubit();

    final initialId = widget.initialGroupId ?? TeacherGroupFilterBar.lastSelectedGroupId;
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
    });
    _loadAttendance();
  }

  void _onDatePicked(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadAttendance();
  }

  void _prevDay() {
    _onDatePicked(_selectedDate.subtract(const Duration(days: 1)));
  }

  void _nextDay() {
    _onDatePicked(_selectedDate.add(const Duration(days: 1)));
  }

  void _jumpToToday() {
    _onDatePicked(DateTime.now());
  }

  Future<void> _loadAttendance({bool forceRefresh = false}) async {
    if (_selectedGroupId == null) return;
    await _attendanceCubit.loadGroupAttendance(
      groupId: _selectedGroupId!,
      date: _selectedDate,
      forceRefresh: forceRefresh,
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: Localizations.localeOf(context),
    );
    if (picked != null && picked != _selectedDate) {
      _onDatePicked(picked);
    }
  }

  void _showNoteDialog(BuildContext context, StudentAttendanceItem student) {
    final controller = TextEditingController(text: student.note ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            context.l10n.noteForStudentTitle(student.studentName),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: AppTextField(
            controller: controller,
            hintText: context.l10n.attendanceNoteHint,
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(context.l10n.cancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
              ),
              onPressed: () {
                _attendanceCubit.updateStudentStatus(
                  student.studentId,
                  student.status,
                  note: controller.text,
                );
                Navigator.of(dialogCtx).pop();
              },
              child: Text(
                context.l10n.save,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final dateStr = DateFormat('yyyy/MM/dd - EEEE', locale).format(_selectedDate);

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

            Widget bodyContent = BlocConsumer<AttendanceCubit, AttendanceState>(
              listener: (context, state) {
                if (state is TeacherAttendanceLoaded && state.saveSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message ?? context.l10n.attendanceSavedSuccess),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else if (state is TeacherAttendanceLoaded &&
                    state.message != null &&
                    !state.saveSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.message!),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              builder: (context, attendanceState) {
                return Center(
                  child: ResponsiveContainer(
                    maxWidth: ResponsiveBreakpoints.maxContentWidth,
                    child: Column(
                      children: [
                        // Modern Web SaaS Hero Header (Zero AppBar!)
                        _buildHeroHeader(context),

                        // Top Filter Header: Group & Lecture Selector
                        _buildHeaderBar(context, dateStr),

                        // Main Content
                        Expanded(
                          child: _buildAttendanceContent(context, attendanceState),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

            if (groupsCubit != null) {
              return BlocConsumer<GroupsCubit, GroupsState>(
                bloc: groupsCubit,
                listener: (context, groupsState) {
                  if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
                    if (_selectedGroupId == null ||
                        !groupsState.groups.any((g) => g.id == _selectedGroupId)) {
                      final targetGroup = (widget.initialGroupId != null &&
                              groupsState.groups.any((g) => g.id == widget.initialGroupId))
                          ? groupsState.groups.firstWhere((g) => g.id == widget.initialGroupId)
                          : groupsState.groups.first;
                      TeacherGroupFilterBar.lastSelectedGroupId = targetGroup.id;
                      setState(() {
                        _selectedGroupId = targetGroup.id;
                      });
                      _loadAttendance();
                    }
                  }
                },
                builder: (context, groupsState) {
                  if (groupsState is GroupsLoaded && groupsState.groups.isEmpty) {
                    return Center(
                      child: ResponsiveContainer(
                        maxWidth: ResponsiveBreakpoints.maxContentWidth,
                        child: Column(
                          children: [
                            _buildHeroHeader(context),
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.s24),
                                  child: Container(
                                    padding: const EdgeInsets.all(AppSpacing.s32),
                                    constraints: const BoxConstraints(maxWidth: 480),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
                                      border: Border.all(color: AppColors.border),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(AppSpacing.s16),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.1),
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
                                          onPressed: () => CreateGroupDialog.show(context),
                                          icon: const Icon(Icons.add_rounded, size: 20),
                                          label: Text(context.l10n.createGroupAction),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.s24,
                                              vertical: AppSpacing.s12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
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

  Widget _buildHeroHeader(BuildContext context) {
    final isMobile = context.screenWidth < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? AppSpacing.s16 : AppSpacing.s24,
        vertical: isMobile ? AppSpacing.s12 : AppSpacing.s16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          bottom: BorderSide(color: AppColors.border),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: const Icon(
              Icons.play_circle_outline_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.s14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: AppSpacing.s8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      context.l10n.takeAttendanceTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        context.l10n.recordedLecturesTrackingBadge,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  context.l10n.takeAttendanceSubtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: context.l10n.refreshAttendanceSheetTooltip,
            onPressed: () => _loadAttendance(forceRefresh: true),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, String formattedDate) {
    final isCompact = context.screenWidth < 600;

    final groupSelector = BlocBuilder<GroupsCubit, GroupsState>(
      builder: (context, groupsState) {
        if (groupsState is GroupsLoaded) {
          final groups = groupsState.groups;
          if (groups.isNotEmpty && _selectedGroupId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _onGroupChanged(groups.first.id);
              }
            });
          }

          return DropdownButtonFormField<String>(
            isExpanded: true,
            value: _selectedGroupId,
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
            onChanged: _onGroupChanged,
          );
        }
        return SizedBox(
          height: 48,
          child: Center(
            child: Text(
              context.l10n.loadingGroups,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        );
      },
    );

    final dateSelectorSection = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s6,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: AppColors.primary,
            ),
            tooltip: context.l10n.prevDayTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: _prevDay,
          ),
          Expanded(
            child: InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.s6,
                  horizontal: AppSpacing.s4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.event_note_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            context.l10n.sessionDateSubtitle,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down_rounded, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.chevron_left_rounded,
              size: 22,
              color: AppColors.primary,
            ),
            tooltip: context.l10n.nextDayTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: _nextDay,
          ),
          IconButton(
            icon: const Icon(
              Icons.today_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            tooltip: context.l10n.todaySessionTooltip,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
            onPressed: _jumpToToday,
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: isCompact
          ? Column(
              children: [
                groupSelector,
                const SizedBox(height: AppSpacing.s10),
                dateSelectorSection,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: groupSelector),
                const SizedBox(width: AppSpacing.s12),
                Expanded(flex: 4, child: dateSelectorSection),
              ],
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

      final stats = attendanceState.currentStats;

      final displayedStudents = students.where((s) {
        if (_searchQuery.isNotEmpty) {
          final q = _searchQuery.toLowerCase();
          final matchName = s.studentName.toLowerCase().contains(q);
          final matchPhone = s.phone?.contains(q) ?? false;
          if (!matchName && !matchPhone) return false;
        }
        if (_statusFilter != null && s.status != _statusFilter) {
          return false;
        }
        return true;
      }).toList();

      return Column(
        children: [
          // Statistics Grid (Responsive 2 cols mobile, 4 cols tablet/desktop)
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
                  subtitle: context.l10n.completedWatchSubtitle(stats.totalSessions),
                  color: AppColors.success,
                  icon: Icons.check_circle_rounded,
                ),
                AttendanceStatCard(
                  title: context.l10n.notWatchedYetTitle,
                  value: '${stats.absentCount}',
                  subtitle: context.l10n.absentFromLectureSubtitle,
                  color: AppColors.error,
                  icon: Icons.cancel_rounded,
                ),
                AttendanceStatCard(
                  title: context.l10n.inProgressWatchTitle,
                  value: '${stats.lateCount}',
                  subtitle: context.l10n.partialWatchSubtitle,
                  color: AppColors.warning,
                  icon: Icons.play_circle_filled_rounded,
                ),
                AttendanceStatCard(
                  title: context.l10n.attendanceRateTitle,
                  value: '${stats.attendancePercentage.toStringAsFixed(0)}%',
                  subtitle: context.l10n.groupCommitmentRateSubtitle,
                  color: AppColors.primary,
                  icon: Icons.analytics_rounded,
                ),
              ],
            ),
          ),

          // Live Search & Status Filters Bar
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
                        label: Text(context.l10n.filterAllCount(students.length)),
                        selected: _statusFilter == null,
                        selectedColor: AppColors.primaryLight.withValues(
                          alpha: 0.25,
                        ),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: _statusFilter == null
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight: _statusFilter == null
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(() => _statusFilter = null),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      FilterChip(
                        label: Text(context.l10n.filterPresentCount(stats.presentCount)),
                        selected: _statusFilter == AttendanceStatus.present,
                        selectedColor: AppColors.success.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.success,
                        labelStyle: TextStyle(
                          color: _statusFilter == AttendanceStatus.present
                              ? AppColors.success
                              : AppColors.textPrimary,
                          fontWeight: _statusFilter == AttendanceStatus.present
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(
                          () => _statusFilter =
                              _statusFilter == AttendanceStatus.present
                              ? null
                              : AttendanceStatus.present,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      FilterChip(
                        label: Text(context.l10n.filterLateCount(stats.lateCount)),
                        selected: _statusFilter == AttendanceStatus.late,
                        selectedColor: AppColors.warning.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.warning,
                        labelStyle: TextStyle(
                          color: _statusFilter == AttendanceStatus.late
                              ? AppColors.warning
                              : AppColors.textPrimary,
                          fontWeight: _statusFilter == AttendanceStatus.late
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(
                          () => _statusFilter =
                              _statusFilter == AttendanceStatus.late
                              ? null
                              : AttendanceStatus.late,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      FilterChip(
                        label: Text(context.l10n.filterAbsentCount(stats.absentCount)),
                        selected: _statusFilter == AttendanceStatus.absent,
                        selectedColor: AppColors.error.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.error,
                        labelStyle: TextStyle(
                          color: _statusFilter == AttendanceStatus.absent
                              ? AppColors.error
                              : AppColors.textPrimary,
                          fontWeight: _statusFilter == AttendanceStatus.absent
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(
                          () => _statusFilter =
                              _statusFilter == AttendanceStatus.absent
                              ? null
                              : AttendanceStatus.absent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.s8),

          // Student List / Filter Empty View
          Expanded(
            child: displayedStudents.isEmpty
                ? AppEmptyView(
                    message: context.l10n.noStudentsMatchFilterMessage,
                    actionText: context.l10n.resetFiltersAction,
                    onAction: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _statusFilter = null;
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
                      return _buildStudentAttendanceRow(context, student);
                    },
                  ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
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

  Widget _buildStudentAttendanceRow(
    BuildContext context,
    StudentAttendanceItem student,
  ) {
    return StudentAttendanceRowCard(
      student: student,
      onStatusChanged: (status) {
        _attendanceCubit.updateStudentStatus(student.studentId, status);
      },
      onNoteTap: () => _showNoteDialog(context, student),
    );
  }
}
