import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/rover_control_model.dart';
import 'rover_status_card.dart';

class RoverStatusGrid extends StatelessWidget {
  const RoverStatusGrid({
    required this.telemetry,
    super.key,
    this.compact = false,
  });

  final RoverControlModel telemetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          _CompactStatusPill(
            label: 'BAT',
            value: '${telemetry.batteryLevel}%',
            icon: CupertinoIcons.battery_100,
            color: AppColors.primaryGreen,
          ),
          _CompactStatusPill(
            label: 'SEED',
            value: '${telemetry.seedLevel}%',
            icon: CupertinoIcons.circle_grid_hex,
            color: AppColors.accentGreen,
          ),
          _CompactStatusPill(
            label: 'WIFI',
            value: telemetry.wifiConnected ? 'ON' : 'OFF',
            icon: CupertinoIcons.wifi,
            color: _connectionColor(telemetry.wifiConnected),
          ),
          _CompactStatusPill(
            label: 'BT',
            value: telemetry.bluetoothConnected ? 'ON' : 'OFF',
            icon: CupertinoIcons.bluetooth,
            color: _connectionColor(telemetry.bluetoothConnected),
          ),
          _CompactStatusPill(
            label: 'CAM',
            value: telemetry.cameraConnected ? 'ON' : 'OFF',
            icon: CupertinoIcons.camera,
            color: _connectionColor(telemetry.cameraConnected),
          ),
        ],
      );
    }

    final cards = [
      RoverStatusCard(
        label: 'Battery',
        value: '${telemetry.batteryLevel}%',
        icon: CupertinoIcons.battery_100,
        color: AppColors.primaryGreen,
      ),
      RoverStatusCard(
        label: 'Seed Level',
        value: '${telemetry.seedLevel}%',
        icon: CupertinoIcons.circle_grid_hex,
        color: AppColors.accentGreen,
      ),
      RoverStatusCard(
        label: 'Wi-Fi',
        value: telemetry.wifiConnected ? 'Online' : 'Offline',
        icon: CupertinoIcons.wifi,
        color: _connectionColor(telemetry.wifiConnected),
      ),
      RoverStatusCard(
        label: 'Bluetooth',
        value: telemetry.bluetoothConnected ? 'Online' : 'Offline',
        icon: CupertinoIcons.bluetooth,
        color: _connectionColor(telemetry.bluetoothConnected),
      ),
      RoverStatusCard(
        label: 'Camera',
        value: telemetry.cameraConnected ? 'Online' : 'Offline',
        icon: CupertinoIcons.camera,
        color: _connectionColor(telemetry.cameraConnected),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 3 : 2;
        final spacing = AppSpacing.md * (columns - 1);
        final tileWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final card in cards) SizedBox(width: tileWidth, child: card),
          ],
        );
      },
    );
  }

  Color _connectionColor(bool connected) {
    return connected ? AppColors.primaryGreen : AppColors.inactiveBorder;
  }
}

class _CompactStatusPill extends StatelessWidget {
  const _CompactStatusPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: AppSpacing.xs),
            Text('$label $value', style: AppTypography.monoCaption),
          ],
        ),
      ),
    );
  }
}
