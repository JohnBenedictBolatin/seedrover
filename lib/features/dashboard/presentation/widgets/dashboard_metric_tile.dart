import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class DashboardMetricTile extends StatelessWidget {
  const DashboardMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    super.key,
    this.caption,
    this.useMonoText = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? caption;
  final bool useMonoText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: AppSpacing.md),
            Text(
              label,
              style: useMonoText ? AppTypography.monoSmall : AppTypography.small,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: AppTypography.sensorValue.copyWith(color: color),
            ),
            if (caption != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                caption!,
                style: useMonoText
                    ? AppTypography.monoCaption
                    : AppTypography.caption,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
