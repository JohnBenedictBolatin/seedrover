import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/constants/workspace_action.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../../rover/providers/rover_providers.dart';
import '../../../../core/theme/app_colors.dart';

class DashboardQuickActions extends ConsumerStatefulWidget {
  const DashboardQuickActions({super.key});

  @override
  ConsumerState<DashboardQuickActions> createState() =>
      _DashboardQuickActionsState();
}

class _DashboardQuickActionsState extends ConsumerState<DashboardQuickActions> {
  bool _hasPlantingReview = false;

  @override
  void initState() {
    super.initState();
    _loadPlantingReview();
  }

  Future<void> _loadPlantingReview() async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null ||
        !(profile.isPlantingManager || profile.isPlantingStaff) ||
        !profile.hasPermission(PermissionKeys.roverView)) {
      return;
    }
    try {
      final receipts =
          await ref.read(plantingReceiptRepositoryProvider).loadPending();
      if (!mounted) return;
      setState(() {
        _hasPlantingReview = receipts.any(
            (receipt) => receipt.status.isTerminal && !receipt.isConfirmed);
      });
    } catch (_) {
      // The dashboard attention section reports local-record load failures.
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return const SizedBox.shrink();
    final isPlanting = profile.isPlantingManager || profile.isPlantingStaff;
    final candidates = profile.isAdministrator
        ? [
            WorkspaceAction.recordSale,
            WorkspaceAction.recordCare,
            WorkspaceAction.receiveStock,
          ]
        : isPlanting
            ? [WorkspaceAction.recordCare, WorkspaceAction.observeGrowth]
            : [
                WorkspaceAction.recordSale,
                WorkspaceAction.receiveStock,
                WorkspaceAction.issueStock,
              ];
    final actions = candidates
        .where((action) =>
            profile.hasPermission(action.permission) &&
            profile.hasPermission(action.isInventory
                ? PermissionKeys.stocksView
                : PermissionKeys.cropsView))
        .toList();
    final showReview = isPlanting &&
        _hasPlantingReview &&
        profile.hasPermission(PermissionKeys.roverView);
    if (actions.isEmpty && !showReview) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Start a task', style: AppTypography.sectionHeading),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 48,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < actions.length; index++) ...[
                  if (index > 0) const SizedBox(width: AppSpacing.sm),
                  _TaskActionButton(
                    label: actions[index].label,
                    icon: _iconFor(actions[index]),
                    onPressed: () => context.push(
                      actions[index].isInventory
                          ? AppRoutes.stocks
                          : AppRoutes.crops,
                    ),
                    backgroundColor: AppColors.secondaryBackground,
                    foregroundColor: AppColors.secondaryGreen,
                  ),
                ],
                if (showReview) ...[
                  if (actions.isNotEmpty) const SizedBox(width: AppSpacing.sm),
                  _TaskActionButton(
                    label: 'Review planting',
                    icon: Icons.rate_review_outlined,
                    onPressed: () => context.push(AppRoutes.rover),
                    backgroundColor: AppColors.secondaryBackground,
                    foregroundColor: AppColors.warning,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _iconFor(WorkspaceAction action) => switch (action) {
        WorkspaceAction.recordSale => Icons.point_of_sale_outlined,
        WorkspaceAction.receiveStock => Icons.add_box_outlined,
        WorkspaceAction.issueStock => Icons.outbox_outlined,
        WorkspaceAction.recordCare => Icons.water_drop_outlined,
        WorkspaceAction.observeGrowth => Icons.add_a_photo_outlined,
      };
}

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          softWrap: false,
        ),
        style: FilledButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.smd),
          side: BorderSide(color: AppColors.primaryBorder),
          visualDensity: VisualDensity.compact,
        ),
      );
}
