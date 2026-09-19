import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/notification_entity.dart';

class NotificationTile extends StatefulWidget {
  final NotificationEntity notification;
  final VoidCallback? onTap;

  const NotificationTile({super.key, required this.notification, this.onTap});

  @override
  State<NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<NotificationTile> {
  bool _isHovered = false;

  String _formatTime(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return context.l10n.justNow;
    } else if (diff.inMinutes < 60) {
      return context.l10n.minutesAgo(diff.inMinutes);
    } else if (diff.inHours < 24) {
      return context.l10n.hoursAgo(diff.inHours);
    } else if (diff.inDays < 7) {
      return context.l10n.daysAgo(diff.inDays);
    } else {
      final localeCode = Localizations.localeOf(context).languageCode;
      return DateFormat('yyyy/MM/dd', localeCode).format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !widget.notification.isRead;
    final type = widget.notification.type;

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(0, _isHovered ? -1.5 : 0.0, 0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s12),
            child: AppCard(
              onTap: widget.onTap,
              padding: EdgeInsets.zero,
              backgroundColor: isUnread
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : AppColors.surface,
              borderColor: _isHovered
                  ? (isUnread
                        ? AppColors.primaryLight.withValues(alpha: 0.6)
                        : AppColors.primary.withValues(alpha: 0.3))
                  : (isUnread
                        ? AppColors.primaryLight.withValues(alpha: 0.35)
                        : AppColors.border),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                child: Stack(
                  children: [
                    // Unread Start Accent Bar
                    if (isUnread)
                      PositionedDirectional(
                        top: 0,
                        bottom: 0,
                        start: 0,
                        child: Container(
                          width: 3.5,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadiusDirectional.only(
                              topStart: Radius.circular(
                                AppSpacing.radiusMedium,
                              ),
                              bottomStart: Radius.circular(
                                AppSpacing.radiusMedium,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Main Content
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.s16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type Icon with subtle gradient glow
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  type.color.withValues(
                                    alpha: _isHovered ? 0.20 : 0.12,
                                  ),
                                  type.color.withValues(
                                    alpha: _isHovered ? 0.10 : 0.04,
                                  ),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusSmall,
                              ),
                              border: Border.all(
                                color: type.color.withValues(
                                  alpha: _isHovered ? 0.35 : 0.20,
                                ),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Icon(type.icon, size: 22, color: type.color),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),

                          // Text Content
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Type Label Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.s6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: type.color.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: type.color.withValues(
                                            alpha: 0.25,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        type.localizedLabel(context),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: type.color,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    // Timestamp
                                    Text(
                                      _formatTime(
                                        context,
                                        widget.notification.createdAt,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (isUnread) ...[
                                      const SizedBox(width: AppSpacing.s6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.4),
                                              blurRadius: 4,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.s6),
                                Text(
                                  widget.notification.title,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isUnread
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.s4),
                                Text(
                                  widget.notification.body,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
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
            ),
          ),
        ),
      ),
    );
  }
}
