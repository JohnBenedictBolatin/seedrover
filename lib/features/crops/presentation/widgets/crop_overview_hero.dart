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
              top: 0,
              right: 0,
              bottom: 0,
              width: 144,
              child: ExcludeSemantics(
                child: Center(
                  child: Transform.rotate(
                    angle: -.16,
                    child: Container(
                      width: 108,
                      height: 108,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .06),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .18),
                          width: 5,
                        ),
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        size: 68,
                        color: Colors.white.withValues(alpha: .28),
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
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              fontVariations: const [
                                FontVariation('wght', 700)
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'active crop batches',
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
