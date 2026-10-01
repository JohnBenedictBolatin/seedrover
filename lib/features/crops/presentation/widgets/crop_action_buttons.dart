import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class CropActionButtons extends StatelessWidget {
  const CropActionButtons({
    required this.onWater,
    required this.onFertilize,
    required this.onFieldCheck,
    required this.onGrowthObservation,
    required this.onTransplant,
    this.onSensorCheck,
    this.onHarvest,
    this.onNotHarvested,
    super.key,
  });

  final VoidCallback onWater;
  final VoidCallback onFertilize;
  final VoidCallback onFieldCheck;
  final VoidCallback onGrowthObservation;
  final VoidCallback onTransplant;
  final VoidCallback? onSensorCheck;
  final VoidCallback? onHarvest;
  final VoidCallback? onNotHarvested;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        final spacing = AppSpacing.sm * (columns - 1);
        final buttonWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _ActionButton(
              width: buttonWidth,
              label: 'Water',
              icon: Icons.water_drop_outlined,
              color: AppColors.information,
              onPressed: onWater,
            ),
            if (onSensorCheck != null)
              _ActionButton(
                width: buttonWidth,
                label: 'Read Sensors',
                icon: Icons.sensors_outlined,
                color: AppColors.information,
                onPressed: onSensorCheck!,
              ),
            _ActionButton(
              width: buttonWidth,
              label: 'Fertilize',
              icon: Icons.science_outlined,
              color: AppColors.primaryGreen,
              onPressed: onFertilize,
            ),
            _ActionButton(
              width: buttonWidth,
              label: 'Check Crop',
              icon: Icons.visibility_outlined,
              color: AppColors.information,
              onPressed: onFieldCheck,
            ),
            _ActionButton(
              width: buttonWidth,
              label: 'Observe Growth',
              icon: Icons.timeline,
              color: AppColors.primaryGreen,
              onPressed: onGrowthObservation,
            ),
            _ActionButton(
              width: buttonWidth,
              label: 'Transplanted',
              icon: Icons.yard_outlined,
              color: AppColors.primaryGreen,
              onPressed: onTransplant,
            ),
            if (onHarvest != null)
              _ActionButton(
                width: buttonWidth,
                label: 'Record Harvest',
                icon: Icons.agriculture_outlined,
                color: AppColors.warning,
                onPressed: onHarvest!,
              ),
            if (onNotHarvested != null)
              _ActionButton(
                width: buttonWidth,
                label: 'Close without harvest',
                icon: Icons.block_outlined,
                color: AppColors.danger,
                onPressed: onNotHarvested!,
              ),
          ],
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.width,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final double width;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.secondaryBackground,
          foregroundColor: AppColors.primaryText,
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          side: BorderSide(color: AppColors.inactiveBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: AppTypography.small.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
