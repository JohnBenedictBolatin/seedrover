import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class ConnectionStatusRow extends StatelessWidget {
  const ConnectionStatusRow({
    required this.wifiConnected,
    required this.bluetoothConnected,
    required this.cameraConnected,
    super.key,
  });

  final bool wifiConnected;
  final bool bluetoothConnected;
  final bool cameraConnected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        _ConnectionBadge(
          label: 'Wi-Fi',
          connected: wifiConnected,
          icon: CupertinoIcons.wifi,
        ),
        _ConnectionBadge(
          label: 'Bluetooth',
          connected: bluetoothConnected,
          icon: CupertinoIcons.bluetooth,
        ),
        _ConnectionBadge(
          label: 'Camera',
          connected: cameraConnected,
          icon: CupertinoIcons.camera,
        ),
      ],
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({
    required this.label,
    required this.connected,
    required this.icon,
  });

  final String label;
  final bool connected;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.primaryGreen : AppColors.inactiveBorder;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: color,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              (connected ? '$label Online' : '$label Offline').toUpperCase(),
              style: AppTypography.statusBadge.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
