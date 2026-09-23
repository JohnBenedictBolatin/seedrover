import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class CropOverviewHero extends StatelessWidget {
  const CropOverviewHero({
    required this.activeCrops,
    required this.needsAttention,
    required this.upcomingHarvests,
    super.key,
    this.imageAsset = 'assets/images/mascots/crops_mobile.png',
  });

  final int activeCrops;
  final int needsAttention;
  final int upcomingHarvests;
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
        border:
            Border.all(color: AppColors.primaryGreen.withValues(alpha: .34)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withValues(alpha: .06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _CropStarFieldPainter())),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Crop overview',
                        style: AppTypography.small.copyWith(
                          color: AppColors.heroSecondaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '$activeCrops active batches',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.displayHeading.copyWith(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$needsAttention need attention  •  $upcomingHarvests harvesting soon',
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
                _CropHeroImage(asset: imageAsset),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CropHeroImage extends StatelessWidget {
  const _CropHeroImage({required this.asset});

  final String? asset;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      height: 86,
      child: ClipRect(
        child: asset == null || asset!.isEmpty
            ? const _CropHeroImageFallback()
            : Transform.scale(
                scaleX: 1.18,
                scaleY: 1,
                child: Image.asset(
                  asset!,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const _CropHeroImageFallback(),
                ),
              ),
      ),
    );
  }
}

class _CropHeroImageFallback extends StatelessWidget {
  const _CropHeroImageFallback();

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.eco_rounded,
      color: AppColors.heroIconGreen.withValues(alpha: .82),
      size: 56,
    );
  }
}

class _CropStarFieldPainter extends CustomPainter {
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
    final paint = Paint()..color = AppColors.accentGreen.withValues(alpha: .42);
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
