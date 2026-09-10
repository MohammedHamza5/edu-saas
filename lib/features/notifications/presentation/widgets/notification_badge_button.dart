import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/localized_context_extension.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../cubit/notifications_cubit.dart';
import '../cubit/notifications_state.dart';

class NotificationBadgeButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const NotificationBadgeButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NotificationsCubit, NotificationsState>(
      builder: (context, state) {
        final unreadCount = state is NotificationsLoaded
            ? state.unreadCount
            : 0;

        return RepaintBoundary(
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: context.l10n.notificationsTooltip,
                onPressed:
                    onPressed ??
                    () {
                      context.push(AppRouter.notificationsCenter);
                    },
              ),
              if (unreadCount > 0)
                PositionedDirectional(
                  top: 8,
                  end: 8,
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey(unreadCount),
                    tween: Tween<double>(begin: 0.6, end: 1.0),
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.35),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
