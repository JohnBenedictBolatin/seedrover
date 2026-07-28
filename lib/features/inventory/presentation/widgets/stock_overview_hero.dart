import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class StockOverviewHero extends StatelessWidget {
  const StockOverviewHero({
    required this.inStockItems,
    required this.needsAttentionItems,
    super.key,
    this.imageAsset = 'assets/images/stock_hero.png',
  });

  final int inStockItems;
  final int needsAttentionItems;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 138,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: RadialGradient(
          center: Alignment.bottomCenter,
          radius: 1.25,
          colors: AppColors.heroGradientColors,
        ),
        border: Border.all(color: AppColors.primaryGreen.withOpacity(.34)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _StockStarFieldPainter())),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory overview',
                        style: AppTypography.small.copyWith(
                          color: AppColors.heroSecondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$inStockItems in stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.displayHeading.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$needsAttentionItems need attention',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.monoCaption.copyWith(
                          color: AppColors.heroMutedText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                _StockHeroImage(asset: imageAsset),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StockHeroImage extends StatelessWidget {
  const _StockHeroImage({required this.asset});

  final String? asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: asset == null || asset!.isEmpty
          ? const _StockHeroImageFallback()
          : Image.asset(
              asset!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const _StockHeroImageFallback(),
            ),
    );
  }
}

class _StockHeroImageFallback extends StatelessWidget {
  const _StockHeroImageFallback();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.inventory_2_rounded,
      color: AppColors.heroIconGreen.withOpacity(.82),
      size: 56,
    );
  }
}

class _StockStarFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const stars = <Offset>[
      Offset(.06, .17),
      Offset(.14, .32),
      Offset(.24, .14),
      Offset(.32, .52),
      Offset(.43, .22),
      Offset(.55, .12),
      Offset(.64, .38),
      Offset(.73, .19),
      Offset(.84, .46),
      Offset(.93, .24),
      Offset(.19, .72),
      Offset(.49, .68),
      Offset(.77, .74),
    ];
    final paint = Paint()..color = AppColors.accentGreen.withOpacity(.42);
    for (var index = 0; index < stars.length; index++) {
      final star = stars[index];
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        index.isEven ? 1.1 : .7,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
