import 'package:flutter/material.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/group_member_entity.dart';

/// Interactive Member Row Card with smooth hover physics & tactile remove action.
class GroupMemberRowCard extends StatefulWidget {
  final GroupMemberEntity member;
  final String groupId;
  final VoidCallback onRemove;
  final void Function(BuildContext context, GroupMemberEntity member)?
      onMemberTap;

  const GroupMemberRowCard({
    super.key,
    required this.member,
    required this.groupId,
    required this.onRemove,
    this.onMemberTap,
  });

  @override
  State<GroupMemberRowCard> createState() => _GroupMemberRowCardState();
}

class _GroupMemberRowCardState extends State<GroupMemberRowCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return MouseRegion(
      cursor: MouseCursor.defer,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () {
          widget.onMemberTap?.call(context, member);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
            border: Border.all(
              color: _isHovered
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.border,
              width: _isHovered ? 1.5 : 1.0,
            ),
            boxShadow: _isHovered
                ? [
                    const BoxShadow(
                      color: Color(0x080F172A),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ]
                : const [],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s16,
            vertical: AppSpacing.s12,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primaryLight.withValues(alpha: 0.18),
                child: Text(
                  member.studentName.isNotEmpty ? member.studentName[0] : 'S',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Tooltip(
                message: context.l10n.removeFromGroupTooltip,
                child: IconButton(
                  icon: const Icon(
                    Icons.person_remove_outlined,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: widget.onRemove,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
