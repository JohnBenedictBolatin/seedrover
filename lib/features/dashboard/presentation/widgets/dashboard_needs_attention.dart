import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/history_pagination.dart';
import '../../../authentication/providers/auth_providers.dart';
import '../../../crops/data/models/crop_model.dart';
import '../../../crops/controllers/crop_monitoring_state.dart';
import '../../../crops/providers/crop_providers.dart';
import '../../../inventory/data/models/stock_model.dart';
import '../../../inventory/controllers/stock_inventory_state.dart';
import '../../../inventory/providers/stock_providers.dart';
import '../../../rover/data/models/planting_session_model.dart';
import '../../../rover/data/models/rover_command_model.dart';
import '../../../rover/providers/rover_providers.dart';

class DashboardNeedsAttention extends ConsumerStatefulWidget {
  const DashboardNeedsAttention({super.key});

  @override
  ConsumerState<DashboardNeedsAttention> createState() =>
      _DashboardNeedsAttentionState();
}

class _DashboardNeedsAttentionState
    extends ConsumerState<DashboardNeedsAttention> {
  String? _pendingAccountId;
  List<PendingPlantingReceipt> _pendingRecords = [];

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    if (_pendingAccountId != profile?.id) {
      _pendingAccountId = profile?.id;
      _pendingRecords = [];
    }
    final canViewCrops =
        profile?.hasPermission(PermissionKeys.cropsView) ?? false;
    final canViewStocks =
        profile?.hasPermission(PermissionKeys.stocksView) ?? false;
    final canUseRover =
        profile?.hasPermission(PermissionKeys.roverView) ?? false;
    final pendingState = canUseRover
        ? ref.watch(pendingPlantingAttentionProvider(profile?.id))
        : const AsyncData<List<PendingPlantingReceipt>>([]);
    final latestPendingRecords = pendingState.asData?.value;
    if (latestPendingRecords != null) _pendingRecords = latestPendingRecords;
    final List<PendingPlantingReceipt> pendingRecords =
        canUseRover ? _pendingRecords : const <PendingPlantingReceipt>[];
    final cropState = canViewCrops
        ? ref.watch(cropMonitoringControllerProvider)
        : CropMonitoringState.initial();
    final stockState = canViewStocks
        ? ref.watch(stockInventoryControllerProvider)
        : StockInventoryState.initial();

    final care = <({CropModel crop, CropCareTask task})>[];
    if (canViewCrops) {
      for (final crop in cropState.crops) {
        if (profile == null ||
            (!profile.isAdministrator &&
                crop.assignedManagerId != profile.id)) {
          continue;
        }
        for (final task in crop.careTasks.where(
            (task) => task.status == 'Overdue' || task.status == 'Due')) {
          care.add((crop: crop, task: task));
        }
      }
      const priorityOrder = {'Critical': 0, 'Important': 1, 'Routine': 2};
      care.sort((a, b) {
        final overdue = (a.task.status == 'Overdue' ? 0 : 1)
            .compareTo(b.task.status == 'Overdue' ? 0 : 1);
        if (overdue != 0) return overdue;
        final order = (priorityOrder[a.task.priority] ?? 3)
            .compareTo(priorityOrder[b.task.priority] ?? 3);
        return order == 0 ? a.task.dueAt.compareTo(b.task.dueAt) : order;
      });
    }
    final lowStocks = canViewStocks
        ? stockState.stocks
            .where((stock) => stock.status != StockStatus.inStock)
            .toList()
        : <StockModel>[];
    final allAttentionEntries = <_AttentionEntry>[
      for (final receipt in pendingRecords)
        _AttentionEntry(
          icon: receipt.isConfirmed
              ? Icons.cloud_upload_outlined
              : Icons.rate_review_outlined,
          title:
              receipt.isConfirmed ? 'Planting sync pending' : 'Review planting',
          subtitle: _plantingReceiptSubtitle(receipt),
          onTap: () => context.push(AppRoutes.rover),
        ),
      for (final item in care)
        _AttentionEntry(
          icon: Icons.eco_outlined,
          title: item.task.farmerTitle,
          subtitle:
              '${item.crop.displayName} · ${item.crop.name} · ${item.crop.fieldLabel}',
          onTap: () => context.push(
            '${AppRoutes.cropDetailsPath(item.crop.id)}?task=${Uri.encodeComponent(item.task.id)}',
          ),
        ),
      for (final stock in lowStocks)
        _AttentionEntry(
          icon: stock.status == StockStatus.outOfStock
              ? Icons.remove_shopping_cart_outlined
              : Icons.inventory_2_outlined,
          title: stock.name,
          subtitle: stock.status == StockStatus.outOfStock
              ? 'Out of stock · ${stock.storageLocation}'
              : '${stock.status.label} · ${stock.currentQuantity} ${stock.unit}',
          onTap: () => context.push(AppRoutes.stockDetailsPath(stock.id)),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Needs attention',
                style: AppTypography.sectionHeading,
              ),
            ),
            if (allAttentionEntries.length > 3)
              TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _AttentionHistorySheet(
                    entries: allAttentionEntries,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  textStyle: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('View All'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if ((canUseRover && pendingState.isLoading) ||
            (canViewCrops && cropState.isLoading) ||
            (canViewStocks && stockState.isLoading))
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sm),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (canUseRover && pendingState.isLoading && !pendingState.hasValue)
          const SizedBox.shrink(),
        if (canUseRover && pendingState.hasError && !pendingState.hasValue)
          _SourceMessage(
            text: 'Planting records are unavailable.',
            action: 'Retry',
            onPressed: () => ref.invalidate(
              pendingPlantingAttentionProvider(profile?.id),
            ),
          ),
        if (canUseRover && pendingState.hasValue && pendingRecords.isNotEmpty)
          _PendingRows(receipts: pendingRecords.take(1).toList()),
        if (canViewCrops &&
            cropState.errorMessage != null &&
            cropState.crops.isEmpty)
          _SourceMessage(
            text: 'Crop tasks are unavailable.',
            action: 'Retry',
            onPressed: () =>
                ref.read(cropMonitoringControllerProvider.notifier).loadCrops(),
          ),
        if (canViewCrops && cropState.crops.isNotEmpty)
          for (final item in care.take(1))
            _AttentionRow(
              icon: Icons.eco_outlined,
              title: item.task.farmerTitle,
              subtitle:
                  '${item.crop.displayName} · ${item.crop.name} · ${item.crop.fieldLabel}',
              onTap: () => context.push(
                '${AppRoutes.cropDetailsPath(item.crop.id)}?task=${Uri.encodeComponent(item.task.id)}',
              ),
            ),
        if (canViewStocks &&
            stockState.errorMessage != null &&
            stockState.stocks.isEmpty)
          _SourceMessage(
            text: 'Inventory status is unavailable.',
            action: 'Retry',
            onPressed: () => ref
                .read(stockInventoryControllerProvider.notifier)
                .loadStocks(),
          ),
        if (canViewStocks && stockState.stocks.isNotEmpty)
          for (final stock in lowStocks.take(1))
            _AttentionRow(
              icon: stock.status == StockStatus.outOfStock
                  ? Icons.remove_shopping_cart_outlined
                  : Icons.inventory_2_outlined,
              title: stock.name,
              subtitle: stock.status == StockStatus.outOfStock
                  ? 'Out of stock · ${stock.storageLocation}'
                  : '${stock.status.label} · ${stock.currentQuantity} ${stock.unit}',
              onTap: () => context.push(AppRoutes.stockDetailsPath(stock.id)),
            ),
        if (!canUseRover && !canViewCrops && !canViewStocks)
          const _SourceMessage(text: 'No attention items for this account.'),
        if ((canUseRover || canViewCrops || canViewStocks) &&
            (!canViewCrops || cropState.hasLoaded) &&
            (!canViewStocks || stockState.hasLoaded) &&
            (!canUseRover || pendingState.hasValue) &&
            (!canViewCrops || cropState.errorMessage == null) &&
            (!canViewStocks || stockState.errorMessage == null) &&
            (!canUseRover || pendingState.hasValue) &&
            care.isEmpty &&
            lowStocks.isEmpty &&
            pendingRecords.isEmpty)
          const _SourceMessage(text: 'You’re up to date'),
      ],
    );
  }
}

