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
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleStatus,
    required this.onDelete,
    super.key,
  });

  final ProfileUserModel user;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.cardTitle,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(user.username, style: AppTypography.monoCaption),
                    ],
                  ),
                ),
                StatusBadge(
                  label: user.status.label,
                  color: accountStatusColor(user.status),
                ),
                const SizedBox(width: AppSpacing.xs),
                _ModifyMenu(
                  user: user,
                  onView: onView,
                  onEdit: onEdit,
                  onResetPassword: onResetPassword,
                  onToggleStatus: onToggleStatus,
                  onDelete: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(user.roleName, style: AppTypography.caption),
          ],
        ),
      ),
    );
  }
}

class _ModifyMenu extends StatelessWidget {
  const _ModifyMenu({
    required this.user,
    required this.onView,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleStatus,
    required this.onDelete,
  });

  final ProfileUserModel user;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onResetPassword;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ModifyAction(
        label: 'View',
        icon: CupertinoIcons.arrow_right,
        color: AppColors.primaryGreen,
        onSelected: onView,
      ),
      _ModifyAction(
        label: 'Edit',
        icon: CupertinoIcons.pencil,
        color: AppColors.danger,
        onSelected: onEdit,
      ),
      _ModifyAction(
        label: 'Reset',
        icon: CupertinoIcons.lock_rotation,
        color: AppColors.information,
        onSelected: onResetPassword,
      ),
      _ModifyAction(
        label: user.status == ProfileAccountStatus.active
            ? 'Deactivate'
            : 'Activate',
        icon: CupertinoIcons.power,
        color: AppColors.warning,
        onSelected: onToggleStatus,
      ),
      _ModifyAction(
        label: 'Delete',
        icon: CupertinoIcons.delete,
        color: AppColors.danger,
        onSelected: onDelete,
      ),
    ];

    return PopupMenuButton<int>(
      tooltip: 'Modify user',
      color: AppColors.secondaryBackground,
      onSelected: (index) => actions[index].onSelected(),
      itemBuilder: (context) {
        return [
          for (var index = 0; index < actions.length; index++)
            PopupMenuItem<int>(
              value: index,
              child: Row(
                children: [
                  Icon(
                    actions[index].icon,
                    size: 16,
                    color: actions[index].color,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    actions[index].label,
                    style: AppTypography.body.copyWith(
                      color: actions[index].color,
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.inactiveBorder),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.xs),
          child: Icon(
            CupertinoIcons.pencil,
            color: AppColors.primaryText,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _ModifyAction {
  const _ModifyAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onSelected;
}

Color accountStatusColor(ProfileAccountStatus status) {
  return switch (status) {
    ProfileAccountStatus.active => AppColors.primaryGreen,
    ProfileAccountStatus.inactive => AppColors.mutedText,
    ProfileAccountStatus.suspended => AppColors.warning,
  };
}
