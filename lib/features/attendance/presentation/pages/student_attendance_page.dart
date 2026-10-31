import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../domain/entities/attendance_entity.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/student_attendance_skeleton.dart';
import '../widgets/student_engagement_view.dart';
import '../widgets/student_physical_attendance_view.dart';

class StudentAttendancePage extends StatefulWidget {
  final String? studentId;
  final AttendanceCubit? attendanceCubit;

  const StudentAttendancePage({
    super.key,
    this.studentId,
    this.attendanceCubit,
  });

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  final ScrollController _scrollController = ScrollController();
  late final AttendanceCubit _attendanceCubit;
  bool _isLocallyCreatedCubit = false;
  String? _resolvedStudentId;
  String? _selectedGroupId;
  final AttendanceStatus? _historyFilter = null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final fromContext =
        widget.attendanceCubit ??
        (() {
          try {
            return context.read<AttendanceCubit>();
          } catch (_) {
            return null;
          }
        })();

    if (fromContext != null) {
      _attendanceCubit = fromContext;
      _isLocallyCreatedCubit = false;
    } else {
      _attendanceCubit = InjectionContainer.createAttendanceCubit();
      _isLocallyCreatedCubit = true;
    }

    final authState = context.read<AuthCubit>().state;
    if (widget.studentId != null) {
      _resolvedStudentId = widget.studentId;
    } else if (authState is AuthAuthenticated) {
      _resolvedStudentId = authState.user.id;
    }

    _loadData();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _attendanceCubit.loadMoreStudentAttendance();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    if (_isLocallyCreatedCubit) {
      _attendanceCubit.close();
    }
    super.dispose();
  }

  void _loadData({bool forceRefresh = false}) {
    if (_resolvedStudentId != null) {
      _attendanceCubit.loadStudentAttendance(
        studentId: _resolvedStudentId!,
        groupId: _selectedGroupId,
        forceRefresh: forceRefresh,
      );
    }
  }

  void _onGroupChanged(String? newGroupId) {
    if (newGroupId == _selectedGroupId) return;
    setState(() {
      _selectedGroupId = newGroupId;
    });
    if (_resolvedStudentId != null) {
      _attendanceCubit.filterStudentByGroup(newGroupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _attendanceCubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: context.l10n.backTooltip,
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go(AppRoutes.studentDashboard);
              }
            },
          ),
          title: Text(context.l10n.studentEngagementPageTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: context.l10n.refreshDashboard,
              onPressed: _loadData,
            ),
          ],
        ),
        body: BlocBuilder<AttendanceCubit, AttendanceState>(
          buildWhen: (prev, curr) => prev != curr,
          builder: (context, state) {
            if (state is AttendanceLoading || state is AttendanceInitial) {
              return const StudentAttendanceSkeleton();
            }

            if (state is AttendanceError) {
              return AppErrorView(message: state.message, onRetry: _loadData);
            }

            if (state is StudentAttendanceLoaded) {
              final summary = state.engagementSummary;

              // If engagement telemetry is loaded, present the Online Engagement Dashboard
              if (summary != null) {
                return StudentEngagementView(
                  summary: summary,
                  scrollController: _scrollController,
                  onRefresh: () async => _loadData(forceRefresh: true),
                  selectedGroupId: _selectedGroupId,
                  onGroupChanged: _onGroupChanged,
                );
              }

              // Fallback for tests or environments with pure physical attendance records
              return StudentPhysicalAttendanceView(
                state: state,
                scrollController: _scrollController,
                onRefresh: () async => _loadData(forceRefresh: true),
                historyFilter: _historyFilter,
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
