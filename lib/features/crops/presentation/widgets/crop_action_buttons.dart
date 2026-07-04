import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class CropActionButtons extends StatelessWidget {
  const CropActionButtons({
    required this.onWater,
    required this.onFertilize,
    required this.onHarvest,
    required this.onEdit,
    super.key,
  });

  final VoidCallback onWater;
  final VoidCallback onFertilize;
  final VoidCallback onHarvest;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        final spacing = AppSpacing.xs * (columns - 1);
        final buttonWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            _ActionButton(
              width: buttonWidth,
              label: 'Water',
              icon: Icons.water_drop_outlined,
              color: AppColors.information,
              onPressed: onWater,
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
              label: 'Harvest',
              icon: Icons.agriculture_outlined,
              color: AppColors.warning,
              onPressed: onHarvest,
            ),
            _ActionButton(
              width: buttonWidth,
              label: 'Edit',
              icon: Icons.edit_outlined,
              color: AppColors.danger,
              onPressed: onEdit,
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
        icon: Icon(icon, size: 15, color: color),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.cardBackground,
          foregroundColor: color,
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: AppTypography.statusBadge,
        ),
      ),
    );
  }
}
