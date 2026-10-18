import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/constants/workspace_action.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../../rover/providers/rover_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../crops/providers/crop_providers.dart';
import '../../../inventory/providers/stock_providers.dart';
import '../../../crops/data/models/crop_model.dart';
import '../../../inventory/data/models/stock_model.dart';
import '../../../crops/presentation/widgets/crop_plant_image.dart';
import '../../../inventory/presentation/widgets/stock_produce_image.dart';

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
        Row(
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              if (index > 0) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TaskActionButton(
                  label: actions[index].label,
                  illustration: _illustrationFor(actions[index]),
                  onPressed: () => _startTask(actions[index]),
                ),
              ),
            ],
            if (showReview) ...[
              if (actions.isNotEmpty) const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TaskActionButton(
                  label: 'Review planting',
                  illustration: 'rover_monitor',
                  onPressed: () => context.push(AppRoutes.rover),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _illustrationFor(WorkspaceAction action) => switch (action) {
        WorkspaceAction.recordSale => 'sales',
        WorkspaceAction.receiveStock => 'inventory_mobile',
        WorkspaceAction.issueStock => 'inventory',
        WorkspaceAction.recordCare => 'crops_mobile',
        WorkspaceAction.observeGrowth => 'crops',
      };

  Future<void> _startTask(WorkspaceAction action) async {
    final targetId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.primaryBackground,
      builder: (_) => _TaskTargetPicker(action: action),
    );
    if (!mounted || targetId == null) return;

    final detailsPath = action.isInventory
        ? AppRoutes.stockDetailsPath(targetId)
        : AppRoutes.cropDetailsPath(targetId);
    final location = Uri(
      path: detailsPath,
      queryParameters: {'action': action.query},
    ).toString();
    context.push(location);
  }
}

class _TaskTargetPicker extends ConsumerWidget {
  const _TaskTargetPicker({required this.action});

  final WorkspaceAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title =
        action.isInventory ? 'Choose an inventory item' : 'Choose a crop';
    final explanation = switch (action) {
      WorkspaceAction.recordSale => 'Choose what you are selling.',
      WorkspaceAction.receiveStock => 'Choose where the new stock belongs.',
      WorkspaceAction.issueStock => 'Choose what you are taking out of stock.',
      WorkspaceAction.recordCare => 'Choose the crop you worked on.',
      WorkspaceAction.observeGrowth => 'Choose the crop to update.',
    };

    final List<_TaskTarget> targets;
    final bool loading;
    final String? error;
    final VoidCallback? retry;
    if (action.isInventory) {
      final state = ref.watch(stockInventoryControllerProvider);
      final controller = ref.read(stockInventoryControllerProvider.notifier);
      loading = state.isLoading && !state.hasLoaded;
      error = state.hasLoaded ? null : state.errorMessage;
      retry = controller.loadStocks;
      targets = [
        for (final stock in state.stocks)
          if (action == WorkspaceAction.receiveStock ||
              stock.currentQuantity > 0)
            _TaskTarget(
              id: stock.id,
              title: stock.name,
              subtitle:
                  '${stock.currentQuantity.toStringAsFixed(stock.currentQuantity % 1 == 0 ? 0 : 1)} ${stock.unit} available',
              image: StockProduceImage(
                itemName: stock.name,
                imageUrl: stock.imageUrl,
                assetPath: stock.imageAssetPath,
                size: 48,
              ),
            ),
      ];
    } else {
      final state = ref.watch(cropMonitoringControllerProvider);
      final controller = ref.read(cropMonitoringControllerProvider.notifier);
      loading = state.isLoading && !state.hasLoaded;
      error = state.hasLoaded ? null : state.errorMessage;
      retry = controller.loadCrops;
      targets = [
        for (final crop in state.crops)
          if (!crop.isCompleted)
            _TaskTarget(
              id: crop.id,
              title: crop.displayName,
              subtitle: '${crop.name} · ${crop.fieldLabel}',
              image: CropPlantImage(crop: crop, size: 48),
            ),
      ];
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .78,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(title, style: AppTypography.sectionHeading)),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(explanation, style: AppTypography.body),
            const SizedBox(height: AppSpacing.md),
            if (loading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              )
            else if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Column(
                  children: [
                    Text('Could not load choices.', style: AppTypography.body),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton.icon(
                      onPressed: retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (targets.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  action == WorkspaceAction.recordSale ||
                          action == WorkspaceAction.issueStock
                      ? 'There are no items with stock available for this task.'
                      : action.isInventory
                          ? 'Add an inventory item first, then receive stock.'
                          : 'There are no active crops to choose from.',
                  style: AppTypography.body,
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: targets.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final target = targets[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: target.image,
                      title: Text(target.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(target.subtitle,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(target.id),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TaskTarget {
  const _TaskTarget({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.image,
  });

  final String id;
  final String title;
  final String subtitle;
  final Widget image;
}

class _TaskActionButton extends StatelessWidget {
  const _TaskActionButton({
    required this.label,
    required this.illustration,
    required this.onPressed,
  });

  final String label;
  final String illustration;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 82,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.secondaryBackground,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppRadius.md),
              splashColor: AppColors.primaryGreen.withValues(alpha: .12),
              highlightColor: AppColors.primaryGreen.withValues(alpha: .06),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/mascots/$illustration.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              AppColors.buttonGradientStart,
                              AppColors.buttonGradientEnd,
                            ],
                          ).createShader(bounds),
                          blendMode: BlendMode.srcIn,
                          child: Text(
                            label,
                            maxLines: 1,
                            softWrap: false,
                            style: AppTypography.caption.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
