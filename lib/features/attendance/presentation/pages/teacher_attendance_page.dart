import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
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

  @override
  void initState() {
    super.initState();
    _attendanceCubit = widget.attendanceCubit ?? InjectionContainer.createAttendanceCubit();
    _selectedGroupId = widget.initialGroupId;

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

  void _loadAttendance() {
    if (_selectedGroupId == null) return;
    _attendanceCubit.loadGroupAttendance(
      groupId: _selectedGroupId!,
      date: _selectedDate,
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      locale: const Locale('ar'),
    );
    if (picked != null && picked != _selectedDate) {
      _onDatePicked(picked);
    }
  }

  void _showNoteDialog(
    BuildContext context,
    StudentAttendanceItem student,
  ) {
    final controller = TextEditingController(text: student.note ?? '');

    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            'ملاحظة للطالب: ${student.studentName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: AppTextField(
            controller: controller,
            hintText: 'اكتب ملاحظة (مثال: تأخر بعذر مسبق، استئذان مبكر...)',
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                _attendanceCubit.updateStudentStatus(
                  student.studentId,
                  student.status,
                  note: controller.text,
                );
                Navigator.of(dialogCtx).pop();
              },
              child: const Text('حفظ الملاحظة', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/MM/dd - EEEE', 'ar').format(_selectedDate);

    return BlocProvider.value(
      value: _attendanceCubit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('رصد الحضور والغياب'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث الكشف',
              onPressed: _loadAttendance,
            ),
          ],
        ),
        body: BlocConsumer<AttendanceCubit, AttendanceState>(
          listener: (context, state) {
            if (state is TeacherAttendanceLoaded && state.saveSuccess) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message ?? 'تم حفظ كشف الحضور بنجاح'),
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
                    // Top Filter Header: Group & Date Pickers
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
        ),
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, String formattedDate) {
    final isCompact = context.screenWidth < 480;

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
            value: _selectedGroupId,
            decoration: InputDecoration(
              labelText: 'المجموعة الدراسية',
              prefixIcon: const Icon(Icons.groups_rounded, color: AppColors.primary),
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
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              );
            }).toList(),
            onChanged: _onGroupChanged,
          );
        }
        return const SizedBox(
          height: 48,
          child: Center(
            child: Text(
              'جارٍ تحميل المجموعات...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
        );
      },
    );

    final datePickerButton = InkWell(
      onTap: () => _selectDate(context),
      borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s12,
          vertical: AppSpacing.s12,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: AppSpacing.s8),
            Flexible(
              child: Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border),
        ),
      ),
      child: isCompact
          ? Column(
              children: [
                groupSelector,
                const SizedBox(height: AppSpacing.s12),
                datePickerButton,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: groupSelector),
                const SizedBox(width: AppSpacing.s12),
                Expanded(flex: 2, child: datePickerButton),
              ],
            ),
    );
  }

  Widget _buildAttendanceContent(
    BuildContext context,
    AttendanceState attendanceState,
  ) {
    if (_selectedGroupId == null) {
      return const AppEmptyView(
        message: 'اختر مجموعة دراسية\nيرجى اختيار مجموعة من القائمة بالأعلى لعرض الطلاب ورصد الحضور.',
        icon: Icons.groups_rounded,
      );
    }

    if (attendanceState is AttendanceLoading || attendanceState is AttendanceInitial) {
      return const AppLoadingView(message: 'جارٍ جلب كشف الحضور والطلاب...');
    }

    if (attendanceState is AttendanceError) {
      return AppErrorView(
        message: attendanceState.message,
        onRetry: _loadAttendance,
      );
    }

    if (attendanceState is TeacherAttendanceLoaded) {
      final students = attendanceState.students;
      if (students.isEmpty) {
        return const AppEmptyView(
          message: 'لا يوجد طلاب في هذه المجموعة\nلم يتم إضافة أي طالب نشط إلى هذه المجموعة بعد.',
          icon: Icons.person_off_rounded,
        );
      }

      final stats = attendanceState.currentStats;

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
                  title: 'الحاضرون',
                  value: '${stats.presentCount}',
                  subtitle: 'من إجمالي ${stats.totalSessions}',
                  color: AppColors.success,
                  icon: Icons.check_circle_rounded,
                ),
                AttendanceStatCard(
                  title: 'الغياب',
                  value: '${stats.absentCount}',
                  color: AppColors.error,
                  icon: Icons.cancel_rounded,
                ),
                AttendanceStatCard(
                  title: 'المتأخرون',
                  value: '${stats.lateCount}',
                  color: AppColors.warning,
                  icon: Icons.access_time_filled_rounded,
                ),
                AttendanceStatCard(
                  title: 'معذور',
                  value: '${stats.excusedCount}',
                  color: AppColors.info,
                  icon: Icons.info_rounded,
                ),
              ],
            ),
          ),

          // Action Toolbar: Fast Mark All & Save (Stacked on narrow screens)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: context.screenWidth < 360
                ? Column(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text('تحضير الكل حاضر'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.success,
                          side: const BorderSide(color: AppColors.success),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        onPressed: () => _attendanceCubit.markAll(AttendanceStatus.present),
                      ),
                      const SizedBox(height: AppSpacing.s8),
                      AppButton(
                        text: 'حفظ كشف الحضور',
                        icon: Icons.save_rounded,
                        isLoading: attendanceState.isSaving,
                        onPressed: attendanceState.isSaving
                            ? null
                            : () => _attendanceCubit.saveAttendance(),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: const Text('تحضير الكل حاضر'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.success,
                            side: const BorderSide(color: AppColors.success),
                          ),
                          onPressed: () => _attendanceCubit.markAll(AttendanceStatus.present),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.s12),
                      Expanded(
                        child: AppButton(
                          text: 'حفظ كشف الحضور',
                          icon: Icons.save_rounded,
                          isLoading: attendanceState.isSaving,
                          onPressed: attendanceState.isSaving
                              ? null
                              : () => _attendanceCubit.saveAttendance(),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.s8),

          // Student List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.s16),
              itemCount: students.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
              itemBuilder: (context, index) {
                final student = students[index];
                return _buildStudentAttendanceRow(context, student);
              },
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStudentAttendanceRow(
    BuildContext context,
    StudentAttendanceItem student,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight.withAlpha(40),
                child: Text(
                  student.studentName.isNotEmpty
                      ? student.studentName.characters.first
                      : 'ط',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.s12),

              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (student.phone != null)
                      Text(
                        student.phone!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),

              // Note Button
              IconButton(
                icon: Icon(
                  student.note != null && student.note!.isNotEmpty
                      ? Icons.note_alt_rounded
                      : Icons.note_add_outlined,
                  color: student.note != null && student.note!.isNotEmpty
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 20,
                ),
                tooltip: 'إضافة ملاحظة',
                onPressed: () => _showNoteDialog(context, student),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),

          // Status Selector Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: AttendanceStatus.values.map((status) {
                final isSelected = student.status == status;
                final (selectedBg, selectedFg) = switch (status) {
                  AttendanceStatus.present => (AppColors.success, Colors.white),
                  AttendanceStatus.absent => (AppColors.error, Colors.white),
                  AttendanceStatus.late => (AppColors.warning, Colors.white),
                  AttendanceStatus.excused => (AppColors.info, Colors.white),
                };

                return Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.s8),
                  child: ChoiceChip(
                    label: Text(status.labelAr),
                    selected: isSelected,
                    selectedColor: selectedBg,
                    backgroundColor: AppColors.surfaceVariant,
                    labelStyle: TextStyle(
                      color: isSelected ? selectedFg : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        _attendanceCubit.updateStudentStatus(
                          student.studentId,
                          status,
                        );
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          // Note Display if exists
          if (student.note != null && student.note!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Container(
              padding: const EdgeInsets.all(AppSpacing.s8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sticky_note_2_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.s6),
                  Expanded(
                    child: Text(
                      student.note!,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
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
