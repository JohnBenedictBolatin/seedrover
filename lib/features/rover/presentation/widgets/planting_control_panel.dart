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
    required this.canStartPlanting,
    required this.isPlantingActive,
    required this.onResume,
    required this.onCancel,
    required this.onPlantNextRow,
    required this.onRetrySync,
    this.canPlantNextRow = false,
    this.isSyncing = false,
    this.completedDrops = 0,
    this.targetDrops = 0,
    this.pendingReceipts = 0,
    super.key,
  });

  final PlantingStatus status;
  final bool canStartPlanting;
  final bool isPlantingActive;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onPlantNextRow;
  final VoidCallback onRetrySync;
  final bool canPlantNextRow;
  final bool isSyncing;
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
          if (targetDrops > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Planting points', style: AppTypography.small),
                Text(
                  '$completedDrops / $targetDrops',
                  style: AppTypography.small.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
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
          if (status == PlantingStatus.paused) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canStartPlanting ? onResume : null,
                  icon: const Icon(CupertinoIcons.play_fill),
                  label: const Text('Resume run'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(CupertinoIcons.xmark_circle),
                  label: const Text('Cancel run'),
                ),
              ),
            ]),
          ] else if (isPlantingActive) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(CupertinoIcons.xmark_circle),
              label: const Text('Cancel planting run'),
            ),
          ],
          if (pendingReceipts > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isSyncing
                        ? 'UPLOADING PLANTING RECORDS…'
                        : '$pendingReceipts LOCAL RECORD${pendingReceipts == 1 ? '' : 'S'} · NEEDS REVIEW OR SYNC',
                    style:
                        AppTypography.small.copyWith(color: AppColors.warning),
                  ),
                ),
                IconButton(
                  tooltip: 'Retry planting record upload',
                  visualDensity: VisualDensity.compact,
                  onPressed: isSyncing ? null : onRetrySync,
                  icon: const Icon(CupertinoIcons.refresh, size: 18),
                ),
              ],
            ),
          ],
          if (canPlantNextRow) ...[
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: _ActionButton(
                label: 'Plant Next Row',
                icon: CupertinoIcons.arrow_right_circle,
                enabled: true,
                onPressed: onPlantNextRow,
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
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primaryGreen;

    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: enabled ? color : null, size: 18),
      label: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: color,
        side: BorderSide(color: enabled ? color : AppColors.inactiveBorder),
        textStyle: AppTypography.caption,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
    );
  }
}
