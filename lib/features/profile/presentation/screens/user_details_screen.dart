import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../controllers/profile_controller.dart';
import '../../data/models/profile_user_model.dart';
import '../../providers/profile_providers.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_detail_tile.dart';
import '../widgets/user_management_card.dart';

class UserDetailsScreen extends ConsumerWidget {
  const UserDetailsScreen({
    required this.userId,
    super.key,
  });

  static const _roles = [
    'System Administrator',
    'Farm Planting Manager',
    'Farm Inventory Manager',
    'Farm Staff',
  ];

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(profileControllerProvider.notifier);
    final user = controller.userById(userId);

    if (user == null) {
      return Center(
        child: Text('User not found.', style: AppTypography.body),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Back',
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }

                context.go(AppRoutes.profile);
              },
              icon: const Icon(
                CupertinoIcons.arrow_left,
                color: AppColors.primaryGreen,
              ),
            ),
            Expanded(
              child: Text(
                'User Details',
                style: AppTypography.sectionHeading.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          backgroundColor: AppColors.secondaryBackground,
          borderColor: AppColors.inactiveBorder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfileAvatar(
                    name: user.fullName,
                    hasImage: user.hasProfilePicture,
                    imageUrl: user.profileImageUrl,
                    size: 72,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.fullName, style: AppTypography.sectionHeading),
                        const SizedBox(height: AppSpacing.xs),
                        Text(user.username, style: AppTypography.monoCaption),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            StatusBadge(label: user.roleName),
                            StatusBadge(
                              label: user.status.label,
                              color: accountStatusColor(user.status),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _UserDetailGrid(user: user),
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _showEditUserDialog(
                    context,
                    controller,
                    user,
                  ),
                  icon: const Icon(
                    CupertinoIcons.pencil,
                    color: AppColors.danger,
                    size: 15,
                  ),
                  label: const Text('Edit User'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _RecentActivities(activities: controller.filteredActivities()),
      ],
    );
  }

  void _showEditUserDialog(
    BuildContext context,
    ProfileController controller,
    ProfileUserModel user,
  ) {
    final fullNameController = TextEditingController(text: user.fullName);
    final contactController = TextEditingController(text: user.contactNumber);
    var roleName = user.roleName;
    var status = user.status;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(AppSpacing.lg),
              child: AppCard(
                backgroundColor: AppColors.secondaryBackground,
                borderColor: AppColors.inactiveBorder,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Edit User', style: AppTypography.cardTitle),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: fullNameController,
                        decoration: const InputDecoration(labelText: 'Full Name'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: contactController,
                        decoration:
                            const InputDecoration(labelText: 'Contact Number'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        enabled: false,
                        controller: TextEditingController(text: user.username),
                        decoration: const InputDecoration(labelText: 'Username'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        value: roleName,
                        dropdownColor: AppColors.secondaryBackground,
                        decoration:
                            const InputDecoration(labelText: 'Assigned Role'),
                        items: [
                          for (final role in _roles)
                            DropdownMenuItem(value: role, child: Text(role)),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => roleName = value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<ProfileAccountStatus>(
                        value: status,
                        dropdownColor: AppColors.secondaryBackground,
                        decoration:
                            const InputDecoration(labelText: 'Account Status'),
                        items: [
                          for (final item in ProfileAccountStatus.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => status = value);
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryText,
                                side: const BorderSide(
                                  color: AppColors.primaryText,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                              ),
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Cancel'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () {
                                _confirmUserDetailsAction(
                                  context,
                                  title: 'Save User Changes',
                                  message:
                                      'Save updates to ${user.fullName} account?',
                                  confirmLabel: 'Save',
                                  onConfirm: () async {
                                    await controller.updateUser(
                                      user.copyWith(
                                        fullName: fullNameController.text,
                                        contactNumber: contactController.text,
                                        roleName: roleName,
                                        status: status,
                                      ),
                                    );
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                              icon: const Icon(
                                CupertinoIcons.check_mark,
                                color: AppColors.primaryGreen,
                                size: 15,
                              ),
                              label: const Text('Save'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primaryGreen,
                                side: const BorderSide(
                                  color: AppColors.primaryGreen,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.sm,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmUserDetailsAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (confirmContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(AppSpacing.lg),
          child: AppCard(
            backgroundColor: AppColors.secondaryBackground,
            borderColor: AppColors.inactiveBorder,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.cardTitle.copyWith(
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SeedRoverMascotMessage(
                  message: message,
                  expression: SeedRoverMascotExpression.thinking,
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _UserDetailsDialogButton(
                        label: 'Cancel',
                        color: AppColors.primaryText,
                        onPressed: () => Navigator.of(confirmContext).pop(),
                      ),
                      _UserDetailsDialogButton(
                        label: confirmLabel,
                        color: AppColors.primaryGreen,
                        icon: CupertinoIcons.check_mark,
                        onPressed: () async {
                          Navigator.of(confirmContext).pop();
                          await onConfirm();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _UserDetailsDialogButton extends StatelessWidget {
  const _UserDetailsDialogButton({
    required this.label,
    required this.color,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = OutlinedButton.styleFrom(
      foregroundColor: color,
      side: BorderSide(color: color),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );

    if (icon == null) {
      return OutlinedButton(
        style: style,
        onPressed: onPressed,
        child: Text(label),
      );
    }

    return OutlinedButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(icon, size: 15, color: color),
      label: Text(label),
    );
  }
}

class _UserDetailGrid extends StatelessWidget {
  const _UserDetailGrid({required this.user});

  final ProfileUserModel user;

  @override
  Widget build(BuildContext context) {
    final details = [
      ('Employee ID', user.employeeId, CupertinoIcons.number),
      ('Email', user.email, CupertinoIcons.mail),
      ('Contact', user.contactNumber, CupertinoIcons.phone),
      ('Role', user.roleName, CupertinoIcons.person_badge_plus),
      ('Joined', _formatDate(user.dateJoined), CupertinoIcons.calendar),
      ('Status', user.status.label, CupertinoIcons.check_mark_circled),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        final width = (constraints.maxWidth - AppSpacing.xs) / columns;

        return Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final detail in details)
              SizedBox(
                width: width,
                child: ProfileDetailTile(
                  label: detail.$1,
                  value: detail.$2,
                  icon: detail.$3,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RecentActivities extends StatelessWidget {
  const _RecentActivities({required this.activities});

  final List<ProfileActivityModel> activities;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Activities', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.md),
          if (activities.isEmpty)
            Text('No activities found.', style: AppTypography.caption)
          else
            for (final activity in activities) ...[
              Text(activity.title, style: AppTypography.small),
              Text(activity.description, style: AppTypography.caption),
              Text(
                '${_formatDate(activity.timestamp)} ${_formatTime(activity.timestamp)}',
                style: AppTypography.monoCaption,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return '${date.month}/${date.day}/${date.year.toString().substring(2)}';
}

String _formatTime(DateTime date) {
  final hour = date.hour > 12
      ? date.hour - 12
      : date.hour == 0
          ? 12
          : date.hour;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $suffix';
}
