import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'seedrover_mascot.dart';

/// A compact, purposeful Rovie panel for welcome, briefing, and feedback.
class RovieScene extends StatelessWidget {
  const RovieScene({
    required this.title,
    required this.message,
    this.expression = SeedRoverMascotExpression.thinking,
    this.size = 64,
    this.backgroundColor,
    this.backgroundGradient,
    super.key,
  });

  final String title;
  final String message;
  final SeedRoverMascotExpression expression;
  final double size;
  final Color? backgroundColor;
  final Gradient? backgroundGradient;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
        ),
        decoration: BoxDecoration(
          color: backgroundGradient == null
              ? backgroundColor ?? AppColors.sageSurface
              : null,
          gradient: backgroundGradient,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTypography.sectionHeading.copyWith(
                      color: backgroundGradient == null
                          ? AppColors.primaryText
                          : AppColors.heroPrimaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: AppTypography.small.copyWith(
                      color: backgroundGradient == null
                          ? AppColors.secondaryText
                          : AppColors.heroSecondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SeedRoverMascot(expression: expression, size: size),
          ],
        ),
      );
}
