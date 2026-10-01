import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_routes.dart';
import '../../core/constants/permission_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../features/assistant/presentation/widgets/assistant_chat_sheet.dart';
import '../../features/assistant/providers/assistant_providers.dart';
import '../../features/authentication/providers/auth_providers.dart';
import '../../features/notifications/providers/notification_providers.dart';

class PageHeaderActions extends ConsumerWidget {
  const PageHeaderActions({super.key, this.foregroundColor});

  final Color? foregroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final canViewNotifications =
        profile?.hasPermission(PermissionKeys.notificationsView) ?? false;
    final canAskRovie =
        profile?.hasPermission(PermissionKeys.profileView) ?? false;
    final unreadCount = canViewNotifications
        ? ref.watch(notificationControllerProvider).unreadCount
        : 0;

    if (!canViewNotifications && !canAskRovie) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canViewNotifications)
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.go(AppRoutes.notifications),
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: foregroundColor ?? AppColors.primaryGreen,
            ),
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppColors.danger,
              label: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: AppTypography.numericCaption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
              child: const Icon(Icons.notifications_none_rounded),
            ),
          ),
        if (canAskRovie)
          IconButton(
            tooltip: 'Ask Rovie',
            onPressed: () {
              ref.read(assistantControllerProvider.notifier).open();
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                builder: (_) => const AssistantChatSheet(),
              ).whenComplete(
                () => ref.read(assistantControllerProvider.notifier).close(),
              );
            },
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: foregroundColor ?? AppColors.primaryGreen,
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
          ),
      ],
    );
  }
}
