import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/page_header_actions.dart';

class CropScreenHeader extends StatelessWidget {
  const CropScreenHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AnimatedTypingText(
            'Crops',
            style: AppTypography.screenTitle.copyWith(
              color: AppColors.primaryGreen,
            ),
          ),
        ),
        const PageHeaderActions(),
      ],
    );
  }
}
