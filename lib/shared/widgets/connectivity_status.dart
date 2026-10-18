import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/foreground_polling.dart';
import '../../features/crops/providers/crop_providers.dart';
import '../../features/authentication/providers/auth_providers.dart';
import '../../features/rover/providers/rover_providers.dart';
import '../../features/rover/presentation/widgets/planting_sync_progress_dialog.dart';
import 'floating_app_notice.dart';

class ConnectivityStatus extends ConsumerStatefulWidget {
  const ConnectivityStatus({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ConnectivityStatus> createState() => _ConnectivityStatusState();
}

class _ConnectivityStatusState extends ConsumerState<ConnectivityStatus> {
  late final ForegroundPolling _polling;
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;
  Timer? _restoredTimer;
  bool _reconnecting = false;
  bool _restored = false;
  bool _checking = false;
  bool _internetAvailable = false;
  bool _syncingOfflineRecords = false;

  @override
  void initState() {
    super.initState();
    _polling = ForegroundPolling(
      check: _checkConnection,
      interval: const Duration(seconds: 120),
    )..start();
    _networkSubscription = Connectivity().onConnectivityChanged.listen(
      (connections) {
        if (connections.any((connection) => connection != ConnectivityResult.none)) {
          unawaited(_polling.requestCheck());
        }
      },
      // The foreground timer still works when platform notifications fail.
      onError: (Object _) {},
    );
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
      ref.invalidate(pendingPlantingAttentionProvider(
        ref.read(authControllerProvider).profile?.id,
      ));
      await cropController.loadCrops();
      final remainingSensors = await cropController.pendingSensorCheckCount();
      if (remainingSensors > 0 && mounted) {
        showFloatingAppToast(
          context,
          title: 'Some readings are still waiting',
          message:
              '$remainingSensors sensor ${remainingSensors == 1 ? 'reading is' : 'readings are'} still waiting to sync.',
          tone: FloatingNoticeTone.warning,
          icon: Icons.cloud_upload_outlined,
        );
      }
      final syncError = ref.read(roverControlControllerProvider).errorMessage;
      if (syncError != null && mounted) {
        showFloatingAppToast(
          context,
          title: 'Some records could not sync',
          message: syncError,
          tone: FloatingNoticeTone.warning,
          icon: Icons.cloud_off_rounded,
        );
      }
    } finally {
      _syncingOfflineRecords = false;
    }
  }

  bool get _isOnRoverWifi =>
      ref.read(localRoverWifiNetworkProvider).asData?.value ?? false;

  @override
  void dispose() {
    _polling.dispose();
    _networkSubscription?.cancel();
    _restoredTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(localRoverWifiNetworkProvider, (previous, next) {
      if (previous?.asData?.value == true && next.asData?.value == false) {
        unawaited(_polling.requestCheck());
      }
    });
    final localRoverWifiConnected =
        ref.watch(localRoverWifiNetworkProvider).asData?.value ?? false;
    final visible = !localRoverWifiConnected && (_reconnecting || _restored);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final bottomClearance =
        MediaQuery.paddingOf(context).bottom + (isLandscape ? 72.0 : 86.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (visible)
          Positioned(
            right: 12,
            bottom: bottomClearance,
            width: (MediaQuery.sizeOf(context).width - 24)
                .clamp(0.0, 420.0)
                .toDouble(),
            child: FloatingAppNotice(
              title: _restored ? 'Internet restored' : 'Reconnecting…',
              message: _restored
                  ? 'Refresh your data before continuing.'
                  : 'Changes may not save. Check interrupted actions before trying again.',
              tone: _restored
                  ? FloatingNoticeTone.success
                  : FloatingNoticeTone.warning,
              icon: _restored
                  ? Icons.cloud_done_rounded
                  : Icons.cloud_sync_rounded,
            ),
          ),
      ],
    );
  }
}

