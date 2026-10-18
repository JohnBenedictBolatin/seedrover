import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class StockOverviewHero extends StatelessWidget {
  const StockOverviewHero({
    required this.totalItems,
    required this.inStockItems,
    required this.needsAttentionItems,
    super.key,
  });

  final int totalItems;
  final int inStockItems;
  final int needsAttentionItems;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 120),
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
              right: -60,
              bottom: -48,
              width: 200,
              child: ExcludeSemantics(
                child: Center(
                  child: Transform.rotate(
                    angle: -.05,
                    child: Container(
                      width: 200,
                      height: 200,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: .10),
                        border: Border.all(color: Colors.white, width: 5),
                      ),
                      child: Transform.translate(
                        offset: const Offset(-6, 2),
                        child: const Icon(
                          Icons.eco_rounded,
                          size: 150,
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
                          'Inventory items',
                          style: AppTypography.sectionHeading.copyWith(
                            color: AppColors.heroSecondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '$totalItems',
                          maxLines: 1,
                          style: AppTypography.sectionHeading.copyWith(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.xs,
                          children: [
                            _HeroCount(label: 'In stock', count: inStockItems),
                            _HeroCount(
                              label: 'Need attention',
                              count: needsAttentionItems,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 84),
                ],
              ),
            ),
          ],
        ),
      );
}
class _HeroCount extends StatelessWidget {
  const _HeroCount({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count',
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              softWrap: true,
              style: AppTypography.caption.copyWith(
                color: AppColors.heroMutedText,
              ),
            ),
          ),
        ],
      );
}
