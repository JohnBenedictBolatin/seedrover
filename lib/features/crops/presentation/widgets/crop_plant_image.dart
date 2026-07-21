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
    super.key,
  });

  final CropModel crop;
  final double size;

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
    return Image.asset(
      'assets/images/crops/${cropKey}_$visualState.png',
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _CropStatePlaceholder(
        cropName: crop.name,
        label: _visualLabelFor(crop),
        size: size,
        color: _stateColorFor(crop),
      ),
    );
  }

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
      CropStatus.needsWater => 'needs_water',
      CropStatus.needsFertilizer => 'needs_fertilizer',
      CropStatus.readyForHarvest => 'harvest_ready',
      CropStatus.harvested => 'harvested',
      CropStatus.healthy => _growthStageKey(crop.growthStage),
    };
  }

  String _growthStageKey(CropGrowthStage stage) {
    return switch (stage) {
      CropGrowthStage.seeded => 'seeded',
      CropGrowthStage.germinating => 'germinating',
      CropGrowthStage.vegetative => 'vegetative',
      CropGrowthStage.flowering => 'flowering',
      CropGrowthStage.fruiting => 'fruiting',
      CropGrowthStage.harvestReady => 'harvest_ready',
      CropGrowthStage.harvested => 'harvested',
    };
  }

  String _visualLabelFor(CropModel crop) {
    return switch (crop.status) {
      CropStatus.needsWater => 'Needs Water',
      CropStatus.needsFertilizer => 'Needs Fertilizer',
      CropStatus.readyForHarvest => 'Harvest Ready',
      CropStatus.harvested => 'Harvested',
      CropStatus.healthy => crop.growthStage.label,
    };
  }

  Color _stateColorFor(CropModel crop) {
    return switch (crop.status) {
      CropStatus.healthy => AppColors.primaryGreen,
      CropStatus.needsWater => AppColors.information,
      CropStatus.needsFertilizer => AppColors.warning,
      CropStatus.readyForHarvest => AppColors.success,
      CropStatus.harvested => AppColors.mutedText,
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border.all(color: color.withOpacity(0.65)),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
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
                style: AppTypography.monoCaption.copyWith(
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
                style: AppTypography.monoCaption.copyWith(
                  color: color,
                  fontSize: size >= 120 ? 11 : 8,
                ),
              ),
            ],
          ],
        ),
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

    if (label == 'Harvest Ready' || label == 'Harvested') {
      return Icons.agriculture_outlined;
    }

    return Icons.spa_outlined;
  }
}
