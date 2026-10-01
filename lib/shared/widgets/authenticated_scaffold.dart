import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Shared authenticated shell with a stable, role-aware bottom bar.
/// Detail routes can select their parent destination without changing URLs.
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
    final roverItems =
        items.where((item) => item.label == 'Rover').toList(growable: false);
    final rover = roverItems.isEmpty ? null : roverItems.first;
    final destinations = items.where((item) => item != rover).toList();
    final middle = (destinations.length + 1) ~/ 2;
    final compact = MediaQuery.orientationOf(context) == Orientation.landscape;
    final barHeight = compact ? 66.0 : 78.0;
    final barTop = compact ? 12.0 : 16.0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: child,
      ),
      bottomNavigationBar: showNavigation && items.isNotEmpty
          ? Container(
              color: AppColors.secondaryBackground,
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: barHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: barTop,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.secondaryBackground,
                            border: Border(
                              top: BorderSide(color: AppColors.inactiveBorder),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: barTop,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Row(
                          children: [
                            for (final item in destinations.take(middle))
                              Expanded(
                                child: _BottomNavigationItem(
                                  item: item,
                                  selected: item.location == currentLocation,
                                  onTap: () => context.go(item.location),
                                ),
                              ),
                            if (rover != null)
                              SizedBox(
                                width: 76,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      bottom: compact ? 5 : 7,
                                    ),
                                    child: _NavigationLabel(
                                      label: rover.label,
                                      selected:
                                          rover.location == currentLocation,
                                    ),
                                  ),
                                ),
                              ),
                            for (final item in destinations.skip(middle))
                              Expanded(
                                child: _BottomNavigationItem(
                                  item: item,
                                  selected: item.location == currentLocation,
                                  onTap: () => context.go(item.location),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (rover != null)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: _RoverNavigationButton(
                              item: rover,
                              selected: rover.location == currentLocation,
                              dimension: compact ? 50 : 56,
                              onTap: () => context.go(rover.location),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class NavigationItemData {
  const NavigationItemData({
    required this.label,
    required this.location,
    required this.icon,
    this.selectedIcon,
    this.badgeCount = 0,
  });

  final String label;
  final String location;
  final IconData icon;
  final IconData? selectedIcon;
  final int badgeCount;
}

class _BottomNavigationItem extends StatelessWidget {
  const _BottomNavigationItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavigationItemData item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = selected ? item.selectedIcon ?? item.icon : item.icon;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Badge(
                  isLabelVisible: item.badgeCount > 0,
                  label: Text(
                    item.badgeCount > 9 ? '9+' : '${item.badgeCount}',
                    style: AppTypography.numericCaption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                  child: Container(
                    width: 42,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          selected ? AppColors.sageSurface : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      size: 22,
                      color: selected
                          ? AppColors.secondaryGreen
                          : AppColors.mutedText,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                _NavigationLabel(label: item.label, selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoverNavigationButton extends StatelessWidget {
  const _RoverNavigationButton({
    required this.item,
    required this.selected,
    required this.dimension,
    required this.onTap,
  });

  final NavigationItemData item;
  final bool selected;
  final double dimension;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Material(
        elevation: 3,
        color: AppColors.secondaryBackground,
        shape: CircleBorder(
          side: BorderSide(color: AppColors.primaryGreen, width: 2.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(
            dimension: dimension,
            child: Icon(
              selected ? item.selectedIcon ?? item.icon : item.icon,
              size: dimension * 0.5,
              color: AppColors.secondaryGreen,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationLabel extends StatelessWidget {
  const _NavigationLabel({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.caption.copyWith(
        fontSize: 10,
        height: 1.1,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        color: selected ? AppColors.secondaryGreen : AppColors.mutedText,
        fontVariations: [
          FontVariation('wght', selected ? 600 : 400),
        ],
      ),
    );
  }
}

class NavigationIcons {
  const NavigationIcons._();

  static const dashboard = Icons.space_dashboard_outlined;
  static const rover = Icons.agriculture_outlined;
  static const roverSelected = Icons.agriculture;
  static const crops = Icons.grass_outlined;
  static const stocks = Icons.inventory_2_outlined;
  static const notifications = Icons.notifications_outlined;
  static const profile = Icons.person_outline;
}
