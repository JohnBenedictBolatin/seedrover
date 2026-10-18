import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A compact crop-count hero styled like the Dashboard sales card.
class CropOverviewHero extends StatelessWidget {
  const CropOverviewHero({required this.activeCrops, super.key});

  final int activeCrops;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 116),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.heroGradientColors.first,
              AppColors.heroGradientColors.last,
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -48,
              right: -64,
              bottom: -48,
              width: 200,
              child: ExcludeSemantics(
                child: Center(
                  child: Transform.rotate(
                    angle: -.16,
                    child: Container(
                      width: 170,
                      height: 170,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .10),
                        border: Border.all(
                          color: Colors.white,
                          width: 5,
                        ),
                      ),
                      child: Transform.translate(
                        offset: const Offset(0, -6),
                        child: const Icon(
                          Icons.grass_rounded,
                          size: 120,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Active crops',
                          style: AppTypography.sectionHeading.copyWith(
                            color: AppColors.heroSecondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$activeCrops',
                            maxLines: 1,
                            softWrap: false,
                            style: AppTypography.sectionHeading.copyWith(
                              color: Colors.white,
                              fontSize: 30,
                              height: 1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'batches',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.heroMutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 86 + AppSpacing.md),
                ],
              ),
            ),
          ],
        ),
      );
}
