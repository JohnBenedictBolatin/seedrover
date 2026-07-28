import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_mode_controller.dart';

class AuthenticatedScaffold extends StatelessWidget {
  const AuthenticatedScaffold({
    required this.child,
    required this.currentLocation,
    required this.items,
    super.key,
    this.showNavigation = true,
    this.floatingAction,
  });

  final Widget child;
  final String currentLocation;
  final List<NavigationItemData> items;
  final bool showNavigation;
  final Widget? floatingAction;

  @override
  Widget build(BuildContext context) {
    final compactNavigation =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(
                bottom: showNavigation ? (compactNavigation ? 68 : 88) : 0,
              ),
              child: child,
            ),
            if (showNavigation)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.all(
                    compactNavigation ? AppSpacing.xs : AppSpacing.sm,
                  ),
                  child: FloatingBottomNavigation(
                    currentLocation: currentLocation,
                    items: items,
                    compact: compactNavigation,
                  ),
                ),
              ),
            if (floatingAction != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.only(
                    right: compactNavigation ? AppSpacing.sm : AppSpacing.md,
                    bottom: showNavigation
                        ? (compactNavigation ? 78 : 100)
                        : AppSpacing.md,
                  ),
                  child: floatingAction,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class NavigationItemData {
  const NavigationItemData({
    required this.label,
    required this.location,
    required this.icon,
    this.badgeCount = 0,
  });

  final String label;
  final String location;
  final IconData icon;
  final int badgeCount;
}

class FloatingBottomNavigation extends ConsumerWidget {
  const FloatingBottomNavigation({
    required this.currentLocation,
    required this.items,
    super.key,
    this.compact = false,
  });

  final String currentLocation;
  final List<NavigationItemData> items;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeControllerProvider);
    AppColors.useLightPalette(themeMode == ThemeMode.light);

    return SizedBox(
      width: double.infinity,
      height: compact ? 56 : 70,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          border: Border.all(color: AppColors.inactiveBorder),
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBackground.withOpacity(0.32),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final item in items)
                  Expanded(
                    child: _NavigationButton(
                      item: item,
                      isSelected: currentLocation == item.location,
                      compact: compact,
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

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.item,
    required this.isSelected,
    required this.compact,
  });

  final NavigationItemData item;
  final bool isSelected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.go(item.location),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: compact ? 44 : 56,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              _SelectedGradient(
                isSelected: isSelected,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(item.icon, size: compact ? 22 : 23),
                    if (!compact) ...[
                      const SizedBox(height: 3),
                      Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
              if (item.badgeCount > 0)
                Positioned(
                  right: compact ? 3 : 4,
                  top: compact ? 2 : 3,
                  child: _NavigationBadge(count: item.badgeCount),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavigationBadge extends StatelessWidget {
  const _NavigationBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 9 ? '9+' : count.toString();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.primaryBackground),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.primaryText,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedGradient extends StatelessWidget {
  const _SelectedGradient({
    required this.isSelected,
    required this.child,
  });

  final bool isSelected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isSelected) {
      return IconTheme(
        data: IconThemeData(color: AppColors.primaryText),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: AppColors.primaryText),
          child: child,
        ),
      );
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          colors: [
            AppColors.buttonGradientStart,
            AppColors.buttonGradientEnd,
          ],
        ).createShader(bounds);
      },
      child: IconTheme(
        data: IconThemeData(color: AppColors.primaryText),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: AppColors.primaryText),
          child: child,
        ),
      ),
    );
  }
}

class NavigationIcons {
  const NavigationIcons._();

  static const dashboard = CupertinoIcons.square_grid_2x2;
  static const rover = Icons.settings_outlined;
  static const crops = Icons.spa_outlined;
  static const stocks = CupertinoIcons.cube_box;
  static const notifications = CupertinoIcons.bell;
  static const profile = CupertinoIcons.person;
}
