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
import '../../../groups/presentation/cubit/groups_cubit.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';
import '../widgets/announcement_audience_selector.dart';
import '../widgets/announcement_live_preview_card.dart';
import '../widgets/announcement_quick_templates_bar.dart';

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
                content: Text(
                  state.message ?? context.l10n.announcementSentSuccess,
                ),
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
            child: ResponsiveContainer(
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
                    AnnouncementAudienceSelector(
                      selectedGroupId: _selectedGroupId,
                      onGroupChanged: (val) {
                        setState(() {
                          _selectedGroupId = val;
                        });
                      },
                    ),
                    const SizedBox(height: AppSpacing.s20),

                    // Quick Template Starters
                    AnnouncementQuickTemplatesBar(
                      onApplyTemplate: _applyTemplate,
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
                    AnnouncementLivePreviewCard(
                      title: _titleController.text.trim(),
                      body: _bodyController.text.trim(),
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
