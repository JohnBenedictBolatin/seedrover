import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class CropPlantImage extends StatelessWidget {
  const CropPlantImage({
    required this.cropName,
    this.size = 48,
    super.key,
  });

  final String cropName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final assetPath = _assetPathFor(cropName);

    if (assetPath == null) {
      return SizedBox.square(
        dimension: size,
        child: Icon(
          Icons.spa_outlined,
          color: AppColors.primaryGreen,
          size: size * 0.72,
        ),
      );
    }

    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.spa_outlined,
          color: AppColors.primaryGreen,
          size: size * 0.72,
        ),
      ),
    );
  }

  String? _assetPathFor(String cropName) {
    final normalizedName = cropName.trim().toLowerCase();

    if (normalizedName.contains('calamansi')) {
      return 'assets/images/crops/calamansi.png';
    }

    if (normalizedName.contains('peanut')) {
      return 'assets/images/crops/peanut.png';
    }

    if (normalizedName.contains('sitaw')) {
      return 'assets/images/crops/sitaw.png';
    }

    return null;
  }
}
