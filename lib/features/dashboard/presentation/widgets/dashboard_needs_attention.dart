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
  late Future<List<PendingPlantingReceipt>> _pendingReceipts;
  List<PendingPlantingReceipt> _pendingRecords = [];

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authControllerProvider).profile;
    if (profile?.hasPermission(PermissionKeys.roverView) == true) {
      _loadPendingReceipts();
    } else {
      _pendingReceipts = Future.value(const <PendingPlantingReceipt>[]);
    }
  }

  void _loadPendingReceipts() {
    final future = ref.read(plantingReceiptRepositoryProvider).loadPending();
    _pendingReceipts = future;
    future.then(
      (receipts) {
        if (!mounted) return;
        final pending = receipts
            .where((receipt) =>
                receipt.status.isTerminal &&
                (!receipt.isConfirmed || !receipt.confirmationSynced))
            .toList()
          ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
        setState(() => _pendingRecords = pending);
      },
      onError: (Object _) {
        if (mounted) setState(() => _pendingRecords = []);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final canViewCrops =
        profile?.hasPermission(PermissionKeys.cropsView) ?? false;
    final canViewStocks =
        profile?.hasPermission(PermissionKeys.stocksView) ?? false;
    final canUseRover =
        profile?.hasPermission(PermissionKeys.roverView) ?? false;
    final cropState = canViewCrops
        ? ref.watch(cropMonitoringControllerProvider)
        : CropMonitoringState.initial();
    final stockState = canViewStocks
        ? ref.watch(stockInventoryControllerProvider)
        : StockInventoryState.initial();

    final care = <({CropModel crop, CropCareTask task})>[];
    if (canViewCrops && !cropState.isLoading) {
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
    final lowStocks = canViewStocks && !stockState.isLoading
        ? stockState.stocks
            .where((stock) => stock.status != StockStatus.inStock)
            .toList()
        : <StockModel>[];
    final allAttentionEntries = <_AttentionEntry>[
      for (final receipt in _pendingRecords)
        _AttentionEntry(
          icon: receipt.isConfirmed
              ? Icons.cloud_upload_outlined
              : Icons.rate_review_outlined,
          title:
              receipt.isConfirmed ? 'Planting sync pending' : 'Review planting',
          subtitle:
              '${receipt.config.seed.label} · ${receipt.config.fieldLabel.isEmpty ? 'Field not labeled' : receipt.config.fieldLabel}',
          onTap: () => context.push(AppRoutes.rover),
        ),
      for (final item in care)
        _AttentionEntry(
          icon: Icons.eco_outlined,
          title: item.task.title,
          subtitle: '${item.crop.name} · ${item.crop.fieldLabel}',
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

    return Card(
      color: AppColors.secondaryBackground,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child:
                      Text('Needs attention', style: AppTypography.cardTitle)),
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.danger,
              ),
            ]),
            const SizedBox(height: AppSpacing.xs),
            if (canUseRover)
              FutureBuilder<List<PendingPlantingReceipt>>(
                future: _pendingReceipts,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _SourceMessage(
                      text: 'Planting records could not be checked.',
                      action: 'Retry',
                      onPressed: () => setState(_loadPendingReceipts),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const _SourceMessage(
                        text: 'Checking planting records…');
                  }
                  final pending = snapshot.data!
                      .where((receipt) =>
                          receipt.status.isTerminal &&
                          (!receipt.isConfirmed || !receipt.confirmationSynced))
                      .toList()
                    ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
                  final allSourcesReady = (!canViewCrops ||
                          (!cropState.isLoading &&
                              cropState.errorMessage == null)) &&
                      (!canViewStocks ||
                          (!stockState.isLoading &&
                              stockState.errorMessage == null));
                  final nothingElseNeedsAttention =
                      care.isEmpty && lowStocks.isEmpty;
                  if (pending.isEmpty &&
                      allSourcesReady &&
                      nothingElseNeedsAttention) {
                    return const _SourceMessage(text: 'You’re up to date');
                  }
                  return _PendingRows(
                    receipts: pending.take(1).toList(),
                    emptyMessage: 'No unresolved planting records',
                  );
                },
              ),
            if (canViewCrops && cropState.isLoading)
              const _SourceMessage(text: 'Checking crop tasks…'),
            if (canViewCrops && cropState.errorMessage != null)
              _SourceMessage(
                text: cropState.crops.isEmpty
                    ? 'Crop tasks are unavailable.'
                    : 'Showing saved crop tasks; refresh may be needed.',
                action: 'Retry',
                onPressed: () => ref
                    .read(cropMonitoringControllerProvider.notifier)
                    .loadCrops(),
              ),
            if (canViewCrops && !cropState.isLoading)
              for (final item in care.take(1))
                _AttentionRow(
                  icon: Icons.eco_outlined,
                  title: item.task.title,
                  subtitle: '${item.crop.name} · ${item.crop.fieldLabel}',
                  onTap: () => context.push(
                    '${AppRoutes.cropDetailsPath(item.crop.id)}?task=${Uri.encodeComponent(item.task.id)}',
                  ),
                ),
            if (canViewStocks && stockState.isLoading)
              const _SourceMessage(text: 'Checking inventory…'),
            if (canViewStocks && stockState.errorMessage != null)
              _SourceMessage(
                text: stockState.stocks.isEmpty
                    ? 'Inventory status is unavailable.'
                    : 'Showing saved stock status; refresh may be needed.',
                action: 'Retry',
                onPressed: () => ref
                    .read(stockInventoryControllerProvider.notifier)
                    .loadStocks(),
              ),
            if (canViewStocks && !stockState.isLoading)
              for (final stock in lowStocks.take(1))
                _AttentionRow(
                  icon: stock.status == StockStatus.outOfStock
                      ? Icons.remove_shopping_cart_outlined
                      : Icons.inventory_2_outlined,
                  title: stock.name,
                  subtitle: stock.status == StockStatus.outOfStock
                      ? 'Out of stock · ${stock.storageLocation}'
                      : '${stock.status.label} · ${stock.currentQuantity} ${stock.unit}',
                  onTap: () =>
                      context.push(AppRoutes.stockDetailsPath(stock.id)),
                ),
            if (!canUseRover && !canViewCrops && !canViewStocks)
              const _SourceMessage(
                  text: 'No attention items for this account.'),
            if (!canUseRover &&
                (canViewCrops || canViewStocks) &&
                (!canViewCrops ||
                    (!cropState.isLoading &&
                        cropState.errorMessage == null &&
                        care.isEmpty)) &&
                (!canViewStocks ||
                    (!stockState.isLoading &&
                        stockState.errorMessage == null &&
                        lowStocks.isEmpty)))
              const _SourceMessage(text: 'You’re up to date'),
            if (allAttentionEntries.length > 3)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
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
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: AppTypography.small.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('View All'),
                ),
              ),
          ],
        ),
      ),
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
  const _PendingRows({required this.receipts, required this.emptyMessage});
  final List<PendingPlantingReceipt> receipts;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) => Column(children: [
        if (receipts.isEmpty) _SourceMessage(text: emptyMessage),
        for (final receipt in receipts)
          _AttentionRow(
            icon: receipt.isConfirmed
                ? Icons.cloud_upload_outlined
                : Icons.rate_review_outlined,
            title: receipt.isConfirmed
                ? 'Planting sync pending'
                : 'Review planting',
            subtitle:
                '${receipt.config.seed.label} · ${receipt.config.fieldLabel.isEmpty ? 'Field not labeled' : receipt.config.fieldLabel}',
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
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          child: Icon(icon, color: AppColors.primaryGreen),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: Icon(
          Icons.arrow_forward_rounded,
          color: AppColors.mutedText,
          size: 20,
        ),
        onTap: onTap,
      );
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
