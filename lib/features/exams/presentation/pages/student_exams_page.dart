import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/exam_entity.dart';
import '../cubit/exams_cubit.dart';
import '../cubit/exams_state.dart';
import '../widgets/exam_card.dart';
import 'exam_intro_page.dart';

enum StudentExamFilter { all, available, inProgress, completed }

class StudentExamsPage extends StatefulWidget {
  const StudentExamsPage({super.key});

  @override
  State<StudentExamsPage> createState() => _StudentExamsPageState();
}

class _StudentExamsPageState extends State<StudentExamsPage> {
  StudentExamFilter _activeFilter = StudentExamFilter.all;

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  void _loadExams() {
    context.read<ExamsCubit>().loadStudentExams();
  }

  List<ExamEntity> _filterExams(List<ExamEntity> list) {
    switch (_activeFilter) {
      case StudentExamFilter.all:
        return list;
      case StudentExamFilter.available:
        return list.where((e) => !e.hasAttempted || e.canTakeExam).toList();
      case StudentExamFilter.inProgress:
        return list.where((e) => e.hasActiveAttempt).toList();
      case StudentExamFilter.completed:
        return list.where((e) => e.hasAttempted && !e.hasActiveAttempt).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'الرجوع للرئيسية',
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go(AppRouter.studentDashboard);
            }
          },
        ),
        title: const Text('امتحاناتي واختباراتي'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
            onPressed: _loadExams,
          ),
        ],
      ),
      body: BlocBuilder<ExamsCubit, ExamsState>(
        builder: (context, state) {
          if (state is ExamsLoading) {
            return const Center(child: AppLoadingView());
          }

          if (state is ExamsError) {
            return Center(
              child: AppErrorView(
                message: state.message,
                onRetry: _loadExams,
              ),
            );
          }

          if (state is ExamsEmpty) {
            return Center(
              child: AppEmptyView(
                message: state.message,
                subtitle: 'لا توجد امتحانات منشورة لمجموعاتك الدراسية حالياً',
                icon: Icons.quiz_outlined,
              ),
            );
          }

          if (state is StudentExamsLoaded) {
            final filtered = _filterExams(state.exams);

            return Column(
              children: [
                // Filter chips
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s16,
                    vertical: AppSpacing.s8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('الكل', StudentExamFilter.all, state.exams.length),
                        const SizedBox(width: AppSpacing.s8),
                        _buildFilterChip(
                          'المتاحة',
                          StudentExamFilter.available,
                          state.exams.where((e) => !e.hasAttempted || e.canTakeExam).length,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        _buildFilterChip(
                          'قيد الأداء',
                          StudentExamFilter.inProgress,
                          state.exams.where((e) => e.hasActiveAttempt).length,
                        ),
                        const SizedBox(width: AppSpacing.s8),
                        _buildFilterChip(
                          'المكتملة',
                          StudentExamFilter.completed,
                          state.exams.where((e) => e.hasAttempted && !e.hasActiveAttempt).length,
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),

                // Exams List
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: AppEmptyView(
                            message: 'لا توجد نتائج في هذا التصنيف',
                            subtitle: 'جرب التبديل لتصنيف آخر لرؤية الامتحانات',
                            icon: Icons.filter_list_off_outlined,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _loadExams(),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.s16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.s12),
                            itemBuilder: (context, index) {
                              final exam = filtered[index];
                              return ExamCard(
                                exam: exam,
                                isTeacher: false,
                                onTap: () {
                                  Navigator.of(context)
                                      .push<void>(
                                    MaterialPageRoute<void>(
                                      builder: (_) => BlocProvider.value(
                                        value: context.read<ExamsCubit>(),
                                        child: ExamIntroPage(exam: exam),
                                      ),
                                    ),
                                  )
                                      .then((_) {
                                    if (context.mounted) {
                                      _loadExams();
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, StudentExamFilter filter, int count) {
    final isSelected = _activeFilter == filter;
    return ChoiceChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? Colors.white : AppColors.textPrimary,
      ),
      onSelected: (_) {
        setState(() {
          _activeFilter = filter;
        });
      },
    );
  }
}
