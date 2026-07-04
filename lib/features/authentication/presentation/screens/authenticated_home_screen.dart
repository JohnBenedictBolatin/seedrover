import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/primary_button.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../providers/auth_providers.dart';

class AuthenticatedHomeScreen extends ConsumerWidget {
  const AuthenticatedHomeScreen({
    required this.title,
    required this.message,
    super.key,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profile = authState.profile;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.screenTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            message,
            style: AppTypography.body.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (profile != null) ...[
            Text(profile.fullName, style: AppTypography.sectionHeading),
            const SizedBox(height: AppSpacing.sm),
            StatusBadge(label: profile.roleName),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Username: ${profile.username}',
              style: AppTypography.small,
            ),
          ],
          const Spacer(),
          PrimaryButton(
            label: 'LOG OUT',
            isLoading: authState.isLoading,
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
    );
  }
}
