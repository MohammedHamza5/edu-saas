import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/extensions/responsive_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/responsive_breakpoints.dart';
import '../../../../core/utils/whatsapp_report_generator.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../../core/widgets/responsive_grid.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../../groups/presentation/widgets/create_group_dialog.dart';
import '../../domain/entities/attendance_entity.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/attendance_stat_card.dart';
import '../widgets/student_attendance_row_card.dart';

enum EngagementViewMode {
  byLecture,
  overall,
}

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
  String? _overallFilter; // 'all', 'committed', 'moderate', 'needs_followup'

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
      _overallFilter = null;
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
              onPressed: () async {
                final note = controller.text.trim();
                final messenger = ScaffoldMessenger.of(context);
                final successText = context.l10n.studentNoteSavedSuccess;
                Navigator.of(dialogCtx).pop();
                await _attendanceCubit.updateStudentNote(
                  student.studentId,
                  note,
                );
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(successText),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
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

  void _showWhatsAppLectureNotice(
    BuildContext context,
    StudentAttendanceItem student,
    TeacherAttendanceLoaded loadedState,
  ) {
    final groupsState = context.read<GroupsCubit>().state;
    String? groupName;
    if (groupsState is GroupsLoaded) {
      final match = groupsState.groups.where((g) => g.id == _selectedGroupId);
      if (match.isNotEmpty) {
        groupName = match.first.name;
      }
    }

    final activeLecture = loadedState.activeLecture;
    final lectureTitle = activeLecture != null
        ? activeLecture.title
        : (student.currentLectureTitle ?? context.l10n.allLecturesOverview);

    final reportText = WhatsAppReportGenerator.generateLectureWatchNotice(
      studentName: student.studentName,
      lectureTitle: lectureTitle,
      watchProgressPercent: student.watchProgressPercent,
      groupName: groupName,
      watchMinutes: student.watchSeconds > 0
          ? (student.watchSeconds / 60).round()
          : null,
      totalMinutes: student.totalDurationSeconds > 0
          ? (student.totalDurationSeconds / 60).round()
          : null,
      customNote: student.note,
    );

    WhatsAppReportGenerator.showReportPreviewDialog(
      context,
      studentName: student.studentName,
      reportText: reportText,
      phone: student.phone,
    );
  }

  void _showWhatsAppOverallNotice(
    BuildContext context,
    StudentAttendanceItem student,
    TeacherAttendanceLoaded loadedState,
  ) {
    final groupsState = context.read<GroupsCubit>().state;
    String groupName = 'المجموعة';
    if (groupsState is GroupsLoaded) {
      final match = groupsState.groups.where((g) => g.id == _selectedGroupId);
      if (match.isNotEmpty) {
        groupName = match.first.name;
      }
    }

    final total = student.totalLecturesCount > 0 ? student.totalLecturesCount : 1;
    final completed = student.completedLecturesCount;
    final completionPct = (completed / total) * 100.0;

    final reportText = WhatsAppReportGenerator.generateOverallEngagementNotice(
      studentName: student.studentName,
      groupName: groupName,
      completedLectures: completed,
      totalLectures: total,
      completionPercentage: completionPct,
      customNote: student.note,
    );

    WhatsAppReportGenerator.showReportPreviewDialog(
      context,
      studentName: student.studentName,
      reportText: reportText,
      phone: student.phone,
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
                return Center(
                  child: ResponsiveContainer(
                    maxWidth: ResponsiveBreakpoints.maxContentWidth,
                    child: Column(
                      children: [
                        // Automated Modern SaaS Hero Header (Zero Manual Save Button!)
                        _buildHeroHeader(context),

                        // Filter & View Mode Switcher Header
                        _buildHeaderBar(context, attendanceState),

                        // Main Content (Statistics + Filter Chips + Automated Student Cards)
                        Expanded(
                          child: _buildAttendanceContent(
                            context,
                            attendanceState,
                          ),
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

  /// Modern Automated SaaS Hero Header
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
        border: const Border(bottom: BorderSide(color: AppColors.border)),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.16),
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
              Icons.insights_rounded,
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
                      context.l10n.studentEngagementTitle,
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
                        context.l10n.studentEngagementBadge,
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
                  context.l10n.studentEngagementSubtitle,
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
            tooltip: context.l10n.refreshEngagementTooltip,
            onPressed: () => _loadAttendance(forceRefresh: true),
          ),
        ],
      ),
    );
  }

  /// Top Bar: Group Selector, View Mode Switcher, and Lecture Selector
  Widget _buildHeaderBar(
    BuildContext context,
    AttendanceState attendanceState,
  ) {
    final isCompact = context.screenWidth < 768;

    final groupSelector = BlocBuilder<GroupsCubit, GroupsState>(
      builder: (context, groupsState) {
        if (groupsState is GroupsInitial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.read<GroupsCubit>().loadGroups();
          });
        }

        if (groupsState is GroupsLoaded) {
          final groups = groupsState.groups;
          if (groups.isNotEmpty && _selectedGroupId == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _onGroupChanged(groups.first.id);
              }
            });
          }

          final currentValue = groups.any((g) => g.id == _selectedGroupId)
              ? _selectedGroupId
              : (groups.isNotEmpty ? groups.first.id : null);

          return DropdownButtonFormField<String>(
            isExpanded: true,
            value: currentValue,
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
    if (_viewMode == EngagementViewMode.byLecture &&
        attendanceState is TeacherAttendanceLoaded &&
        attendanceState.availableLectures.isNotEmpty) {
      final lectures = attendanceState.availableLectures;
      final selectedId = attendanceState.selectedLectureContentId;

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
                    if (val) _attendanceCubit.selectLecture(null);
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
                        if (val) _attendanceCubit.selectLecture(lec.contentId);
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
  }

  Widget _buildViewModePill(
    BuildContext context, {
    required EngagementViewMode mode,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () {
        if (_viewMode != mode) {
          setState(() {
            _viewMode = mode;
            _lectureFilter = null;
            _overallFilter = null;
          });
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
        return _buildOverallView(context, attendanceState);
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
                      onNoteTap: () => _showNoteDialog(context, student),
                      onWhatsAppTap: () => _showWhatsAppLectureNotice(
                        context,
                        student,
                        loadedState,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// View Mode 2: Overall Student Progress View
  Widget _buildOverallView(
    BuildContext context,
    TeacherAttendanceLoaded loadedState,
  ) {
    final students = loadedState.students;

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
                subtitle: loadedState.availableLectures.isNotEmpty
                    ? '${loadedState.availableLectures.length} محاضرات'
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
                      onNoteTap: () => _showNoteDialog(context, student),
                      onWhatsAppTap: () => _showWhatsAppOverallNotice(
                        context,
                        student,
                        loadedState,
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
