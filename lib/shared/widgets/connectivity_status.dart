import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/crops/providers/crop_providers.dart';
import '../../features/rover/providers/rover_providers.dart';
import '../../features/rover/presentation/widgets/planting_sync_progress_dialog.dart';

class ConnectivityStatus extends ConsumerStatefulWidget {
  const ConnectivityStatus({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ConnectivityStatus> createState() => _ConnectivityStatusState();
}

class _ConnectivityStatusState extends ConsumerState<ConnectivityStatus>
    with WidgetsBindingObserver {
  Timer? _probeTimer;
  Timer? _restoredTimer;
  bool _reconnecting = false;
  bool _restored = false;
  bool _checking = false;
  bool _internetAvailable = false;
  bool _syncingOfflineRecords = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_checkConnection());
    _probeTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_checkConnection()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkConnection());
    }
  }

  Future<void> _checkConnection() async {
    if (_checking) return;
    if (_isOnRoverWifi) {
      _internetAvailable = false;
      if (mounted && (_reconnecting || _restored)) {
        setState(() {
          _reconnecting = false;
          _restored = false;
        });
      }
      return;
    }
    _checking = true;
    try {
      await Supabase.instance.client
          .from('profiles')
          .select('id')
          .limit(1)
          .timeout(const Duration(seconds: 6));
      final justRestored = !_internetAvailable;
      _internetAvailable = true;
      if (!mounted) return;
      if (_reconnecting) {
        setState(() {
          _reconnecting = false;
          _restored = true;
        });
        _restoredTimer?.cancel();
        _restoredTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _restored = false);
        });
      }
      if (justRestored) unawaited(_syncPlantingRunsAfterReconnect());
    } catch (_) {
      _internetAvailable = false;
      if (!mounted) return;
      if (_isOnRoverWifi) {
        setState(() {
          _reconnecting = false;
          _restored = false;
        });
        return;
      }
      _restoredTimer?.cancel();
      if (!_reconnecting) setState(() => _reconnecting = true);
      if (_restored) setState(() => _restored = false);
    } finally {
      _checking = false;
    }
  }

  Future<void> _syncPlantingRunsAfterReconnect() async {
    if (_syncingOfflineRecords || !mounted) return;
    _syncingOfflineRecords = true;
    try {
      final repository = ref.read(plantingReceiptRepositoryProvider);
      final pending = await repository.loadPending();
      final confirmedRuns = pending.where((receipt) =>
          receipt.status.isTerminal &&
          receipt.isConfirmed &&
          !receipt.confirmationSynced);
      final cropController =
          ref.read(cropMonitoringControllerProvider.notifier);
      final pendingSensors = await cropController.pendingSensorCheckCount();
      if ((confirmedRuns.isEmpty && pendingSensors == 0) || !mounted) return;

      final hasPlantingRuns = confirmedRuns.isNotEmpty;
      final hasSensorReadings = pendingSensors > 0;

      await showPlantingSyncProgressDialog(
        context,
        title: hasPlantingRuns && hasSensorReadings
            ? 'Syncing saved records'
            : hasSensorReadings
                ? 'Syncing sensor readings'
                : 'Saving plant run',
        message: hasPlantingRuns && hasSensorReadings
            ? 'Uploading your sensor readings and planting result.'
            : hasSensorReadings
                ? 'Uploading readings saved on this device.'
                : 'Syncing the confirmed result.',
        synchronize: () async {
          if (hasSensorReadings) {
            await cropController.retryPendingSensorChecks();
          }
          if (hasPlantingRuns) {
            await ref
                .read(roverControlControllerProvider.notifier)
                .synchronizePendingReceipts();
          }
        },
      );
      if (!mounted) return;
      ref.invalidate(plantingRunsAwaitingSyncProvider);
      await cropController.loadCrops();
      final remainingSensors = await cropController.pendingSensorCheckCount();
      if (remainingSensors > 0 && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                '$remainingSensors sensor ${remainingSensors == 1 ? 'reading is' : 'readings are'} still waiting to sync.',
              ),
            ),
          );
      }
      final syncError = ref.read(roverControlControllerProvider).errorMessage;
      if (syncError != null && mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(syncError)));
      }
    } finally {
      _syncingOfflineRecords = false;
    }
  }

  bool get _isOnRoverWifi =>
      ref.read(localRoverWifiNetworkProvider).asData?.value ?? false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _probeTimer?.cancel();
    _restoredTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localRoverWifiConnected =
        ref.watch(localRoverWifiNetworkProvider).asData?.value ?? false;
    final banner = !localRoverWifiConnected && (_reconnecting || _restored);
    final colorScheme = Theme.of(context).colorScheme;
    final background = _restored
        ? colorScheme.primaryContainer
        : colorScheme.tertiaryContainer;
    final foreground = _restored
        ? colorScheme.onPrimaryContainer
        : colorScheme.onTertiaryContainer;

    return Column(
      children: [
        if (banner)
          Material(
            color: background,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _restored
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
                      color: foreground,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _restored
                            ? 'Internet connection restored. Refresh your data before continuing.'
                            : 'Reconnecting to the internet. Changes cannot be saved. If a transaction was interrupted, check its record before submitting it again.',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: foreground),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: banner,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}
