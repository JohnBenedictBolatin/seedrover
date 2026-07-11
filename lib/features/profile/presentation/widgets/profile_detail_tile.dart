import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';

class ProfileDetailTile extends StatelessWidget {
  const ProfileDetailTile({
    required this.label,
    required this.value,
    required this.icon,
    this.backgroundColor,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: AppColors.primaryGreen),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: AnimatedTypingText(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            AnimatedTypingText(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small.copyWith(
                color: AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
