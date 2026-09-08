import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../domain/entities/group_entity.dart';
import '../../domain/entities/group_member_entity.dart';
import '../cubit/groups_cubit.dart';
import '../cubit/groups_state.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  final GroupEntity? initialGroup;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    this.initialGroup,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<GroupsCubit>().loadGroupDetail(widget.groupId);
  }

  void _confirmRemoveMember(String studentId, String studentName) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الاستبعاد'),
        content: Text('هل أنت متأكد من رغبتك في إزالة الطالب "$studentName" من هذه المجموعة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<GroupsCubit>().removeMember(
                    groupId: widget.groupId,
                    studentId: studentId,
                  );
            },
            child: const Text('إزالة الطالب', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupsCubit, GroupsState>(
      builder: (context, state) {
        if (state is GroupsLoading) {
          return const Scaffold(
            body: AppLoadingView(message: 'جاري تحميل تفاصيل المجموعة والأعضاء...'),
          );
        }

        GroupEntity? group = widget.initialGroup;
        final List<GroupMemberEntity> members =
            state is GroupsLoaded ? state.groupMembers : const [];

        if (state is GroupsLoaded && state.selectedGroup != null) {
          group = state.selectedGroup;
        }

        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('تفاصيل المجموعة')),
            body: const Center(child: Text('لم يتم العثور على المجموعة')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () =>
                    context.read<GroupsCubit>().loadGroupDetail(widget.groupId),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Group Overview Card
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              group.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          AppBadge(
                            label: group.level,
                            variant: AppBadgeVariant.active,
                          ),
                        ],
                      ),
                      if (group.description != null &&
                          group.description!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.s12),
                        Text(
                          group.description!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.s16),
                      const Divider(height: 1),
                      const SizedBox(height: AppSpacing.s12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'سياسة المحتوى السابق:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          AppBadge(
                            label: group.isPreviousContentAllowed
                                ? 'متاح للطلاب الجدد (Allow)'
                                : 'محجوب عن الجدد (Deny)',
                            variant: group.isPreviousContentAllowed
                                ? AppBadgeVariant.active
                                : AppBadgeVariant.neutral,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.s24),

                // Members Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'أعضاء المجموعة (${members.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.fact_check_rounded, size: 16),
                      label: const Text('رصد الحضور'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      onPressed: () => context.push(
                        '${AppRouter.teacherAttendance}?groupId=${widget.groupId}',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.s12),

                // Members List
                if (members.isEmpty)
                  const AppEmptyView(
                    message: 'لا يوجد طلاب مضافون في هذه المجموعة حالياً',
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.s8),
                    itemBuilder: (context, index) {
                      final member = members[index];
                      return AppCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s16,
                          vertical: AppSpacing.s12,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.primaryLight.withValues(alpha: 0.3),
                              child: Text(
                                member.studentName.isNotEmpty
                                    ? member.studentName[0]
                                    : 'ط',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.s12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.studentName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (member.studentEmail != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      member.studentEmail!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.person_remove_outlined,
                                color: AppColors.error,
                                size: 20,
                              ),
                              tooltip: 'استبعاد من المجموعة',
                              onPressed: () => _confirmRemoveMember(
                                member.studentId,
                                member.studentName,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
