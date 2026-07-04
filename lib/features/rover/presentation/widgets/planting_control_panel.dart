import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status.label.toUpperCase(),
            style: AppTypography.statusBadge.copyWith(
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            soilCheckMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.small.copyWith(color: AppColors.secondaryText),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (!isPlantingActive) ...[
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Check Soil',
                    icon: CupertinoIcons.check_mark_circled,
                    enabled: canCheckSoil,
                    onPressed: onCheckSoil,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _ActionButton(
                    label: 'Plant',
                    icon: CupertinoIcons.play_fill,
                    enabled: canStartPlanting,
                    onPressed: onStartPlanting,
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: _ActionButton(
                label: 'Emergency Stop',
                icon: CupertinoIcons.exclamationmark_triangle_fill,
                enabled: true,
                danger: true,
                onPressed: onEmergencyStop,
              ),
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
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: enabled ? color : AppColors.inactiveBorder),
      ),
    );
  }
}
