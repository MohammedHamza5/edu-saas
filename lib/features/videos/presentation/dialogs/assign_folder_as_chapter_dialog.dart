import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../../domain/entities/video_folder_entity.dart';
import '../cubit/video_bank_cubit.dart';

class AssignFolderAsChapterDialog extends StatefulWidget {
  final VideoFolderEntity folder;

  const AssignFolderAsChapterDialog({
    super.key,
    required this.folder,
  });

  static Future<bool?> show(
    BuildContext context, {
    required VideoFolderEntity folder,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: context.read<VideoBankCubit>()),
          BlocProvider.value(value: context.read<GroupsCubit>()),
        ],
        child: AssignFolderAsChapterDialog(folder: folder),
      ),
    );
  }

  @override
  State<AssignFolderAsChapterDialog> createState() =>
      _AssignFolderAsChapterDialogState();
}

class _AssignFolderAsChapterDialogState
    extends State<AssignFolderAsChapterDialog> {
  late final TextEditingController _titleController;
  String? _selectedGroupId;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.folder.name);
    final groupsState = context.read<GroupsCubit>().state;
    if (groupsState is GroupsLoaded && groupsState.groups.isNotEmpty) {
      _selectedGroupId = groupsState.groups.first.id;
    } else {
      context.read<GroupsCubit>().loadGroups();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    if (_selectedGroupId == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final cubit = context.read<VideoBankCubit>();
    final result = await cubit.assignFolderAsChapter(
      folderId: widget.folder.id,
      groupId: _selectedGroupId!,
      chapterTitle: title,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _errorMessage =
            result.failureOrNull?.message ?? context.l10n.assignFolderAsChapterError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLarge),
      ),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                    padding: const EdgeInsets.all(AppSpacing.s10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                    ),
                    child: const Icon(
                      Icons.auto_stories_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.assignFolderAsChapterTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.folder.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: l10n.cancel,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),

              // Description banner
              Container(
                padding: const EdgeInsets.all(AppSpacing.s12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(15),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.radiusMedium),
                  border: Border.all(
                    color: AppColors.primary.withAlpha(40),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        l10n.assignFolderAsChapterDesc,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s16),

              // Target Course Selector
              Text(
                l10n.selectTargetCourse,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              BlocBuilder<GroupsCubit, GroupsState>(
                builder: (context, state) {
                  List<GroupEntity> groups = [];
                  if (state is GroupsLoaded) {
                    groups = state.groups;
                    if (_selectedGroupId == null && groups.isNotEmpty) {
                      _selectedGroupId = groups.first.id;
                    }
                  }

                  if (groups.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.s12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMedium),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMedium),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedGroupId,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down_rounded),
                        items: groups.map((g) {
                          return DropdownMenuItem<String>(
                            value: g.id,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.school_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: AppSpacing.s8),
                                Expanded(
                                  child: Text(
                                    g.name,
                                    style: const TextStyle(fontSize: 13.5),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() => _selectedGroupId = val);
                                }
                              },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.s16),

              // Chapter Title Input
              Text(
                l10n.chapterTitleLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.s6),
              AppTextField(
                controller: _titleController,
                hintText: l10n.chapterTitleHint,
                enabled: !_isSubmitting,
                prefixIcon: const Icon(
                  Icons.title_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ),

              if (widget.folder.videoCount == 0) ...[
                const SizedBox(height: AppSpacing.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.s10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withAlpha(20),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusMedium),
                    border: Border.all(
                      color: AppColors.warning.withAlpha(60),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(
                          l10n.noVideosInFolderToAssign,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.s12),
                Text(
                  _errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.s24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: AppSpacing.s12),
                  AppButton(
                    text: l10n.assignFolderAsChapterConfirm,
                    icon: Icons.check_rounded,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting || _selectedGroupId == null
                        ? null
                        : _handleSubmit,
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
