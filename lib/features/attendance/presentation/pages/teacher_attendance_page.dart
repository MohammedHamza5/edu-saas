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
  int _selectedLectureIndex = 0;

  static const List<Map<String, String>> _lectures = [
    {
      'title': 'المحاضرة 1: مراجعة الجبر والنسب والمعادلات',
      'duration': 'ساعتان • 120 دقيقة',
      'date': '2026/09/01',
    },
    {
      'title': 'المحاضرة 2: الهندسة المستوية وحساب المثلثات',
      'duration': 'ساعتان • 115 دقيقة',
      'date': '2026/09/08',
    },
    {
      'title': 'المحاضرة 3: الدوال التربيعية ومتعددات الحدود',
      'duration': 'ساعتان • 125 دقيقة',
      'date': '2026/09/15',
    },
    {
      'title': 'المحاضرة 4: الإحصاء وتحليل البيانات والاحتمالات',
      'duration': 'ساعتان • 110 دقيقة',
      'date': '2026/09/22',
    },
    {
      'title': 'المحاضرة 5: تطبيقات الدوال الأسية والجذور',
      'duration': 'ساعتان • 130 دقيقة',
      'date': '2026/09/29',
    },
    {
      'title': 'المحاضرة 6: المتتاليات والمتسلسلات والأولمبياد',
      'duration': 'ساعتان • 120 دقيقة',
      'date': '2026/10/06',
    },
  ];

  void _onLectureChanged(int newIndex) {
    if (newIndex < 0 || newIndex >= _lectures.length) return;
    setState(() {
      _selectedLectureIndex = newIndex;
      final parts = _lectures[newIndex]['date']!.split('/');
      _selectedDate = DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    });
    _loadAttendance();
  }

  void _prevLecture() => _onLectureChanged(_selectedLectureIndex - 1);
  void _nextLecture() => _onLectureChanged(_selectedLectureIndex + 1);

  @override
  void initState() {
    super.initState();
    _attendanceCubit =
        widget.attendanceCubit ?? InjectionContainer.createAttendanceCubit();
    _selectedGroupId = widget.initialGroupId;

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

  void _showNoteDialog(BuildContext context, StudentAttendanceItem student) {
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
              child: const Text(
                'حفظ الملاحظة',
                style: TextStyle(color: Colors.white),
              ),
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
                    const Text(
                      'رصد الحضور والغياب',
                      style: TextStyle(
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
                      child: const Text(
                        '🎥 متابعة المحاضرات المسجلة',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'رصد إتمام ومشاهدة الطلاب للمحاضرات المسجلة ونسب الالتزام الأكاديمي',
                  style: TextStyle(
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
            tooltip: 'تحديث كشف المشاهدات',
            onPressed: _loadAttendance,
          ),
        ],
      ),
    );
  }

  void _showLecturePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.video_library_rounded, color: AppColors.primary, size: 22),
                    SizedBox(width: AppSpacing.s8),
                    Text(
                      'اختر المحاضرة المسجلة',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _lectures.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final lec = _lectures[i];
                      final isSelected = i == _selectedLectureIndex;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                        ),
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: isSelected ? AppColors.primary : AppColors.surfaceVariant,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        title: Text(
                          lec['title']!,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${lec['duration']} • نُشرت: ${lec['date']}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20)
                            : null,
                        onTap: () {
                          Navigator.of(modalCtx).pop();
                          _onLectureChanged(i);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderBar(BuildContext context, String formattedDate) {
    final isCompact = context.screenWidth < 600;
    final currentLecture = _lectures[_selectedLectureIndex];

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
              labelText: 'المجموعة الدراسية',
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

    final lectureSelectorSection = Container(
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
            tooltip: 'المحاضرة السابقة',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: _selectedLectureIndex > 0 ? _prevLecture : null,
          ),
          Expanded(
            child: InkWell(
              onTap: () => _showLecturePicker(context),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.s6,
                  horizontal: AppSpacing.s4,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_circle_filled_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentLecture['title']!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${currentLecture['duration']} • ${currentLecture['date']}',
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
            tooltip: 'المحاضرة التالية',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onPressed: _selectedLectureIndex < _lectures.length - 1 ? _nextLecture : null,
          ),
          IconButton(
            icon: const Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            tooltip: 'اختيار تاريخ محدد',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 34),
            onPressed: () => _selectDate(context),
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
                lectureSelectorSection,
              ],
            )
          : Row(
              children: [
                Expanded(flex: 3, child: groupSelector),
                const SizedBox(width: AppSpacing.s12),
                Expanded(flex: 4, child: lectureSelectorSection),
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
        message:
            'اختر مجموعة دراسية\nيرجى اختيار مجموعة من القائمة بالأعلى لعرض الطلاب ورصد الحضور.',
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
        onRetry: _loadAttendance,
      );
    }

    if (attendanceState is TeacherAttendanceLoaded) {
      final students = attendanceState.students;
      if (students.isEmpty) {
        return const AppEmptyView(
          message:
              'لا يوجد طلاب في هذه المجموعة\nلم يتم إضافة أي طالب نشط إلى هذه المجموعة بعد.',
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
                  title: 'حضروا المحاضرة',
                  value: '${stats.presentCount}',
                  subtitle: 'أتموا المشاهدة (${stats.totalSessions} طلاب)',
                  color: AppColors.success,
                  icon: Icons.check_circle_rounded,
                ),
                AttendanceStatCard(
                  title: 'لم يشاهدوا بعد',
                  value: '${stats.absentCount}',
                  subtitle: 'غائب عن المحاضرة',
                  color: AppColors.error,
                  icon: Icons.cancel_rounded,
                ),
                AttendanceStatCard(
                  title: 'قيد المشاهدة',
                  value: '${stats.lateCount}',
                  subtitle: 'مشاهدة جزئية',
                  color: AppColors.warning,
                  icon: Icons.play_circle_filled_rounded,
                ),
                AttendanceStatCard(
                  title: 'نسبة الحضور',
                  value: '${stats.attendancePercentage.toStringAsFixed(0)}%',
                  subtitle: 'معدل التزام المجموعة',
                  color: AppColors.primary,
                  icon: Icons.analytics_rounded,
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
                          side: BorderSide(
                            color: AppColors.success.withValues(alpha: 0.6),
                          ),
                          backgroundColor: AppColors.success.withValues(
                            alpha: 0.05,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                          ),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        onPressed: () =>
                            _attendanceCubit.markAll(AttendanceStatus.present),
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
                            side: BorderSide(
                              color: AppColors.success.withValues(alpha: 0.6),
                            ),
                            backgroundColor: AppColors.success.withValues(
                              alpha: 0.05,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusMedium,
                              ),
                            ),
                            minimumSize: const Size(0, 44),
                          ),
                          onPressed: () => _attendanceCubit.markAll(
                            AttendanceStatus.present,
                          ),
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
          const SizedBox(height: AppSpacing.s12),

          // Live Search & Status Filters Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'بحث سريع باسم الطالب أو رقم الهاتف...',
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
                        label: Text('الكل (${students.length})'),
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
                        label: Text('حاضر (${stats.presentCount})'),
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
                        label: Text('غائب (${stats.absentCount})'),
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
                      const SizedBox(width: AppSpacing.s8),
                      FilterChip(
                        label: Text('قيد المشاهدة (${stats.lateCount})'),
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
                        label: Text('معذور (${stats.excusedCount})'),
                        selected: _statusFilter == AttendanceStatus.excused,
                        selectedColor: AppColors.info.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.info,
                        labelStyle: TextStyle(
                          color: _statusFilter == AttendanceStatus.excused
                              ? AppColors.info
                              : AppColors.textPrimary,
                          fontWeight: _statusFilter == AttendanceStatus.excused
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) => setState(
                          () => _statusFilter =
                              _statusFilter == AttendanceStatus.excused
                              ? null
                              : AttendanceStatus.excused,
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
                    message: 'لا يوجد طلاب يطابقون خيارات البحث أو التصفية',
                    actionText: 'إعادة ضبط الفلاتر',
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s8),
                  Container(
                    width: 40,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
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
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceVariant,
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
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 80,
                          height: 10,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
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
