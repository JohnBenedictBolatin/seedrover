import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../controllers/rover_control_state.dart';

class PlantingControlPanel extends StatelessWidget {
  const PlantingControlPanel({
    required this.status,
    required this.soilCheckMessage,
    required this.canCheckSoil,
    required this.canStartPlanting,
    required this.isPlantingActive,
    required this.onCheckSoil,
    required this.onStartPlanting,
    required this.onEmergencyStop,
    required this.onCalibration,
    required this.onResume,
    required this.onCancel,
    this.completedDrops = 0,
    this.targetDrops = 0,
    this.pendingReceipts = 0,
    super.key,
  });

  final PlantingStatus status;
  final String soilCheckMessage;
  final bool canCheckSoil;
  final bool canStartPlanting;
  final bool isPlantingActive;
  final VoidCallback onCheckSoil;
  final VoidCallback onStartPlanting;
  final VoidCallback onEmergencyStop;
  final VoidCallback onCalibration;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final int completedDrops;
  final int targetDrops;
  final int pendingReceipts;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      radius: AppRadius.sm,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status.label.toUpperCase(),
            style: AppTypography.statusBadge.copyWith(
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            soilCheckMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.small.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 2),
          if (targetDrops > 0) ...[
            LinearProgressIndicator(
              value: (completedDrops / targetDrops).clamp(0, 1),
              minHeight: 5,
              color: AppColors.primaryGreen,
              backgroundColor: AppColors.inactiveBorder,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (!isPlantingActive) ...[
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Calibration',
                    icon: CupertinoIcons.settings,
                    enabled: canCheckSoil,
                    onPressed: onCalibration,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: _ActionButton(
                    label: status == PlantingStatus.paused
                        ? 'Resume'
                        : 'Configure Row',
                    icon: CupertinoIcons.play_fill,
                    enabled:
                        status == PlantingStatus.paused || canStartPlanting,
                    onPressed: status == PlantingStatus.paused
                        ? onResume
                        : onStartPlanting,
                  ),
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                    child: _ActionButton(
                        label: 'Cancel Row',
                        icon: CupertinoIcons.xmark_circle,
                        enabled: true,
                        onPressed: onCancel)),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                    child: _ActionButton(
                        label: 'Emergency Stop',
                        icon: CupertinoIcons.exclamationmark_triangle_fill,
                        enabled: true,
                        danger: true,
                        onPressed: onEmergencyStop)),
              ],
            ),
          ],
          if (pendingReceipts > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$pendingReceipts planting receipt${pendingReceipts == 1 ? '' : 's'} waiting for internet',
              style: AppTypography.small.copyWith(color: AppColors.warning),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final bool danger;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.primaryGreen;

    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: enabled ? color : null, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        foregroundColor: color,
        side: BorderSide(color: enabled ? color : AppColors.inactiveBorder),
        textStyle: AppTypography.statusBadge.copyWith(fontSize: 10),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 0,
        ),
      ),
    );
  }
}
