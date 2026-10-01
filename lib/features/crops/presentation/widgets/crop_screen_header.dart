import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/page_header_actions.dart';
import '../../../../shared/widgets/app_page_header.dart';

class CropScreenHeader extends StatelessWidget {
  const CropScreenHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPageHeader(
      title: 'Crops',
      titleColor: AppColors.primaryText,
      actions: PageHeaderActions(foregroundColor: AppColors.primaryGreen),
    );
  }
}
