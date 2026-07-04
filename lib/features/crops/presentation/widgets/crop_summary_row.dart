import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';

class CropSummaryRow extends StatelessWidget {
  const CropSummaryRow({
    required this.totalCrops,
    required this.activeCrops,
    required this.harvestReadyCrops,
    super.key,
  });

  final int totalCrops;
  final int activeCrops;
  final int harvestReadyCrops;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 3 : 1;
        final spacing = AppSpacing.md * (columns - 1);
        final tileWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: tileWidth,
              child: _SummaryTile(
                label: 'Total Crops',
                value: totalCrops.toString(),
                icon: Icons.spa_outlined,
                color: AppColors.primaryGreen,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _SummaryTile(
                label: 'Active',
                value: activeCrops.toString(),
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _SummaryTile(
                label: 'Harvest Ready',
                value: harvestReadyCrops.toString(),
                icon: Icons.content_cut,
                color: AppColors.warning,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small,
            ),
          ),
          Text(
            value,
            style: AppTypography.sensorValue.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
