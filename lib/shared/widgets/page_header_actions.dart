import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/permission_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../features/authentication/providers/auth_providers.dart';
import '../../features/notifications/providers/notification_providers.dart';

class PageHeaderActions extends ConsumerWidget {
  const PageHeaderActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final canViewNotifications =
        profile?.hasPermission(PermissionKeys.notificationsView) ?? false;
    final canViewProfile =
        profile?.hasPermission(PermissionKeys.profileView) ?? false;
    final unreadCount = canViewNotifications
        ? ref.watch(notificationControllerProvider).unreadCount
        : 0;

    if (!canViewNotifications && !canViewProfile) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canViewNotifications)
          _PageHeaderAction(
            icon: Icons.notifications_none_rounded,
            badgeCount: unreadCount,
            tooltip: 'Notifications',
            onTap: () => context.go(AppRoutes.notifications),
          ),
        if (canViewNotifications && canViewProfile)
          const SizedBox(width: AppSpacing.sm),
        if (canViewProfile)
          _PageHeaderAction(
            icon: Icons.person_outline_rounded,
            tooltip: 'Profile',
            onTap: () => context.go(AppRoutes.profile),
          ),
      ],
    );
  }
}

class _PageHeaderAction extends StatelessWidget {
  const _PageHeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.secondaryBackground,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.inactiveBorder),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    icon,
                    color: AppColors.secondaryText,
                    size: 21,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: 5,
                    top: 4,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 15,
                        minHeight: 15,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: AppColors.secondaryBackground,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 9 ? '9+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
