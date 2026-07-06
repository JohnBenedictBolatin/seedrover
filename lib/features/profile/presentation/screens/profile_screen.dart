import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/animated_content.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../controllers/profile_controller.dart';
import '../../data/models/profile_user_model.dart';
import '../../providers/profile_providers.dart';
import '../widgets/profile_action_button.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_detail_tile.dart';
import '../widgets/profile_filter_bar.dart';
import '../widgets/user_management_card.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _roles = [
    'System Administrator',
    'Farm Planting Manager',
    'Farm Inventory Manager',
    'Farm Staff',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);
    final authProfile = ref.watch(authControllerProvider).profile;
    final authController = ref.read(authControllerProvider.notifier);
    final isAdmin = authProfile?.isAdministrator ?? false;

    ref.listen(profileControllerProvider, (previous, next) {
      final message = next.generatedPassword == null
          ? next.successMessage
          : '${next.successMessage} ${next.generatedPassword}';

      if (message != null &&
          (message != previous?.successMessage ||
              next.generatedPassword != previous?.generatedPassword)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        ref.read(profileControllerProvider.notifier).clearMessages();
      }
    });

    if (state.isLoading) {
      return const _ProfileLoadingSkeleton();
    }

    if (state.errorMessage != null) {
      return _ProfileErrorState(
        message: state.errorMessage!,
        onRetry: controller.loadProfile,
      );
    }

    final currentUser = controller.currentUser;

    return RefreshIndicator(
      onRefresh: controller.refreshProfile,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(
            children: [
              Expanded(
                child: AnimatedTypingText(
                  'Profile',
                  style: AppTypography.screenTitle.copyWith(
                    color: AppColors.primaryGreen,
                  ),
                ),
              ),
              _ProfileEditMenu(
                onEditInfo: () => _showEditProfileDialog(
                  context,
                  controller,
                  currentUser,
                ),
                onChangePassword: () => _showChangePasswordDialog(
                  context,
                  controller,
                ),
                onChangePicture: () =>
                    _showProfilePictureSheet(context, controller),
                onLogout: () => _confirmLogout(context, authController),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _ProfileHeader(
            user: currentUser,
            onAvatarTap: () => _showProfilePictureSheet(context, controller),
          ),
          const SizedBox(height: AppSpacing.lg),
          _QuickStats(stats: controller.statsForRole(currentUser.roleName)),
          if (isAdmin) ...[
            const SizedBox(height: AppSpacing.lg),
            _ManageUsersEntry(
              onPressed: () => _showUserManagementDialog(context),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _PersonalInformation(
            user: currentUser,
          ),
          const SizedBox(height: AppSpacing.lg),
          _MyActivity(
            activities: controller.filteredActivities(),
            selectedFilter: state.activityFilter,
            onFilterChanged: controller.updateActivityFilter,
          ),
        ],
      ),
    );
  }

  void _showUserManagementDialog(BuildContext parentContext) {
    showDialog<void>(
      context: parentContext,
      builder: (dialogContext) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(profileControllerProvider);
            final controller = ref.read(profileControllerProvider.notifier);

            return _ProfileStyledDialog(
              title: 'User Management',
              child: SingleChildScrollView(
                child: _UserManagementSection(
                  users: state.filteredUsers,
                  searchQuery: state.searchQuery,
                  selectedFilter: state.userFilter,
                  onSearchChanged: controller.updateSearch,
                  onFilterChanged: controller.updateUserFilter,
                  onClear: () => controller.updateSearch(''),
                  onCreate: () => _showCreateUserDialog(
                    parentContext,
                    controller,
                  ),
                  onView: (user) {
                    Navigator.of(dialogContext).pop();
                    parentContext.push(AppRoutes.userDetailsPath(user.id));
                  },
                  onEdit: (user) => _showEditUserDialog(
                    parentContext,
                    controller,
                    user,
                  ),
                  onResetPassword: (user) => _confirmAction(
                    parentContext,
                    title: 'Reset Password',
                    message:
                        'Reset ${user.fullName} password and prepare a temporary one?',
                    confirmLabel: 'Reset',
                    onConfirm: () => controller.resetPassword(user.id),
                  ),
                  onToggleStatus: (user) => _confirmAction(
                    parentContext,
                    title: user.status == ProfileAccountStatus.active
                        ? 'Deactivate Account'
                        : 'Activate Account',
                    message: 'Update ${user.fullName} account status now?',
                    onConfirm: () {
                      controller.updateUser(
                        user.copyWith(
                          status: user.status == ProfileAccountStatus.active
                              ? ProfileAccountStatus.inactive
                              : ProfileAccountStatus.active,
                        ),
                        successMessage: 'Account status updated.',
                      );
                    },
                  ),
                  onDelete: (user) => _confirmAction(
                    parentContext,
                    title: 'Delete User',
                    message: 'Delete ${user.fullName}? This cannot be undone in mock data.',
                    onConfirm: () => controller.deleteUser(user.id),
                  ),
                  framed: false,
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showProfilePictureSheet(
    BuildContext context,
    ProfileController controller,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.secondaryBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DialogHeader(title: 'Profile Picture'),
              const SizedBox(height: AppSpacing.md),
              ProfileActionButton(
                label: 'Change Profile Picture',
                icon: CupertinoIcons.camera,
                color: AppColors.primaryGreen,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Future<void>.microtask(
                    () => _confirmAction(
                      context,
                      title: 'Change Profile Picture',
                      message: 'Change your profile picture for this mock profile?',
                      confirmLabel: 'Change',
                      onConfirm: controller.changeProfilePicture,
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              ProfileActionButton(
                label: 'Remove Profile Picture',
                icon: CupertinoIcons.delete,
                color: AppColors.danger,
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Future<void>.microtask(
                    () => _confirmAction(
                      context,
                      title: 'Remove Profile Picture',
                      message: 'Remove your current profile picture from this profile?',
                      confirmLabel: 'Remove',
                      onConfirm: controller.removeProfilePicture,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    ProfileController controller,
    ProfileUserModel user,
  ) {
    final fullNameController = TextEditingController(text: user.fullName);
    final contactController = TextEditingController(text: user.contactNumber);

    _showSeedRoverDialog(
      context,
      title: 'Edit Profile',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: fullNameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: contactController,
            decoration: const InputDecoration(labelText: 'Contact Number'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            enabled: false,
            controller: TextEditingController(text: user.username),
            decoration: const InputDecoration(labelText: 'Username'),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            enabled: false,
            controller: TextEditingController(text: user.roleName),
            decoration: const InputDecoration(labelText: 'Assigned Role'),
          ),
        ],
      ),
      onConfirm: () {
        controller.updateCurrentProfile(
          fullName: fullNameController.text,
          contactNumber: contactController.text,
        );
      },
      confirmationMessage: 'Save these profile updates?',
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    ProfileController controller,
  ) {
    _showSeedRoverDialog(
      context,
      title: 'Change Password',
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(decoration: InputDecoration(labelText: 'Current Password')),
          SizedBox(height: AppSpacing.md),
          TextField(decoration: InputDecoration(labelText: 'New Password')),
          SizedBox(height: AppSpacing.md),
          TextField(decoration: InputDecoration(labelText: 'Confirm Password')),
        ],
      ),
      onConfirm: controller.changePassword,
      confirmationMessage: 'Change your account password now?',
    );
  }

  void _showCreateUserDialog(
    BuildContext context,
    ProfileController controller,
  ) {
    final fullNameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final contactController = TextEditingController();
    var roleName = _roles.last;

    _showSeedRoverDialog(
      context,
      title: 'Create User',
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                value: roleName,
                dropdownColor: AppColors.secondaryBackground,
                decoration: const InputDecoration(labelText: 'Assigned Role'),
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
            ],
          );
        },
      ),
      onConfirm: () {
        controller.createUser(
          fullName: fullNameController.text,
          username: usernameController.text,
          email: emailController.text,
          contactNumber: contactController.text,
          roleName: roleName,
        );
      },
      confirmationMessage: 'Create this user account and generate credentials?',
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

    _showSeedRoverDialog(
      context,
      title: 'Edit User',
      child: StatefulBuilder(
        builder: (context, setDialogState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: contactController,
                decoration: const InputDecoration(labelText: 'Contact Number'),
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
                decoration: const InputDecoration(labelText: 'Assigned Role'),
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
                decoration: const InputDecoration(labelText: 'Account Status'),
                items: [
                  for (final item in ProfileAccountStatus.values)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => status = value);
                  }
                },
              ),
            ],
          );
        },
      ),
      onConfirm: () {
        final updatedUser = user.copyWith(
          fullName: fullNameController.text,
          contactNumber: contactController.text,
          roleName: roleName,
          status: status,
        );

        _confirmAction(
          context,
          title: 'Save User Changes',
          message: roleName != user.roleName || status != user.status
              ? 'Save role or status updates for ${user.fullName}?'
              : 'Save updates to ${user.fullName} account?',
          confirmLabel: 'Save',
          onConfirm: () => controller.updateUser(updatedUser),
        );
      },
    );
  }

  void _confirmLogout(
    BuildContext context,
    AuthController authController,
  ) {
    _confirmAction(
      context,
      title: 'Logout',
      message: 'End your SeedRover session for now?',
      confirmLabel: 'Logout',
      onConfirm: authController.signOut,
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
    String confirmLabel = 'Confirm',
  }) {
    _showSeedRoverDialog(
      context,
      title: title,
      child: SeedRoverMascotMessage(
        message: message,
        expression: title.contains('Delete') ||
                title.contains('Deactivate') ||
                title.contains('Logout')
            ? SeedRoverMascotExpression.warning
            : SeedRoverMascotExpression.thinking,
      ),
      confirmLabel: confirmLabel,
      onConfirm: onConfirm,
    );
  }

  void _showSeedRoverDialog(
    BuildContext context, {
    required String title,
    required Widget child,
    required VoidCallback onConfirm,
    String confirmLabel = 'Save',
    String? confirmationMessage,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
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
                  _DialogHeader(title: title),
                  const SizedBox(height: AppSpacing.md),
                  child,
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
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
                            if (confirmationMessage == null) {
                              onConfirm();
                              Navigator.of(dialogContext).pop();
                              return;
                            }

                            _showActionConfirmationDialog(
                              dialogContext,
                              title: 'Confirm Action',
                              message: confirmationMessage,
                              confirmLabel: confirmLabel,
                              onConfirm: () {
                                onConfirm();
                                Navigator.of(dialogContext).pop();
                              },
                            );
                          },
                          icon: const Icon(
                            CupertinoIcons.check_mark,
                            size: 15,
                            color: AppColors.primaryGreen,
                          ),
                          label: Text(confirmLabel),
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
  }

  void _showActionConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required VoidCallback onConfirm,
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
                _DialogHeader(title: title),
                const SizedBox(height: AppSpacing.md),
                SeedRoverMascotMessage(
                  message: message,
                  expression: title.contains('Delete') ||
                          title.contains('Deactivate') ||
                          title.contains('Logout')
                      ? SeedRoverMascotExpression.warning
                      : SeedRoverMascotExpression.thinking,
                ),
                const SizedBox(height: AppSpacing.lg),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      _SeedRoverDialogButton(
                        label: 'Cancel',
                        color: AppColors.primaryText,
                        onPressed: () => Navigator.of(confirmContext).pop(),
                      ),
                      _SeedRoverDialogButton(
                        label: confirmLabel,
                        color: AppColors.primaryGreen,
                        icon: CupertinoIcons.check_mark,
                        onPressed: () {
                          Navigator.of(confirmContext).pop();
                          onConfirm();
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

class _SeedRoverDialogButton extends StatelessWidget {
  const _SeedRoverDialogButton({
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

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.cardTitle.copyWith(color: AppColors.primaryText),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.onAvatarTap,
  });

  final ProfileUserModel user;
  final VoidCallback onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(
            name: user.fullName,
            hasImage: user.hasProfilePicture,
            size: 92,
            onTap: onAvatarTap,
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
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileEditMenu extends StatelessWidget {
  const _ProfileEditMenu({
    required this.onEditInfo,
    required this.onChangePassword,
    required this.onChangePicture,
    required this.onLogout,
  });

  final VoidCallback onEditInfo;
  final VoidCallback onChangePassword;
  final VoidCallback onChangePicture;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Edit profile',
      color: AppColors.secondaryBackground,
      onSelected: (index) {
        switch (index) {
          case 0:
            onEditInfo();
          case 1:
            onChangePassword();
          case 2:
            onChangePicture();
          case 3:
            onLogout();
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem<int>(
            value: 0,
            child: Text('Edit Personal Info', style: AppTypography.body),
          ),
          PopupMenuItem<int>(
            value: 1,
            child: Text('Change Password', style: AppTypography.body),
          ),
          PopupMenuItem<int>(
            value: 2,
            child: Text('Profile Picture', style: AppTypography.body),
          ),
          PopupMenuItem<int>(
            value: 3,
            child: Text('Logout', style: AppTypography.body),
          ),
        ];
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          border: Border.all(color: AppColors.primaryGreen),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.pencil,
                color: AppColors.primaryGreen,
                size: 15,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Edit',
                style: AppTypography.statusBadge.copyWith(
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.stats});

  final List<ProfileStatModel> stats;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    for (var index = 0; index < stats.length; index++) {
      children.add(
        Expanded(
          child: AppCard(
            backgroundColor: AppColors.secondaryBackground,
            borderColor: AppColors.inactiveBorder,
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedTypingText(
                  stats[index].label,
                  style: AppTypography.caption,
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      _statIcon(stats[index].iconKey),
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    AnimatedMetricText(
                      stats[index].value,
                      style: AppTypography.sectionHeading,
                    ),
                  ],
                ),
                AnimatedTypingText(
                  stats[index].context,
                  style: AppTypography.monoCaption,
                ),
              ],
            ),
          ),
        ),
      );

      if (index != stats.length - 1) {
        children.add(const SizedBox(width: AppSpacing.sm));
      }
    }

    return Row(children: children);
  }
}

IconData _statIcon(String iconKey) {
  return switch (iconKey) {
    'users' => CupertinoIcons.person_2,
    'active' => CupertinoIcons.check_mark_circled,
    'pending' => CupertinoIcons.clock,
    'crops' => Icons.spa_outlined,
    'planting' => Icons.grass_outlined,
    'tasks' => CupertinoIcons.list_bullet,
    'inventory' => CupertinoIcons.cube_box,
    'warning' => CupertinoIcons.exclamationmark_triangle,
    'transactions' => CupertinoIcons.arrow_2_circlepath,
    'notifications' => CupertinoIcons.bell,
    _ => CupertinoIcons.chart_bar,
  };
}

class _PersonalInformation extends StatelessWidget {
  const _PersonalInformation({
    required this.user,
  });

  final ProfileUserModel user;

  @override
  Widget build(BuildContext context) {
    final details = [
      ('Full Name', user.fullName, CupertinoIcons.person),
      ('Username', user.username, CupertinoIcons.at),
      ('Email', user.email, CupertinoIcons.mail),
      ('Contact', user.contactNumber, CupertinoIcons.phone),
      ('Role', user.roleName, CupertinoIcons.person_badge_plus),
      ('Joined', _formatDate(user.dateJoined), CupertinoIcons.calendar),
    ];

    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Personal Information', style: AppTypography.cardTitle),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              const columns = 2;
              final width =
                  (constraints.maxWidth - AppSpacing.xs) / columns;

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
                        backgroundColor: AppColors.secondaryBackground,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MyActivity extends StatelessWidget {
  const _MyActivity({
    required this.activities,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final List<ProfileActivityModel> activities;
  final ProfileActivityFilter selectedFilter;
  final ValueChanged<ProfileActivityFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('My Activity', style: AppTypography.cardTitle),
              ),
              ActivityFilterBar(
                selectedFilter: selectedFilter,
                onFilterChanged: onFilterChanged,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (activities.isEmpty)
            Text('No activities found.', style: AppTypography.caption)
          else
            for (final activity in activities) ...[
              _ActivityRow(activity: activity),
              const SizedBox(height: AppSpacing.sm),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final ProfileActivityModel activity;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          CupertinoIcons.clock,
          color: AppColors.primaryGreen,
          size: 18,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(activity.title, style: AppTypography.small),
              Text(activity.description, style: AppTypography.caption),
              Text(
                '${_formatDate(activity.timestamp)} ${_formatTime(activity.timestamp)}',
                style: AppTypography.monoCaption,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ManageUsersEntry extends StatelessWidget {
  const _ManageUsersEntry({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.person_2,
            color: AppColors.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text('Manage Users', style: AppTypography.cardTitle),
          ),
          ProfileActionButton(
            label: 'Manage',
            icon: CupertinoIcons.person_crop_circle_badge_plus,
            color: AppColors.primaryGreen,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

class _ProfileStyledDialog extends StatelessWidget {
  const _ProfileStyledDialog({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxContentHeight = MediaQuery.of(context).size.height * 0.68;

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
            Row(
              children: [
                const Icon(
                  CupertinoIcons.person_2,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.cardTitle.copyWith(
                      color: AppColors.primaryText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(
                    CupertinoIcons.xmark,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserManagementSection extends StatelessWidget {
  const _UserManagementSection({
    required this.users,
    required this.searchQuery,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    required this.onClear,
    required this.onCreate,
    required this.onView,
    required this.onEdit,
    required this.onResetPassword,
    required this.onToggleStatus,
    required this.onDelete,
    this.framed = true,
  });

  final List<ProfileUserModel> users;
  final String searchQuery;
  final ProfileUserFilter selectedFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<ProfileUserFilter> onFilterChanged;
  final VoidCallback onClear;
  final VoidCallback onCreate;
  final ValueChanged<ProfileUserModel> onView;
  final ValueChanged<ProfileUserModel> onEdit;
  final ValueChanged<ProfileUserModel> onResetPassword;
  final ValueChanged<ProfileUserModel> onToggleStatus;
  final ValueChanged<ProfileUserModel> onDelete;
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProfileUserFilterBar(
          searchQuery: searchQuery,
          selectedFilter: selectedFilter,
          onSearchChanged: onSearchChanged,
          onFilterChanged: onFilterChanged,
          onClear: onClear,
          leading: ProfileActionButton(
            label: 'Create',
            icon: CupertinoIcons.person_crop_circle_badge_plus,
            color: AppColors.primaryGreen,
            onPressed: onCreate,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (users.isEmpty)
          Text('No users found.', style: AppTypography.caption)
        else
          for (final user in users) ...[
            UserManagementCard(
              user: user,
              onView: () => onView(user),
              onEdit: () => onEdit(user),
              onResetPassword: () => onResetPassword(user),
              onToggleStatus: () => onToggleStatus(user),
              onDelete: () => onDelete(user),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
      ],
    );

    if (!framed) {
      return content;
    }

    return AppCard(
      backgroundColor: AppColors.secondaryBackground,
      borderColor: AppColors.inactiveBorder,
      child: content,
    );
  }
}

class _ProfileLoadingSkeleton extends StatelessWidget {
  const _ProfileLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        SkeletonLine(widthFactor: 0.32, height: 30),
        SizedBox(height: AppSpacing.xl),
        SkeletonCard(
          children: [
            Row(
              children: [
                SkeletonBlock(height: 64, width: 64),
                SizedBox(width: AppSpacing.md),
                Expanded(child: SkeletonLine(widthFactor: 0.8)),
              ],
            ),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        SkeletonCard(
          children: [
            SkeletonLine(widthFactor: 0.55),
            SizedBox(height: AppSpacing.md),
            SkeletonLine(widthFactor: 0.88),
            SizedBox(height: AppSpacing.sm),
            SkeletonLine(widthFactor: 0.72),
          ],
        ),
        SizedBox(height: AppSpacing.lg),
        SkeletonCard(
          children: [
            SkeletonLine(widthFactor: 0.45),
            SizedBox(height: AppSpacing.md),
            SkeletonBlock(height: 92),
          ],
        ),
      ],
    );
  }
}

class _ProfileErrorState extends StatelessWidget {
  const _ProfileErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: AppColors.warning,
              size: 42,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
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
