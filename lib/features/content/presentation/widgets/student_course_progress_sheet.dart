import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../cubit/course_progress_cubit.dart';
import '../cubit/course_progress_state.dart';
import 'manual_unlock_sheet.dart';

class StudentCourseProgressSheet extends StatefulWidget {
  final String groupId;
  final String studentId;
  final String studentName;

  const StudentCourseProgressSheet({
    super.key,
    required this.groupId,
    required this.studentId,
    required this.studentName,
  });

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String studentId,
    required String studentName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentCourseProgressSheet(
        groupId: groupId,
        studentId: studentId,
        studentName: studentName,
      ),
    );
  }

  @override
  State<StudentCourseProgressSheet> createState() =>
      _StudentCourseProgressSheetState();
}

class _StudentCourseProgressSheetState
    extends State<StudentCourseProgressSheet> {
  late final CourseProgressCubit _progressCubit;

  @override
  void initState() {
    super.initState();
    _progressCubit = InjectionContainer.createCourseProgressCubit()
      ..loadCourseProgress(
        widget.groupId,
        studentId: widget.studentId,
        isTeacher:
            false, // Force false so teacher sees what student sees (locked/unlocked)
      );
  }

  @override
  void dispose() {
    _progressCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.radiusLarge),
        ),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.s12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${context.l10n.courseProgressTitle} - ${widget.studentName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: BlocProvider.value(
              value: _progressCubit,
              child: BlocBuilder<CourseProgressCubit, CourseProgressState>(
                builder: (context, state) {
                  if (state is CourseProgressLoading) {
                    return const AppLoadingView.list();
                  }
                  if (state is CourseProgressError) {
                    return AppErrorView(
                      message: state.message,
                      onRetry: () => _progressCubit.loadCourseProgress(
                        widget.groupId,
                        studentId: widget.studentId,
                        isTeacher: false,
                      ),
                    );
                  }
                  if (state is CourseProgressLoaded) {
                    final lessons = state.lessons;
                    if (lessons.isEmpty) {
                      return Center(
                        child: Text(
                          context.l10n.noContentYet,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      itemCount: lessons.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.s12),
                      itemBuilder: (context, index) {
                        final lesson = lessons[index];
                        final isLocked = lesson.isLocked;
                        final isCompleted = lesson.isEffectivelyCompleted;

                        return ListTile(
                          tileColor: isLocked
                              ? AppColors.surfaceVariant.withAlpha(50)
                              : AppColors.surfaceVariant,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMedium,
                            ),
                            side: BorderSide(
                              color: isCompleted
                                  ? AppColors.success.withAlpha(100)
                                  : AppColors.border,
                            ),
                          ),
                          leading: Icon(
                            isCompleted
                                ? Icons.check_circle_rounded
                                : isLocked
                                ? Icons.lock_rounded
                                : Icons.play_circle_fill_rounded,
                            color: isCompleted
                                ? AppColors.success
                                : isLocked
                                ? AppColors.textMuted
                                : AppColors.primary,
                          ),
                          title: Text(
                            lesson.title,
                            style: TextStyle(
                              fontWeight: isLocked
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: isLocked
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: isLocked
                              ? Text(
                                  context.l10n.quizGateNotice,
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                          trailing: isLocked
                              ? TextButton(
                                  onPressed: () {
                                    ManualUnlockSheet.show(
                                      context,
                                      groupId: widget.groupId,
                                      studentId: widget.studentId,
                                      contentId: lesson.contentId,
                                      contentTitle: lesson.title,
                                      studentName: widget.studentName,
                                      cubit: _progressCubit,
                                    );
                                  },
                                  child: Text(context.l10n.manualUnlockAction),
                                )
                              : null,
                        );
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
