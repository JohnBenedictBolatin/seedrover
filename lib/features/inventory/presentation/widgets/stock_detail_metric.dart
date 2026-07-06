import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';

class StockDetailMetric extends StatelessWidget {
  const StockDetailMetric({
    required this.label,
    required this.value,
    required this.icon,
    required this.width,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: AppColors.primaryGreen, size: 14),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: AnimatedTypingText(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              AnimatedMetricText(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.monoSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
