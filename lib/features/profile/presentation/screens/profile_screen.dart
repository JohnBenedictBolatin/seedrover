import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/theme_mode_controller.dart';
import '../../../../shared/models/action_outcome.dart';
import '../../../../shared/widgets/action_confirmation.dart';
import '../../../../shared/widgets/app_page_header.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../authentication/data/models/auth_profile_model.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../../crops/data/repositories/crop_repository.dart';
import '../../../rover/providers/rover_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    final themeController = ref.read(themeModeControllerProvider.notifier);
    final profile = authState.profile;

    if (authState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (profile == null) {
      return const Center(child: Text('Account information unavailable.'));
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        const AppPageHeader(title: 'Account'),
        const SizedBox(height: AppSpacing.md),
        _ProfileHeader(profile: profile),
        const SizedBox(height: AppSpacing.lg),
        _AccountGroup(
          title: 'Appearance',
          child: SwitchListTile(
            title: const Text('Dark appearance'),
            subtitle: const Text('Use darker surfaces in low light'),
            value: themeMode == ThemeMode.dark,
            onChanged: (enabled) => themeController.setLightMode(!enabled),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _confirmLogout(context, ref),
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final AuthProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile.fullName,
              style: AppTypography.sectionHeading.copyWith(
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                StatusBadge(
                  label: profile.roleName,
                  color: Colors.white,
                ),
                StatusBadge(
                  label: profile.isActive ? 'Active' : 'Inactive',
                  color: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppTypography.sectionHeading),
            const SizedBox(height: AppSpacing.sm),
            Card(margin: EdgeInsets.zero, child: child),
          ],
        ),
      );
}

Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
  String pending;
  try {
    final drafts = await ref.read(cropRepositoryProvider).getCareDrafts();
    final receipts =
        await ref.read(plantingReceiptRepositoryProvider).loadPending();
    final count = drafts.length + receipts.length;
    pending = count == 0
        ? 'No pending local crop or planting records were found.'
        : '$count local record${count == 1 ? '' : 's'} still need synchronization or review. They remain on this phone for this account.';
  } catch (_) {
    pending =
        'Pending local work could not be checked. Existing account records will remain on this phone.';
  }

  if (!context.mounted) return;

  await showActionConfirmation(
    context,
    title: 'Sign out?',
    message: pending,
    actionLabel: 'Sign out',
    onConfirm: () async {
      await ref.read(authControllerProvider.notifier).signOut();
      return const ActionOutcome.success();
    },
  );
}
