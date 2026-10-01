import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../data/models/profile_user_model.dart';
import 'profile_avatar.dart';

class UserManagementCard extends StatelessWidget {
  const UserManagementCard({
    required this.user,
    required this.onView,
    super.key,
  });

  final ProfileUserModel user;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.inactiveBorder),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  name: user.fullName,
                  hasImage: user.hasProfilePicture,
                  imageUrl: user.profileImageUrl,
                  size: 46,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.fullName,
                        style: AppTypography.cardTitle,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(user.username, style: AppTypography.numericCaption),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'View user',
                  onPressed: onView,
                  icon: const Icon(CupertinoIcons.arrow_right),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(user.roleName, style: AppTypography.small),
            StatusBadge(
                label: user.status.label,
                color: accountStatusColor(user.status)),
          ],
        ),
      ),
    );
  }
}

Color accountStatusColor(ProfileAccountStatus status) {
  return switch (status) {
    ProfileAccountStatus.active => AppColors.primaryGreen,
    ProfileAccountStatus.inactive => AppColors.mutedText,
  };
}
