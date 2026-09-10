import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../domain/entities/assignment_entity.dart';
import '../cubit/assignments_cubit.dart';
import '../cubit/assignments_state.dart';
import '../../../../core/widgets/teacher_group_filter_bar.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../widgets/assignment_card.dart';
import '../widgets/submission_tile.dart';
import 'grade_submission_page.dart';

class TeacherAssignmentsPage extends StatefulWidget {
  final String? groupId;
  final String? groupName;

  const TeacherAssignmentsPage({
    super.key,
    this.groupId,
    this.groupName,
  });

  @override
  State<TeacherAssignmentsPage> createState() => _TeacherAssignmentsPageState();
}

class _TeacherAssignmentsPageState extends State<TeacherAssignmentsPage> {
  String? _selectedGroupId;
  String? _selectedGroupName;

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.groupId;
    _selectedGroupName = widget.groupName;
    if (_selectedGroupId != null) {
      _loadAssignments();
    }
    try {
      context.read<GroupsCubit>().loadGroups();
    } catch (_) {}
  }

  void _onGroupChanged(GroupEntity group) {
    if (_selectedGroupId == group.id) return;
    setState(() {
      _selectedGroupId = group.id;
      _selectedGroupName = group.name;
    });
    _loadAssignments();
  }

  void _loadAssignments() {
    if (_selectedGroupId != null) {
      context.read<AssignmentsCubit>().loadGroupAssignments(_selectedGroupId!);
    }
  }

  void _showCreateAssignmentDialog() {
    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController();
    final instructionsController = TextEditingController();
    final maxScoreController = TextEditingController(text: '100');
    DateTime? selectedDueDate;
    bool allowLate = false;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.s20,
                right: AppSpacing.s20,
                top: AppSpacing.s20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.s24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'إنشاء واجب جديد',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      AppTextField(
                        controller: titleController,
                        labelText: 'عنوان الواجب *',
                        hintText: 'مثال: تمارين حل معادلات الدرجة الثانية',
                        prefixIcon: const Icon(Icons.title),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'يرجى إدخال عنوان الواجب';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      AppTextField(
                        controller: instructionsController,
                        labelText: 'التعليمات والإرشادات للطلاب',
                        hintText: 'اكتب الأسئلة أو التعليمات المطلوب اتباعها...',
                        maxLines: 3,
                        prefixIcon: const Icon(Icons.notes),
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: maxScoreController,
                              labelText: 'الدرجة القصوى',
                              keyboardType: TextInputType.number,
                              prefixIcon: const Icon(Icons.grade),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'مطلوب';
                                }
                                final numVal = int.tryParse(val.trim());
                                if (numVal == null || numVal <= 0) {
                                  return 'رقم موجب';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final pickedDate = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.now().add(const Duration(days: 3)),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (pickedDate != null && ctx.mounted) {
                                  final pickedTime = await showTimePicker(
                                    context: ctx,
                                    initialTime: const TimeOfDay(hour: 23, minute: 59),
                                  );
                                  if (pickedTime != null) {
                                    setModalState(() {
                                      selectedDueDate = DateTime(
                                        pickedDate.year,
                                        pickedDate.month,
                                        pickedDate.day,
                                        pickedTime.hour,
                                        pickedTime.minute,
                                      );
                                    });
                                  }
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.s12,
                                  vertical: AppSpacing.s16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.border),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.event, size: 20, color: AppColors.primary),
                                    const SizedBox(width: AppSpacing.s8),
                                    Expanded(
                                      child: Text(
                                        selectedDueDate != null
                                            ? '${selectedDueDate!.month}/${selectedDueDate!.day}'
                                            : 'موعد التسليم',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: selectedDueDate != null
                                              ? AppColors.textPrimary
                                              : AppColors.textMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      SwitchListTile(
                        title: const Text(
                          'السماح بالتسليم المتأخر',
                          style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                        ),
                        subtitle: const Text(
                          'يمكن للطلاب إرسال الحل حتى بعد انقضاء الموعد',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                        value: allowLate,
                        activeColor: AppColors.primary,
                        contentPadding: EdgeInsets.zero,
                        onChanged: (val) {
                          setModalState(() {
                            allowLate = val;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.s20),

                      AppButton(
                        text: 'نشر الواجب للطلاب',
                        icon: Icons.send_rounded,
                        onPressed: () async {
                          if (!formKey.currentState!.validate()) return;
                          final title = titleController.text.trim();
                          final instructions = instructionsController.text.trim();
                          final maxScore = int.parse(maxScoreController.text.trim());

                          Navigator.of(ctx).pop();

                          final success = await context.read<AssignmentsCubit>().createAssignment(
                                groupId: _selectedGroupId!,
                                title: title,
                                instructions: instructions.isNotEmpty ? instructions : null,
                                dueAt: selectedDueDate,
                                allowLateSubmission: allowLate,
                                maxScore: maxScore,
                              );

                          if (mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إنشاء الواجب ونشره بنجاح'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSubmissionsSheet(AssignmentEntity assignment) {
    context.read<AssignmentsCubit>().selectAssignmentForTeacher(assignment);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLarge)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollController) {
            return BlocBuilder<AssignmentsCubit, AssignmentsState>(
              builder: (context, state) {
                if (state is! TeacherAssignmentsLoaded) {
                  return const Center(child: AppLoadingView());
                }

                final submissions = state.submissions;
                final isLoading = state.isLoadingSubmissions;

                return Column(
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  assignment.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(ctx).pop(),
                              ),
                            ],
                          ),
                          Text(
                            'التسليمات (${submissions.length}) • تم التصحيح (${assignment.reviewedCount})',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.border),

                    // Submissions List
                    Expanded(
                      child: isLoading
                          ? const Center(child: AppLoadingView())
                          : submissions.isEmpty
                              ? const Center(
                                  child: AppEmptyView(
                                    message: 'لا توجد تسليمات حتى الآن',
                                    subtitle: 'سيظهر هنا الطلاب الذين قاموا بتسليم هذا الواجب',
                                    icon: Icons.assignment_turned_in_outlined,
                                  ),
                                )
                              : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.all(AppSpacing.s16),
                                  itemCount: submissions.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSpacing.s8),
                                  itemBuilder: (context, index) {
                                    final sub = submissions[index];
                                    return SubmissionTile(
                                      submission: sub,
                                      maxScore: assignment.maxScore,
                                      onTap: () {
                                        Navigator.of(ctx).push<void>(
                                          MaterialPageRoute<void>(
                                            builder: (_) => BlocProvider.value(
                                              value: context.read<AssignmentsCubit>(),
                                              child: GradeSubmissionPage(
                                                assignment: assignment,
                                                submission: sub,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'رجوع',
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(AppRouter.teacherDashboard),
        ),
        title: Text(_selectedGroupName != null
            ? 'واجبات: $_selectedGroupName'
            : 'إدارة الواجبات'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadAssignments,
          ),
        ],
      ),
      floatingActionButton: _selectedGroupId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _showCreateAssignmentDialog,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                'إنشاء واجب',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.s16),
        child: Column(
          children: [
            TeacherGroupFilterBar(
              selectedGroupId: _selectedGroupId,
              onGroupChanged: _onGroupChanged,
              onRefresh: _loadAssignments,
            ),
            Expanded(
              child: BlocBuilder<AssignmentsCubit, AssignmentsState>(
                builder: (context, state) {
                  if (state is AssignmentsLoading) {
                    return const Center(child: AppLoadingView());
                  }

                  if (state is AssignmentsError) {
                    return Center(
                      child: AppErrorView(
                        message: state.message,
                        onRetry: _loadAssignments,
                      ),
                    );
                  }

                  if (state is TeacherAssignmentsLoaded) {
                    final assignments = state.assignments;

                    if (assignments.isEmpty) {
                      return Center(
                        child: AppEmptyView(
                          message: 'لا توجد واجبات مضافة لهذه المجموعة',
                          subtitle: 'ابدأ بإنشاء أول واجب للطلاب لمتابعة تسليماتهم وتقييمها',
                          actionText: _selectedGroupId != null ? 'إنشاء أول واجب' : null,
                          onAction: _selectedGroupId == null ? null : _showCreateAssignmentDialog,
                          icon: Icons.assignment_outlined,
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async => _loadAssignments(),
                      child: ListView.separated(
                        itemCount: assignments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s12),
                        itemBuilder: (context, index) {
                          final assignment = assignments[index];
                          return AssignmentCard(
                            assignment: assignment,
                            isTeacher: true,
                            onTap: () => _showSubmissionsSheet(assignment),
                          );
                        },
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