class _AttentionEntry {
  const _AttentionEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
}

class _AttentionHistorySheet extends StatefulWidget {
  const _AttentionHistorySheet({required this.entries});

  final List<_AttentionEntry> entries;

  @override
  State<_AttentionHistorySheet> createState() => _AttentionHistorySheetState();
}

class _AttentionHistorySheetState extends State<_AttentionHistorySheet> {
  static const _pageSize = 5;
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final pageEntries = widget.entries.skip(_page * _pageSize).take(_pageSize);
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: .88,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primaryBackground,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                key: const Key('needs-attention-history-drag-handle'),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inactiveBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Needs attention',
                              style: AppTypography.sectionHeading),
                          Text('${widget.entries.length} attention items',
                              style: AppTypography.caption),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close needs attention',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  itemBuilder: (context, index) {
                    final entry = pageEntries.elementAt(index);
                    return _AttentionRow(
                      icon: entry.icon,
                      title: entry.title,
                      subtitle: entry.subtitle,
                      onTap: () {
                        Navigator.of(context).pop();
                        entry.onTap();
                      },
                    );
                  },
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemCount: pageEntries.length,
                ),
              ),
              HistoryPagination(
                pageIndex: _page,
                totalRecords: widget.entries.length,
                pageSize: _pageSize,
                onPageChanged: (page) => setState(() => _page = page),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingRows extends StatelessWidget {
  const _PendingRows({required this.receipts});
  final List<PendingPlantingReceipt> receipts;

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final receipt in receipts)
          _AttentionRow(
            icon: receipt.isConfirmed
                ? Icons.cloud_upload_outlined
                : Icons.rate_review_outlined,
            title: receipt.isConfirmed
                ? 'Planting sync pending'
                : 'Review planting',
            subtitle: _plantingReceiptSubtitle(receipt),
            onTap: () => context.push(AppRoutes.rover),
          ),
      ]);
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: AppColors.primaryGreen),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.small.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption,
        ),
        trailing: Icon(
          Icons.arrow_forward_rounded,
          color: AppColors.mutedText,
          size: 20,
        ),
        onTap: onTap,
      );
}

String _plantingReceiptSubtitle(PendingPlantingReceipt receipt) {
  final field = receipt.config.fieldLabel.trim();
  return '${receipt.config.seed.label} · ${field.isEmpty ? 'No field' : field}';
}

class _SourceMessage extends StatelessWidget {
  const _SourceMessage({required this.text, this.action, this.onPressed});
  final String text;
  final String? action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(children: [
          Expanded(child: Text(text, style: AppTypography.small)),
          if (action != null)
            TextButton(onPressed: onPressed, child: Text(action!)),
        ]),
      );
}
