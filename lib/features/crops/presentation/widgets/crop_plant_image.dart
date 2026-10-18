import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/crop_model.dart';

class CropPlantImage extends StatelessWidget {
  const CropPlantImage({
    required this.crop,
    this.size = 48,
    this.zoomToSubject = false,
    super.key,
  });

  final CropModel crop;
  final double size;
  final bool zoomToSubject;

  @override
  Widget build(BuildContext context) {
    final imageUrl = crop.imageUrl;
    final cropKey = _cropKeyFor(crop.name);
    final visualState = _visualStateFor(crop);

    return SizedBox.square(
      dimension: size,
      child: imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _assetFallback(
                  cropKey,
                  visualState,
                ),
              ),
            )
          : _assetFallback(cropKey, visualState),
    );
  }

  Widget _assetFallback(String cropKey, String visualState) {
    final image = Image.asset(
      'assets/images/crops/${cropKey}_$visualState.webp',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        'assets/images/crops/$cropKey.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _CropStatePlaceholder(
          cropName: crop.name,
          label: _visualLabelFor(crop),
          size: size,
          color: _stateColorFor(crop),
        ),
      ),
    );

    if (!zoomToSubject) return image;

    return ClipRect(
      child: Transform.scale(
        scale: _expandedStageScale(visualState),
        child: image,
      ),
    );
  }

  double _expandedStageScale(String stage) => switch (stage) {
        'seeded' || 'seedbed' => 2.2,
        'germinating' => 1.8,
        'nursery_seedling' || 'transplant_review' => 1.55,
        'establishing' || 'juvenile' || 'vegetative' => 1.3,
        _ => 1.0,
      };

  String _cropKeyFor(String cropName) {
    final normalizedName = cropName.trim().toLowerCase();

    if (normalizedName.contains('calamansi')) {
      return 'calamansi';
    }

    if (normalizedName.contains('peanut')) {
      return 'peanut';
    }

    if (normalizedName.contains('sitaw')) {
      return 'sitaw';
    }

    return normalizedName
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _visualStateFor(CropModel crop) {
    return switch (crop.status) {
      CropStatus.needsAttention => _growthStageKey(crop.growthStage),
      CropStatus.readyForHarvest => 'harvest_ready',
      CropStatus.harvested => 'harvested',
      CropStatus.notHarvested => _growthStageKey(crop.growthStage),
      CropStatus.active => _growthStageKey(crop.growthStage),
    };
  }

  String _growthStageKey(CropGrowthStage stage) {
    return switch (stage) {
      CropGrowthStage.seeded => 'seeded',
      CropGrowthStage.seedbed => 'seedbed',
      CropGrowthStage.germinating => 'germinating',
      CropGrowthStage.nurserySeedling => 'nursery_seedling',
      CropGrowthStage.transplantReview => 'transplant_review',
      CropGrowthStage.establishing => 'establishing',
      CropGrowthStage.juvenile => 'juvenile',
      CropGrowthStage.vegetative => 'vegetative',
      CropGrowthStage.trellising => 'trellising',
      CropGrowthStage.flowering => 'flowering',
      CropGrowthStage.podFormation => 'pod_formation',
      CropGrowthStage.pegging => 'pegging',
      CropGrowthStage.podDevelopment => 'pod_development',
      CropGrowthStage.maturityCheck => 'maturity_check',
      CropGrowthStage.firstBearing => 'first_bearing',
      CropGrowthStage.fruiting => 'fruiting',
      CropGrowthStage.harvestReady => 'harvest_ready',
      CropGrowthStage.harvested => 'harvested',
      CropGrowthStage.other => 'unknown',
    };
  }

  String _visualLabelFor(CropModel crop) {
    return switch (crop.status) {
      CropStatus.needsAttention => crop.status.farmerLabel,
      CropStatus.readyForHarvest => crop.status.farmerLabel,
      CropStatus.harvested => crop.status.farmerLabel,
      CropStatus.notHarvested => crop.status.farmerLabel,
      CropStatus.active => crop.farmerGrowthStageLabel,
    };
  }

  Color _stateColorFor(CropModel crop) {
    return switch (crop.status) {
      CropStatus.active => AppColors.mutedText,
      CropStatus.needsAttention => AppColors.warning,
      CropStatus.readyForHarvest => AppColors.success,
      CropStatus.harvested => AppColors.mutedText,
      CropStatus.notHarvested => AppColors.danger,
    };
  }
}

class _CropStatePlaceholder extends StatelessWidget {
  const _CropStatePlaceholder({
    required this.cropName,
    required this.label,
    required this.size,
    required this.color,
  });

  final String cropName;
  final String label;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final showText = size >= 96;
    final iconSize = showText ? size * 0.28 : size * 0.52;

    return Padding(
      padding: EdgeInsets.all(showText ? AppSpacing.sm : AppSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _placeholderIcon,
            color: color,
            size: iconSize,
          ),
          if (showText) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              cropName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.numericCaption.copyWith(
                color: AppColors.primaryText,
                fontSize: size >= 120 ? 12 : 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.numericCaption.copyWith(
                color: color,
                fontSize: size >= 120 ? 11 : 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData get _placeholderIcon {
    if (label == 'Needs Water') {
      return Icons.water_drop_outlined;
    }

    if (label == 'Needs Fertilizer') {
      return Icons.science_outlined;
    }

    if (label == 'Ready to harvest' || label == 'Harvested') {
      return Icons.agriculture_outlined;
    }

    return Icons.spa_outlined;
  }
}
