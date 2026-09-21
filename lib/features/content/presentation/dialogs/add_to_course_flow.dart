import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/content_entity.dart';
import '../cubit/content_cubit.dart';
import 'lesson_setup_sheet.dart';

/// Two-step flow for adding a video from the Video Library to a course.
///
/// Step 1 — Select Course (radio list of groups)
/// Step 2 — Lesson Setup (LessonSetupSheet)
///
/// Launched from the [VideoLibraryCard] "Add to Course" action.
class AddToCourseFlow extends StatefulWidget {
  final ContentEntity video;

  const AddToCourseFlow({super.key, required this.video});

  static Future<bool> show(BuildContext context,
      {required ContentEntity video}) async {
    final groupsCubit = context.read<GroupsCubit>();
    final contentCubit = context.read<ContentCubit>();

    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: groupsCubit),
          BlocProvider.value(value: contentCubit),
        ],
        child: AddToCourseFlow(video: video),
      ),
    );
    return result == true;
  }

  @override
  State<AddToCourseFlow> createState() => _AddToCourseFlowState();
}

class _AddToCourseFlowState extends State<AddToCourseFlow> {
  GroupEntity? _selectedGroup;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<GroupsCubit>();
    if (cubit.state is! GroupsLoaded) {
      cubit.loadGroups();
    }
  }

  Future<void> _proceedToLessonSetup(GroupEntity group) async {
    if (!mounted) return;
    Navigator.of(context).pop(); // close this dialog

    final contentCubit = context.read<ContentCubit>();

    final saved = await LessonSetupSheet.show(
      context,
      video: widget.video,
      groupId: group.id,
      groupName: group.name,
      defaultPassingScore: group.defaultPassingScore,
      onSave: ({
        required contentId,
        required groupId,
        required lessonTitle,
        required fileId,
        required examId,
        required passingScoreOverride,
      }) async {
        return contentCubit.assignContentToGroups(
          contentId: contentId,
          groupIds: [groupId],
          groupConfigs: [
            {
              'group_id': groupId,
              if (fileId != null) 'file_id': fileId,
              if (examId != null) 'associated_exam_id': examId,
              if (passingScoreOverride != null)
                'passing_score_override': passingScoreOverride,
            }
          ],
        );
      },
    );

    if (saved && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(context.l10n.lessonAddedToCourse(group.name)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusLarge)),
      elevation: 4,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSmall),
                    ),
                    child: const Icon(Icons.school_rounded,
                        color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.selectCourse,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          l10n.selectCourseSubtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ],
              ),

              // Video name badge
              const SizedBox(height: AppSpacing.s16),
              Container(
                padding: const EdgeInsets.all(AppSpacing.s10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_circle_fill_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        widget.video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.s16),
              const Divider(height: 1),

              // Course list
              Flexible(
                child: BlocBuilder<GroupsCubit, GroupsState>(
                  builder: (context, state) {
                    if (state is GroupsLoading) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSpacing.s24),
                        child: Center(child: AppLoadingView()),
                      );
                    }
                    if (state is GroupsLoaded && state.groups.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(AppSpacing.s24),
                        child: AppEmptyView(
                          icon: Icons.school_outlined,
                          message: l10n.noCoursesAvailable,
                          subtitle: l10n.noCoursesAvailableSubtitle,
                        ),
                      );
                    }
                    final groups = state is GroupsLoaded ? state.groups : <GroupEntity>[];
                    return ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.s8),
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        final isSelected = _selectedGroup?.id == group.id;
                        return RadioListTile<String>(
                          value: group.id,
                          groupValue: _selectedGroup?.id,
                          onChanged: (_) =>
                              setState(() => _selectedGroup = group),
                          activeColor: AppColors.primary,
                          title: Text(
                            group.name,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            l10n.nStudentsCount(group.membersCount),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        );
                      },
                    );
                  },
                ),
              ),

              const Divider(height: 1),
              const SizedBox(height: AppSpacing.s16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectedGroup == null
                          ? null
                          : () => _proceedToLessonSetup(_selectedGroup!),
                      child: Text(l10n.lessonSetupTitle),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
