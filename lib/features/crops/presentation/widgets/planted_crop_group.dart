import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/crop_model.dart';
import 'crop_card.dart';

class PlantedCropGroup extends StatelessWidget {
  const PlantedCropGroup({
    required this.title,
    required this.crops,
    required this.onCropSelected,
    super.key,
  });

  final String title;
  final List<CropModel> crops;
  final ValueChanged<CropModel> onCropSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.cardTitle.copyWith(
                  color: AppColors.primaryText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var index = 0; index < crops.length; index++) ...[
                SizedBox(
                  width: 230,
                  child: CropCard(
                    crop: crops[index],
                    selected: false,
                    onTap: () => onCropSelected(crops[index]),
                  ),
                ),
                if (index != crops.length - 1)
                  const SizedBox(width: AppSpacing.md),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
