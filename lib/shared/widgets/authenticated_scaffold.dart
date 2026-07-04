import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class AuthenticatedScaffold extends StatelessWidget {
  const AuthenticatedScaffold({
    required this.child,
    required this.currentLocation,
    required this.items,
    super.key,
    this.showNavigation = true,
  });

  final Widget child;
  final String currentLocation;
  final List<NavigationItemData> items;
  final bool showNavigation;

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
  });

  final String label;
  final String location;
  final IconData icon;
}

class FloatingBottomNavigation extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 56 : 70,
      child: DecoratedBox(
        decoration: BoxDecoration(
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
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground.withOpacity(0.28),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(
                  color: AppColors.primaryText.withOpacity(0.12),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in items)
                        _NavigationButton(
                          item: item,
                          isSelected: currentLocation == item.location,
                          compact: compact,
                        ),
                    ],
                  ),
                ),
              ),
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
          width: compact ? 44 : 52,
          height: compact ? 44 : 52,
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: _SelectedGradient(
            isSelected: isSelected,
            child: Center(
              child: Icon(
                item.icon,
                color: AppColors.primaryText,
                size: compact ? (isSelected ? 26 : 24) : (isSelected ? 30 : 27),
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
        data: const IconThemeData(color: AppColors.primaryText),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: AppColors.primaryText),
          child: child,
        ),
      );
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            AppColors.buttonGradientStart,
            AppColors.buttonGradientEnd,
          ],
        ).createShader(bounds);
      },
      child: IconTheme(
        data: const IconThemeData(color: AppColors.primaryText),
        child: DefaultTextStyle.merge(
          style: const TextStyle(color: AppColors.primaryText),
          child: child,
        ),
      ),
    );
  }
}

class NavigationIcons {
  const NavigationIcons._();

  static const dashboard = CupertinoIcons.square_grid_2x2;
  static const rover = Icons.tire_repair_outlined;
  static const crops = Icons.spa_outlined;
  static const stocks = CupertinoIcons.cube_box;
  static const notifications = CupertinoIcons.bell;
  static const profile = CupertinoIcons.person;
}
