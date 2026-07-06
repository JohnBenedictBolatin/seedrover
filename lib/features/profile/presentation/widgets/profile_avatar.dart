import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.name,
    required this.hasImage,
    super.key,
    this.size = 64,
    this.onTap,
  });

  final String name;
  final bool hasImage;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(' ')
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part.substring(0, 1).toUpperCase())
        .join();

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.primaryGreen),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: SizedBox.square(
          dimension: size,
          child: Center(
            child: hasImage
                ? Text(
                    initials.isEmpty ? '?' : initials,
                    style: AppTypography.sectionHeading.copyWith(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : Icon(
                    CupertinoIcons.person,
                    color: AppColors.primaryGreen,
                    size: size * 0.45,
                  ),
          ),
        ),
      ),
    );
  }
}
