import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class CropMaintenanceNote extends StatelessWidget {
  const CropMaintenanceNote({
    required this.note,
    super.key,
  });

  final String note;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: AppSpacing.xs),
          child: Icon(
            CupertinoIcons.check_mark_circled,
            size: 16,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(note, style: AppTypography.body)),
      ],
    );
  }
}
