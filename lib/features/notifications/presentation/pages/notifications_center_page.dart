import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/responsive_container.dart';
import '../../domain/entities/notification_entity.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';
import '../widgets/notification_tile.dart';

class NotificationsCenterPage extends StatefulWidget {
  const NotificationsCenterPage({super.key});

  @override
  State<NotificationsCenterPage> createState() =>
      _NotificationsCenterPageState();
}

class _NotificationsCenterPageState extends State<NotificationsCenterPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<NotificationsCubit>().loadNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNotificationDetails(BuildContext context, NotificationEntity item) {
    final localeCode = Localizations.localeOf(context).languageCode;
    final formattedDate = DateFormat(
      'EEEE، d MMMM yyyy - hh:mm a',
      localeCode,
    ).format(item.createdAt);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.s24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppSpacing.radiusLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.type.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
                    border: Border.all(
                      color: item.type.color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.type.icon, size: 14, color: item.type.color),
                      const SizedBox(width: AppSpacing.s4),
                      Text(
                        item.type.localizedLabel(context),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: item.type.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Text(
                    formattedDate,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.s16),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.s16),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMedium),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                item.body,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.s24),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoading() {
    return const AppLoadingView.list(count: 6, hasBadge: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.notificationsCenterTitle),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              if (state is NotificationsLoaded && state.unreadCount > 0) {
                return TextButton.icon(
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: Text(
                    context.l10n.markAllAsRead,
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                  onPressed: state.isMarkingAll
                      ? null
                      : () =>
                            context.read<NotificationsCubit>().markAllAsRead(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refresh,
            onPressed: () =>
                context.read<NotificationsCubit>().loadNotifications(),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state is NotificationsLoading || state is NotificationsInitial) {
            return _buildSkeletonLoading();
          }

          if (state is NotificationsError) {
            return AppErrorView(
              message: state.message,
              onRetry: () =>
                  context.read<NotificationsCubit>().loadNotifications(),
            );
          }

          if (state is NotificationsLoaded) {
            final filteredItems = state.filteredNotifications;
            final displayedItems = filteredItems.where((item) {
              if (_searchQuery.isEmpty) return true;
              final q = _searchQuery.toLowerCase();
              return item.title.toLowerCase().contains(q) ||
                  item.body.toLowerCase().contains(q);
            }).toList();

            return Center(
              child: ResponsiveContainer(
                maxWidth: 800,
                child: Column(
                  children: [
                    // Search & Filters Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                        vertical: AppSpacing.s12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: context.l10n.searchNotificationsHint,
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                          _searchQuery = '';
                                        });
                                      },
                                    )
                                  : null,
                              isDense: true,
                              filled: true,
                              fillColor: AppColors.surfaceVariant,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.border,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusMedium,
                                ),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.s12,
                                vertical: AppSpacing.s8,
                              ),
                            ),
                            onChanged: (val) {
                              setState(() => _searchQuery = val.trim());
                            },
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          Row(
                            children: [
                              ChoiceChip(
                                label: Text(
                                  context.l10n.allNotificationsFilter(state.notifications.length),
                                ),
                                selected: !state.filterUnreadOnly,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surfaceVariant,
                                labelStyle: TextStyle(
                                  color: !state.filterUnreadOnly
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: !state.filterUnreadOnly
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {
                                  context
                                      .read<NotificationsCubit>()
                                      .toggleUnreadFilter(false);
                                },
                              ),
                              const SizedBox(width: AppSpacing.s8),
                              ChoiceChip(
                                label: Text(
                                  context.l10n.unreadNotificationsFilter(state.unreadCount),
                                ),
                                selected: state.filterUnreadOnly,
                                selectedColor: AppColors.primary,
                                backgroundColor: AppColors.surfaceVariant,
                                labelStyle: TextStyle(
                                  color: state.filterUnreadOnly
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                  fontWeight: state.filterUnreadOnly
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                                onSelected: (_) {
                                  context
                                      .read<NotificationsCubit>()
                                      .toggleUnreadFilter(true);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Notifications List / Empty View
                    Expanded(
                      child: displayedItems.isEmpty
                          ? AppEmptyView(
                              message: _searchQuery.isNotEmpty
                                  ? context.l10n.noNotificationsMatchingSearch
                                  : (state.filterUnreadOnly
                                        ? context.l10n.noUnreadNotifications
                                        : context.l10n.noNotificationsYet),
                              icon: _searchQuery.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : (state.filterUnreadOnly
                                        ? Icons.mark_email_read_outlined
                                        : Icons.notifications_off_outlined),
                              actionText: _searchQuery.isNotEmpty
                                  ? context.l10n.clearSearch
                                  : null,
                              onAction: _searchQuery.isNotEmpty
                                  ? () => setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    })
                                  : null,
                            )
                          : RefreshIndicator(
                              onRefresh: () => context
                                  .read<NotificationsCubit>()
                                  .loadNotifications(),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(AppSpacing.s16),
                                itemCount: displayedItems.length,
                                itemBuilder: (context, index) {
                                  final item = displayedItems[index];
                                  return NotificationTile(
                                    notification: item,
                                    onTap: () {
                                      if (!item.isRead) {
                                        context
                                            .read<NotificationsCubit>()
                                            .markAsRead(item.recipientId);
                                      }
                                      _showNotificationDetails(context, item);
                                    },
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
