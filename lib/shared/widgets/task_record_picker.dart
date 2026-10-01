import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_routes.dart';
import '../../core/constants/permission_keys.dart';
import '../../core/constants/workspace_action.dart';
import '../../features/authentication/providers/auth_providers.dart';
import '../../features/crops/providers/crop_providers.dart';
import '../../features/inventory/providers/stock_providers.dart';

Future<void> openTaskRecordPicker(BuildContext context, WorkspaceAction action) async {
  final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => _TaskRecordPicker(action: action)));
  if (id == null || !context.mounted) return;
  final path = action.isInventory ? AppRoutes.stockDetailsPath(id) : AppRoutes.cropDetailsPath(id);
  context.push(Uri(path: path, queryParameters: {'action': action.query}).toString());
}

class _TaskRecordPicker extends ConsumerStatefulWidget {
  const _TaskRecordPicker({required this.action});
  final WorkspaceAction action;
  @override
  ConsumerState<_TaskRecordPicker> createState() => _TaskRecordPickerState();
}
class _TaskRecordPickerState extends ConsumerState<_TaskRecordPicker> {
  String query = '';
  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final profile = ref.watch(authControllerProvider).profile;
    final permitted = profile?.hasPermission(action.permission) == true && profile?.hasPermission(action.isInventory ? PermissionKeys.stocksView : PermissionKeys.cropsView) == true;
    if (!permitted) return Scaffold(appBar: AppBar(title: Text(action.label)), body: const Center(child: Text('This action is no longer available for your account.')));
    final entries = <({String id, String title, String subtitle})>[];
    bool loading;
    String? error;
    VoidCallback retry;
    if (action.isInventory) {
      final state = ref.watch(stockInventoryControllerProvider);
      loading = state.isLoading;
      error = state.errorMessage;
      retry = () => ref.read(stockInventoryControllerProvider.notifier).loadStocks();
      for (final stock in state.stocks) {
        if (action != WorkspaceAction.receiveStock && stock.currentQuantity <= 0) continue;
        entries.add((id: stock.id, title: stock.name, subtitle: '${stock.currentQuantity} ${stock.unit} available · ${stock.displayId}'));
      }
    } else {
      final state = ref.watch(cropMonitoringControllerProvider);
      loading = state.isLoading;
      error = state.errorMessage;
      retry = () => ref.read(cropMonitoringControllerProvider.notifier).loadCrops();
      for (final crop in state.crops.where((crop) => !crop.isCompleted)) {
        if (profile?.isAdministrator != true &&
            crop.assignedManagerId != profile?.id) {
          continue;
        }
        entries.add((id: crop.id, title: crop.name, subtitle: '${crop.fieldLabel} · ${crop.trackingCode}'));
      }
    }
    final filtered = entries.where((e) => '${e.title} ${e.subtitle}'.toLowerCase().contains(query.toLowerCase())).toList();
    return Scaffold(appBar: AppBar(title: Text(action.label)), body: Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: TextField(decoration: InputDecoration(labelText: action.isInventory ? 'Choose an inventory item' : 'Choose an active crop', prefixIcon: const Icon(Icons.search)), onChanged: (value) => setState(() => query = value))),
      if (loading) const LinearProgressIndicator(),
      if (error != null) ListTile(title: const Text('Could not refresh records.'), trailing: TextButton(onPressed: retry, child: const Text('Retry'))),
      Expanded(child: filtered.isEmpty ? Center(child: Text(loading ? 'Loading records…' : error != null ? 'Records are unavailable. Try again.' : query.isNotEmpty ? 'No matching records.' : 'No eligible records for this action.'))
        : ListView.builder(itemCount: filtered.length, itemBuilder: (context, index) {
          final entry = filtered[index];
          return ListTile(title: Text(entry.title), subtitle: Text(entry.subtitle), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.of(context).pop(entry.id));
        })),
    ]));
  }
}
