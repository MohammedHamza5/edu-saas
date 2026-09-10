import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../../groups/domain/entities/group_entity.dart';
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../../../groups/presentation/cubit/groups_state.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';

class SendAnnouncementPage extends StatefulWidget {
  final String? initialGroupId;

  const SendAnnouncementPage({super.key, this.initialGroupId});

  @override
  State<SendAnnouncementPage> createState() => _SendAnnouncementPageState();
}

class _SendAnnouncementPageState extends State<SendAnnouncementPage> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _selectedGroupId;

  List<({String label, String title, String body})> _getTemplates(
    BuildContext context,
  ) => [
    (
      label: context.l10n.templateSessionReminderLabel,
      title: context.l10n.templateSessionReminderTitle,
      body: context.l10n.templateSessionReminderBody,
    ),
    (
      label: context.l10n.templateAssignmentReminderLabel,
      title: context.l10n.templateAssignmentReminderTitle,
      body: context.l10n.templateAssignmentReminderBody,
    ),
    (
      label: context.l10n.templateExamAlertLabel,
      title: context.l10n.templateExamAlertTitle,
      body: context.l10n.templateExamAlertBody,
    ),
    (
      label: context.l10n.templateExcellencePraiseLabel,
      title: context.l10n.templateExcellencePraiseTitle,
      body: context.l10n.templateExcellencePraiseBody,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.initialGroupId;
    context.read<GroupsCubit>().loadGroups();
    _titleController.addListener(_onTextChanged);
    _bodyController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _bodyController.removeListener(_onTextChanged);
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _applyTemplate(String title, String body) {
    setState(() {
      _titleController.text = title;
      _bodyController.text = body;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) return;

    context.read<NotificationsCubit>().sendAnnouncement(
      title: title,
      body: body,
      groupId: _selectedGroupId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sendAnnouncementTitle)),
      body: BlocConsumer<NotificationsCubit, NotificationsState>(
        listener: (context, state) {
          if (state is NotificationsLoaded && state.sendSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message ?? context.l10n.announcementSentSuccess),
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.pop();
          } else if (state is NotificationsLoaded &&
              state.message != null &&
              !state.sendSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message!),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final isSending = state is NotificationsLoaded && state.isSending;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: ResponsiveContainer.reading(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Notice Card
                    AppCard(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.05,
                      ),
                      borderColor: AppColors.primaryLight.withValues(
                        alpha: 0.3,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.campaign_rounded,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.instantAcademicAlertTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  context.l10n.instantAcademicAlertDesc,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // Target Audience Dropdown & Audience Details
                    BlocBuilder<GroupsCubit, GroupsState>(
                      builder: (context, groupsState) {
                        final List<GroupEntity> groups =
                            groupsState is GroupsLoaded
                            ? groupsState.groups
                            : <GroupEntity>[];

                        GroupEntity? selectedGroup;
                        if (_selectedGroupId != null && groups.isNotEmpty) {
                          try {
                            selectedGroup = groups.firstWhere(
                              (g) => g.id == _selectedGroupId,
                            );
                          } catch (_) {}
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String?>(
                              value: _selectedGroupId,
                              decoration: InputDecoration(
                                labelText: context.l10n.targetAudienceLabel,
                                prefixIcon: const Icon(
                                  Icons.group_rounded,
                                  color: AppColors.primary,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMedium,
                                  ),
                                ),
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text(
                                    context.l10n.allPlatformStudents,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                ...groups.map((g) {
                                  return DropdownMenuItem<String?>(
                                    value: g.id,
                                    child: Text('${g.name} (${g.level})'),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() {
                                  _selectedGroupId = val;
                                });
                              },
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            // Audience indicator pill
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s10,
                                vertical: AppSpacing.s4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _selectedGroupId == null
                                        ? Icons.public_rounded
                                        : Icons.groups_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: AppSpacing.s6),
                                  Text(
                                    _selectedGroupId == null
                                        ? context.l10n.audienceScopeGeneral
                                        : context.l10n.audienceScopeGroup(
                                            selectedGroup?.name ?? '',
                                            selectedGroup?.membersCount ?? 0,
                                          ),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // Quick Template Starters
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.bolt_rounded,
                              size: 16,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: AppSpacing.s4),
                            Text(
                              context.l10n.quickTemplatesTitle,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s8),
                        Wrap(
                          spacing: AppSpacing.s8,
                          runSpacing: AppSpacing.s8,
                          children: _getTemplates(context).map((tpl) {
                            return ActionChip(
                              avatar: const Icon(
                                Icons.touch_app_rounded,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                tpl.label,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSmall,
                                ),
                              ),
                              onPressed: () =>
                                  _applyTemplate(tpl.title, tpl.body),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // Title Field with Character Counter
                    AppTextField(
                      controller: _titleController,
                      labelText: context.l10n.announcementTitleLabel,
                      hintText: context.l10n.announcementTitleHint,
                      prefixIcon: const Icon(
                        Icons.title_rounded,
                        color: AppColors.primary,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return context.l10n.announcementTitleRequired;
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 4,
                          left: 4,
                          right: 4,
                        ),
                        child: Text(
                          '${_titleController.text.length} / 80',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s12),

                    // Body Field with Character Counter
                    AppTextField(
                      controller: _bodyController,
                      labelText: context.l10n.announcementBodyLabel,
                      hintText: context.l10n.announcementBodyHint,
                      maxLines: 4,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return context.l10n.announcementBodyRequired;
                        }
                        return null;
                      },
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: 4,
                          left: 4,
                          right: 4,
                        ),
                        child: Text(
                          '${_bodyController.text.length} / 500',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // Live Student Preview Card (معاينة حية لما يراه الطالب)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMedium,
                        ),
                        border: Border.all(
                          color: AppColors.primaryLight.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.visibility_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: AppSpacing.s6),
                              Text(
                                context.l10n.liveNotificationPreview,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s10),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.s12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSmall,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.campaign_rounded,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.s10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              _titleController.text
                                                      .trim()
                                                      .isEmpty
                                                  ? context.l10n.previewTitlePlaceholder
                                                  : _titleController.text
                                                        .trim(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    _titleController.text
                                                        .trim()
                                                        .isEmpty
                                                    ? AppColors.textSecondary
                                                    : AppColors.textPrimary,
                                                fontStyle:
                                                    _titleController.text
                                                        .trim()
                                                        .isEmpty
                                                    ? FontStyle.italic
                                                    : FontStyle.normal,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            context.l10n.justNow,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _bodyController.text.trim().isEmpty
                                            ? context.l10n.previewBodyPlaceholder
                                            : _bodyController.text.trim(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              _bodyController.text
                                                  .trim()
                                                  .isEmpty
                                              ? AppColors.textSecondary
                                                    .withValues(alpha: 0.6)
                                              : AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s24),

                    // Submit Button
                    AppButton(
                      text: context.l10n.sendAnnouncementNow,
                      icon: Icons.send_rounded,
                      isLoading: isSending,
                      onPressed: isSending ? null : _submit,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
