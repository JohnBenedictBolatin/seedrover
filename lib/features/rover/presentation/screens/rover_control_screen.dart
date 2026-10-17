import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/permission_keys.dart';
import '../../../../core/config/app_environment.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_selector.dart';
import '../../../../shared/models/soil_moisture_diagnosis.dart';
import '../../../../features/authentication/providers/auth_providers.dart';
import '../../../../features/crops/controllers/crop_monitoring_controller.dart';
import '../../../../features/crops/data/models/crop_model.dart';
import '../../../../features/crops/providers/crop_providers.dart';
import '../../../../shared/widgets/content_skeleton.dart';
import '../../../../shared/widgets/seedrover_mascot.dart';
import '../../controllers/rover_control_state.dart';
import '../../data/models/rover_command_model.dart';
import '../../data/models/rover_control_model.dart';
import '../../data/models/planting_session_model.dart';
import '../../data/models/planting_soil_precheck.dart';
import '../../data/models/planting_condition_assessment.dart';
import '../../controllers/rover_control_controller.dart';
import '../../providers/rover_providers.dart';
import '../widgets/camera_preview_panel.dart';
import '../widgets/movement_control_panel.dart';
import '../widgets/planting_sync_progress_dialog.dart';
import '../widgets/sensor_monitoring_grid.dart';

class RoverControlScreen extends ConsumerStatefulWidget {
  const RoverControlScreen({super.key});

  @override
  ConsumerState<RoverControlScreen> createState() => _RoverControlScreenState();
}

class _RoverControlScreenState extends ConsumerState<RoverControlScreen>
    with WidgetsBindingObserver {
  bool _cameraOnline = false;

  void _handleCameraStatus(bool online) {
    if (!mounted || _cameraOnline == online) return;
    setState(() => _cameraOnline = online);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(roverControlControllerProvider.notifier).onAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(const []);
    super.dispose();
  }

  Future<void> _toggleLandscapeControls(
    RoverControlController controller,
    bool fullscreen,
  ) async {
    final nextFullscreen = !fullscreen;
    await SystemChrome.setPreferredOrientations(
      nextFullscreen
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [DeviceOrientation.portraitUp],
    );
    if (mounted) controller.setCameraFullscreen(nextFullscreen);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RoverControlState>(roverControlControllerProvider,
        (previous, next) {
      final message = next.errorMessage;
      if (message != null &&
          message != previous?.errorMessage &&
          !message.startsWith('Scanning for') &&
          !(message
                  .toLowerCase()
                  .startsWith('reconnect before sending commands') &&
              !next.cameraFullscreen)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      }
      final confirmationSession = next.pendingConfirmationSessionId;
      if (confirmationSession != null &&
          confirmationSession != previous?.pendingConfirmationSessionId) {
        final operation = next.plantingOperation;
        if (operation != null && operation.sessionId == confirmationSession) {
          _askWhetherAnythingWasPlanted(
            context,
            ref,
            ref.read(roverControlControllerProvider.notifier),
            operation,
          );
        }
      }
      final syncedConfirmation = next.lastConfirmedSyncedSessionId;
      if (syncedConfirmation != null &&
          syncedConfirmation != previous?.lastConfirmedSyncedSessionId) {
        ref.invalidate(plantingRunsAwaitingSyncProvider);
        ref.read(cropMonitoringControllerProvider.notifier).loadCrops();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Planting record synced and saved to history.'),
          ));
      } else if (next.confirmedPlantingSessionId != null &&
          next.confirmedPlantingSessionId !=
              previous?.confirmedPlantingSessionId) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('Planting result saved on this phone; syncing.'),
          ));
      }
      final cropId = next.lastCreatedCropId;
      if (cropId != null && cropId != previous?.lastCreatedCropId) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: const Text('Crop saved from the rover planting run.'),
            action: SnackBarAction(
              label: 'VIEW CROP',
              onPressed: () => context.go(AppRoutes.cropDetailsPath(cropId)),
            ),
          ));
      }
    });
    final state = ref.watch(roverControlControllerProvider);
    final controller = ref.read(roverControlControllerProvider.notifier);
    final profile = ref.watch(authControllerProvider).profile;
    final environment = ref.watch(appEnvironmentProvider);
    final obstacleStatus = _obstacleStatusFor(state);

    final canControl =
        profile?.hasPermission(PermissionKeys.roverControl) ?? true;
    final canViewCamera =
        profile?.hasPermission(PermissionKeys.roverCameraView) ?? true;
    final canControlPlanting =
        profile?.hasPermission(PermissionKeys.roverPlantingControl) ?? true;
    final canManageCrops =
        profile?.hasPermission(PermissionKeys.cropsManage) ?? true;

    if (state.isLoading) {
      return const _RoverLoadingSkeleton();
    }

    final telemetry = state.telemetry ?? RoverControlModel.offline();
    final movementOverlaySize = (MediaQuery.sizeOf(context).height * .52)
        .clamp(160.0, 210.0)
        .toDouble();
    final rakeCommandedDown = state.plantingOperation?.rakeCommandedDown;
    final activeCrops = ref
        .watch(cropMonitoringControllerProvider)
        .crops
        .where((crop) => !crop.isCompleted)
        .toList(growable: false);
    final canPlantNextRow = !state.isPlantingLocked &&
        state.activePlantingConfig != null &&
        state.pendingConfirmationSessionId == null &&
        !(state.plantingOperation?.awaitingPhoneAck ?? false);
    final canUseControls =
        state.localWifiConnected && !state.isPlantingLocked;
    return Column(
      children: [
        _RoverHeader(
          connected: state.isConnected,
          showRoverStatus: state.cameraFullscreen,
          showCameraStatus: state.cameraFullscreen,
          cameraConnected: _cameraOnline,
          cameraCanView: canViewCamera,
          onBack: () {
            if (state.cameraFullscreen) {
              _toggleLandscapeControls(controller, true);
              return;
            }
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(
                profile?.isPlantingManager == true ||
                        profile?.isPlantingStaff == true
                    ? AppRoutes.crops
                    : AppRoutes.dashboard,
              );
            }
          },
        ),
        Expanded(
          child: state.cameraFullscreen
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Row(
                        children: [
                          SizedBox(
                            width: movementOverlaySize,
                            child: ColoredBox(
                              color: AppColors.primaryBackground,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(top: AppSpacing.smd),
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: movementOverlaySize,
                                    height: movementOverlaySize,
                                    child: MovementControlPanel(
                                      enabled: state.isPlantingLocked
                                          ? canControlPlanting
                                          : canControl,
                                      plantingMode: state.isPlantingLocked,
                                      activeCommand: state.activeMovement,
                                      onCommand: controller.sendMovement,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreviewPanel(
                                  connected: state.localWifiConnected,
                                  loading: false,
                                  canView: canViewCamera,
                                  cameraBaseUrl: environment.cameraBaseUrl,
                                  onCameraStatusChanged: _handleCameraStatus,
                                  fullscreen: true,
                                  fillAvailableSpace: true,
                                  showStatusBadge: false,
                                  showWaitingMessage: false,
                                ),
                                if (state.isPlantingLocked)
                                  Align(
                                    alignment: const Alignment(0.0, -0.85),
                                    child: _LandscapePlantingPhaseNotice(
                                      status: state.plantingStatus,
                                      operation: state.plantingOperation,
                                    ),
                                  ),
                                Align(
                                  alignment: const Alignment(0.0, 0.9),
                                  child: SizedBox(
                                    width:
                                        MediaQuery.sizeOf(context).width * .32,
                                    child: _ObstacleNotice(
                                      status: obstacleStatus,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      flex: 3,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxHeight < 300;
                          final buttonHeight = compact ? 40.0 : 44.0;
                          final gap = compact ? 4.0 : 7.0;
                          final canUseControls = state.localWifiConnected &&
                              !state.isPlantingLocked;
                          final canSense = canControl &&
                              canManageCrops &&
                              canUseControls &&
                              !telemetry.isSimulated &&
                              activeCrops.isNotEmpty;
                          return SingleChildScrollView(
                            padding: const EdgeInsets.only(
                              top: AppSpacing.md,
                              bottom: AppSpacing.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FilledButton.icon(
                                  onPressed: canControlPlanting && canUseControls
                                      ? () => _showPlantingConfiguration(
                                            this.context,
                                            controller,
                                            state.selectedSeed,
                                            returnToLandscape:
                                                state.cameraFullscreen,
                                          )
                                      : null,
                                  icon: const Icon(
                                    Icons.agriculture_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Set up planting',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: FilledButton.styleFrom(
                                    minimumSize: Size.fromHeight(buttonHeight),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                    ),
                                  ),
                                ),
                                SizedBox(height: gap),
                                OutlinedButton.icon(
                                  onPressed: canSense
                                      ? () => _showSensorReadingSheet(
                                            this.context,
                                            controller,
                                            activeCrops,
                                            ref.read(
                                              cropMonitoringControllerProvider
                                                  .notifier,
                                            ),
                                            returnToLandscape:
                                                state.cameraFullscreen,
                                          )
                                      : null,
                                  icon: const Icon(
                                    Icons.sensors_outlined,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Soil condition sensing',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size.fromHeight(buttonHeight),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                    ),
                                  ),
                                ),
                                SizedBox(height: gap),
                                OutlinedButton.icon(
                                  onPressed: canUseControls
                                      ? () {
                                          final movingUp =
                                              rakeCommandedDown == true;
                                          final command = movingUp
                                              ? 'RAKE_UP'
                                              : 'RAKE_DOWN';
                                          final label = movingUp
                                              ? 'Raise rake'
                                              : 'Lower rake';
                                          _confirmRoverAction(
                                            context,
                                            title: '$label?',
                                            message:
                                                '$label now? Keep clear of the rover mechanism while it moves.',
                                            confirmLabel: label,
                                            confirmColor:
                                                AppColors.primaryGreen,
                                            onConfirm: () =>
                                                controller.controlMechanism(
                                              command,
                                              label,
                                            ),
                                          );
                                        }
                                      : null,
                                  icon: Icon(
                                    rakeCommandedDown == true
                                        ? Icons.arrow_upward_rounded
                                        : Icons.arrow_downward_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    rakeCommandedDown == true
                                        ? 'Raise rake'
                                        : 'Lower rake',
                                    maxLines: 1,
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: Size.fromHeight(buttonHeight),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                    ),
                                  ),
                                ),
                                if (state.isPlantingLocked) ...[
                                  SizedBox(height: gap),
                                  FilledButton.icon(
                                    onPressed: controller.emergencyStop,
                                    icon: const Icon(
                                      Icons.emergency_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Emergency stop'),
                                    style: FilledButton.styleFrom(
                                      minimumSize:
                                          Size.fromHeight(buttonHeight),
                                      backgroundColor: AppColors.danger,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                                SizedBox(height: gap),
                                _ConnectivitySummary(
                                  roverConnected: state.isConnected,
                                  wifiConnected: state.localWifiConnected,
                                  connecting: state.localWifiConnecting,
                                  pingRoundTripMs: state.pingRoundTripMs,
                                  onConnect: controller.connectLocalWifi,
                                  onDisconnect: () => _confirmDisconnectRover(
                                    context,
                                    controller,
                                  ),
                                  disconnecting: state.localWifiDisconnecting,
                                  canDisconnect: !state.isPlantingLocked,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (telemetry.isSimulated) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: _SimulationBadge(),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    CameraPreviewPanel(
                      connected: state.localWifiConnected,
                      loading: false,
                      canView: canViewCamera,
                      cameraBaseUrl: environment.cameraBaseUrl,
                      onCameraStatusChanged: _handleCameraStatus,
                      fullscreen: state.cameraFullscreen,
                      onFullscreenToggle: () => _toggleLandscapeControls(
                        controller,
                        state.cameraFullscreen,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _ConnectivitySummary(
                      roverConnected: state.isConnected,
                      wifiConnected: state.localWifiConnected,
                      connecting: state.localWifiConnecting,
                      pingRoundTripMs: state.pingRoundTripMs,
                      onConnect: controller.connectLocalWifi,
                      onDisconnect: () => _confirmDisconnectRover(
                        context,
                        controller,
                      ),
                      disconnecting: state.localWifiDisconnecting,
                      canDisconnect: !state.isPlantingLocked,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _PortraitAutoPlantCard(
                      state: state,
                      controller: controller,
                      canControlPlanting: canControlPlanting,
                      canUseControls: canUseControls,
                      canPlantNextRow: canPlantNextRow,
                      onReviewPendingSession: state.pendingConfirmationSessionId != null &&
                              state.plantingOperation != null
                          ? () => _askWhetherAnythingWasPlanted(
                                context,
                                ref,
                                controller,
                                state.plantingOperation!,
                              )
                          : null,
                      onStartAutomaticRow: (seed, points) async {
                        final defaults = PlantingRowConfig.defaults(seed);
                        final config = PlantingRowConfig(
                          sessionId: defaults.sessionId,
                          seed: seed,
                          fieldLabel: state.activePlantingConfig?.fieldLabel.isNotEmpty == true
                              ? state.activePlantingConfig!.fieldLabel
                              : 'Field 1',
                          targetDrops: points,
                          spacingCm: defaults.spacingCm,
                          rowSpacingCm: defaults.rowSpacingCm,
                          gateOpenMs: defaults.gateOpenMs,
                          rakeOffsetCm: defaults.rakeOffsetCm,
                        );
                        await _runPlantingPrecheck(
                          this.context,
                          controller,
                          config,
                          returnToLandscape: false,
                        );
                      },
                      onSetupPlanting: () => _showPlantingConfiguration(
                        this.context,
                        controller,
                        state.selectedSeed,
                        returnToLandscape: false,
                      ),
                      onPlantNextRow: () => _confirmRoverAction(
                        this.context,
                        title: 'Plant the next row',
                        message:
                            'Start another supervised planting run in ${state.activePlantingConfig?.fieldLabel ?? 'the selected field'}?',
                        confirmLabel: 'Plant next row',
                        onConfirm: () async {
                          final nextConfiguration =
                              state.activePlantingConfig?.nextRow();
                          if (nextConfiguration == null) return;
                          await _runPlantingPrecheck(
                            this.context,
                            controller,
                            nextConfiguration,
                            returnToLandscape: false,
                            nextRow: true,
                          );
                        },
                      ),
                      onRetrySync: () =>
                          _retryPlantingSync(this.context, controller),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _LastSensorReadPanel(sensors: telemetry.sensors),
                    const SizedBox(height: AppSpacing.md),
                    const _PendingSyncQueue(),
                    if (state.errorMessage != null &&
                        !state.errorMessage!.toLowerCase().startsWith(
                            'reconnect before sending commands')) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _InfoNotice(
                        icon: Icons.info_outline,
                        message: state.errorMessage!,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _retryPlantingSync(
    BuildContext context,
    RoverControlController controller,
  ) async {
    await showPlantingSyncProgressDialog(
      context,
      synchronize: controller.synchronizePendingReceipts,
    );
    ref.invalidate(plantingRunsAwaitingSyncProvider);
    final syncError = ref.read(roverControlControllerProvider).errorMessage;
    if (syncError != null && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(syncError)));
    }
  }

  Future<void> _confirmDisconnectRover(
    BuildContext context,
    RoverControlController controller,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Disconnect from SeedRover?'),
        content: const Text(
          'The rover will stop if it is moving, then its Wi-Fi connection will end. Reconnect before sending more commands.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await controller.disconnectLocalWifi();
    }
  }

  Future<void> _askWhetherAnythingWasPlanted(
    BuildContext context,
    WidgetRef ref,
    RoverControlController controller,
    PlantingOperationStatus operation,
  ) async {
    final fullRowCompleted = operation.targetDrops > 0 &&
        operation.completedDrops >= operation.targetDrops;
    final outcome = await showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm planting result'),
        content: Text(
          '${operation.completedDrops} of ${operation.targetDrops} planting cycles were acknowledged. Did planting take place?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('none_planted'),
            child: const Text('Not planted'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              fullRowCompleted ? 'row_planted' : 'some_planted',
            ),
            child: const Text('Planted'),
          ),
        ],
      ),
    );
    if (outcome != null) {
      final saved = await controller.confirmPendingPlanting(operation.sessionId,
          outcome: outcome);
      ref.invalidate(plantingRunsAwaitingSyncProvider);
      if (!saved && context.mounted) {
        await _askWhetherAnythingWasPlanted(
            context, ref, controller, operation);
      }
    } else {
      await controller.confirmPendingPlanting(
        operation.sessionId,
        outcome: fullRowCompleted
            ? 'row_planted'
            : (operation.completedDrops > 0 ? 'some_planted' : 'none_planted'),
      );
      ref.invalidate(plantingRunsAwaitingSyncProvider);
    }
  }

  Future<void> _showPlantingConfiguration(
    BuildContext context,
    RoverControlController controller,
    PlantingSeedType selectedSeed, {
    required bool returnToLandscape,
  }) async {
    if (returnToLandscape) {
      await _toggleLandscapeControls(controller, true);
      if (!context.mounted) return;
    }

    PlantingRowConfig? configuration;
    try {
      configuration = await showModalBottomSheet<PlantingRowConfig>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _PlantingSetupSheet(
          initialSeed: selectedSeed,
        ),
      );
    } finally {
      if (returnToLandscape && context.mounted) {
        await _toggleLandscapeControls(controller, false);
      }
    }
    final confirmedConfiguration = configuration;
    if (confirmedConfiguration != null && context.mounted) {
      await _runPlantingPrecheck(
        context,
        controller,
        confirmedConfiguration,
        returnToLandscape: returnToLandscape,
      );
    }
  }

  Future<void> _runPlantingPrecheck(
    BuildContext context,
    RoverControlController controller,
    PlantingRowConfig configuration, {
    required bool returnToLandscape,
    bool nextRow = false,
  }) async {
    if (returnToLandscape) {
      await _toggleLandscapeControls(controller, true);
    }

    PlantingSoilPrecheck? confirmedReadings;
    try {
      final initialReadings = await controller.precheckPlantingSoil();
      if (!context.mounted) return;
      confirmedReadings = await showModalBottomSheet<PlantingSoilPrecheck>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _PlantingSoilPrecheckSheet(
          initialReadings: initialReadings,
          seed: configuration.seed,
          fieldLabel: configuration.fieldLabel,
          onRetry: controller.precheckPlantingSoil,
        ),
      );
    } finally {
      if (returnToLandscape && context.mounted) {
        await _toggleLandscapeControls(controller, false);
      }
    }

    if (confirmedReadings == null) {
      await controller.cancelPlantingSoilPrecheck();
      return;
    }
    if (!context.mounted) return;
    if (nextRow) {
      await controller.plantNextRow(soilPrecheck: confirmedReadings);
    } else {
      await controller.startPlanting(
        configuration,
        soilPrecheck: confirmedReadings,
      );
    }
  }

  Future<void> _showSensorReadingSheet(
      BuildContext context,
      RoverControlController roverController,
      List<CropModel> crops,
      CropMonitoringController cropController,
      {required bool returnToLandscape}) async {
    if (returnToLandscape) {
      await _toggleLandscapeControls(roverController, true);
      if (!context.mounted) return;
    }
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _CropSensorReadingSheet(
          crops: crops,
          onRead: roverController.checkCropSensors,
          onLoadCalibration: roverController.loadCalibration,
          onSave: cropController.recordRoverSensorCheck,
        ),
      );
    } finally {
      if (returnToLandscape && context.mounted) {
        await _toggleLandscapeControls(roverController, false);
      }
    }
  }


  void _confirmRoverAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Future<void> Function() onConfirm,
    Color? confirmColor,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return _RoverConfirmationDialog(
          title: title,
          message: message,
          confirmLabel: confirmLabel,
          confirmColor: confirmColor ?? AppColors.primaryGreen,
          onConfirm: () {
            Navigator.of(dialogContext).pop();
            onConfirm();
          },
        );
      },
    );
  }
}

Future<void> _showPlantingWorkflowGuideModal(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.primaryBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => const _PlantingWorkflowGuideSheet(),
  );
}

class _PlantingWorkflowGuideSheet extends StatelessWidget {
  const _PlantingWorkflowGuideSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xs,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alt_route_rounded,
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Autonomous 2-Pass Planting',
                        style: AppTypography.sectionHeading,
                      ),
                      Text(
                        'How the Rover Scouts & Plants Your Row',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'The rover moves forward first to survey the row and rake the furrow, then reverses back to the starting line before dropping any seeds. This ensures exact dynamic spacing and proper seed burial.',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primaryText,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'STEP-BY-STEP WORKFLOW',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _WorkflowStepCard(
              stepNumber: '1',
              title: 'Phase 1: Scout Row & Rake Furrow',
              badgeLabel: 'FORWARD DRIVE',
              badgeColor: Color(0xFF246B45),
              icon: Icons.arrow_forward_rounded,
              toolsStatus: 'Rake DOWN · Flattener UP · Dispenser OFF',
              description:
                  'The rover lowers the rake into the soil and drives forward to till the furrow line. Meanwhile, the front ultrasonic sensor measures the bed length until it detects the end wall (≤ 5 cm) or reaches the 4 ft max distance.',
              highlight: 'Result: Measures row length & cuts the planting furrow.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _WorkflowStepCard(
              stepNumber: '2',
              title: 'Phase 1 (Return): Reverse to Start Position',
              badgeLabel: 'REVERSING',
              badgeColor: Color(0xFF9A6A00),
              icon: Icons.arrow_back_rounded,
              toolsStatus: 'Rake UP · Flattener UP · Tools Raised',
              description:
                  'The rover lifts the rake UP to avoid dragging backward through the furrow, then automatically reverses along the exact same path back to the starting line (0 cm).',
              highlight: 'Result: Robot is at origin, ready to deposit seeds.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _WorkflowStepCard(
              stepNumber: '3',
              title: 'Phase 2: Plant Seeds & Flatten Furrow',
              badgeLabel: 'FORWARD PLANTING',
              badgeColor: Color(0xFF246B45),
              icon: Icons.grain_rounded,
              toolsStatus: 'Seed Gate Active · Flattener DOWN · Rake UP',
              description:
                  'The rover lowers the flattener and moves forward covering the surveyed row. At each dynamically calculated drop station, it stops, flash-opens the seed hatch for 1.0s, and covers the seeds with the flattener as it advances.',
              highlight: 'Result: Seeds dropped at even intervals and buried with soil.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const _WorkflowStepCard(
              stepNumber: '4',
              title: 'Phase 3: Row Completion & Safe Park',
              badgeLabel: 'COMPLETED',
              badgeColor: Color(0xFF1565C0),
              icon: Icons.check_circle_outline_rounded,
              toolsStatus: 'Motors STOP · Flattener UP · Tools Home',
              description:
                  'After the last seed, the flattener smooths the soil to the end of the bed. The rover stops motors, lifts all tools, and signals completion to your phone.',
              highlight: 'Row finished safely and ready for the next row!',
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryGreen),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Operator Tips',
                        style: AppTypography.small.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Place a cardboard or wooden board at the end of the bed so the front sensor detects the exact boundary.\n'
                    '• Do not push or pull the rover during the reverse phase—it tracks its own reverse return automatically.\n'
                    '• Ensure the path between start and end wall is clear of garden hoses and obstacles.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryText,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it, ready to plant'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowStepCard extends StatelessWidget {
  const _WorkflowStepCard({
    required this.stepNumber,
    required this.title,
    required this.badgeLabel,
    required this.badgeColor,
    required this.icon,
    required this.toolsStatus,
    required this.description,
    required this.highlight,
  });

  final String stepNumber;
  final String title;
  final String badgeLabel;
  final Color badgeColor;
  final IconData icon;
  final String toolsStatus;
  final String description;
  final String highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNumber,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.small.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  badgeLabel,
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(icon, size: 14, color: badgeColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  toolsStatus,
                  style: AppTypography.caption.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            highlight,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantingSetupSheet extends StatefulWidget {
  const _PlantingSetupSheet({
    required this.initialSeed,
  });

  final PlantingSeedType initialSeed;

  @override
  State<_PlantingSetupSheet> createState() => _PlantingSetupSheetState();
}

class _PlantingSetupSheetState extends State<_PlantingSetupSheet> {
  static const _fieldOptions = [
    'Field 1',
    'Field 2',
    'Field 3',
    'Field 4',
    'Field 5',
  ];
  final _formKey = GlobalKey<FormState>();
  late PlantingSeedType _seed = widget.initialSeed;
  late final TextEditingController _pointsController;
  String? _fieldSelection;
  bool _reviewing = false;

  @override
  void initState() {
    super.initState();
    _pointsController = TextEditingController(
      text:
          PlantingRowConfig.defaults(widget.initialSeed).targetDrops.toString(),
    );
    _pointsController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .76,
        minChildSize: .52,
        maxChildSize: .94,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: _reviewing
              ? _buildReview()
              : Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Set up auto-planting',
                                    style: AppTypography.sectionHeading),
                                const SizedBox(height: 2),
                                Text(
                                  '2-Pass Autonomous Survey & Planting',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primaryGreen,
                            ),
                            tooltip: 'How auto-planting works',
                            onPressed: () => _showPlantingWorkflowGuideModal(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      InkWell(
                        onTap: () => _showPlantingWorkflowGuideModal(context),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs + 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(color: AppColors.primaryBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.alt_route_rounded,
                                size: 18,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  '1. Scout & Rake ➔ 2. Return to Start ➔ 3. Plant',
                                  style: AppTypography.caption.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryText,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: AppColors.mutedText,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _FormFieldLabel(label: 'Seed variant', requiredField: true),
                      AppSelector<PlantingSeedType>(
                        value: _seed,
                        decoration: _fieldDecoration('Choose a seed variant'),
                        items: [
                          for (final seed in PlantingSeedType.values)
                            DropdownMenuItem(
                              value: seed,
                              child: Text(
                                switch (seed) {
                                  PlantingSeedType.sitaw => 'Sitaw (Gate 2 · 70 cm spacing)',
                                  PlantingSeedType.peanut => 'Peanut (Gate 3 · 60 cm spacing)',
                                  PlantingSeedType.calamansi => 'Calamansi (Gate 1 · 60 cm spacing)',
                                },
                              ),
                            ),
                        ],
                        onChanged: (seed) {
                          if (seed == null) return;
                          setState(() {
                            _seed = seed;
                            _pointsController.text =
                                PlantingRowConfig.defaults(seed)
                                    .targetDrops
                                    .toString();
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _FormFieldLabel(
                          label: 'Field or bed', requiredField: true),
                      AppSelector<String>(
                        value: _fieldSelection,
                        decoration: _fieldDecoration('Choose a field'),
                        items: [
                          for (final field in _fieldOptions)
                            DropdownMenuItem(value: field, child: Text(field)),
                        ],
                        onChanged: (value) => setState(
                          () => _fieldSelection = value,
                        ),
                        validator: (value) => value == null
                            ? 'Choose a field for this planting run.'
                            : null,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _FormFieldLabel(
                          label: 'Seeds to plant (Drops)', requiredField: true),
                      Row(
                        children: [
                          IconButton.outlined(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: () {
                              final current = int.tryParse(_pointsController.text) ?? 5;
                              if (current > 1) {
                                _pointsController.text = (current - 1).toString();
                              }
                            },
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: TextFormField(
                              controller: _pointsController,
                              style: AppTypography.numericInput,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(2),
                              ],
                              decoration: _fieldDecoration(
                                'Number of seeds',
                                hint: 'Default 5 · max 20',
                              ),
                              validator: (value) {
                                final points = int.tryParse(value ?? '');
                                if (points == null || points < 1 || points > 20) {
                                  return 'Enter between 1 and 20 seeds.';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          IconButton.outlined(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: () {
                              final current = int.tryParse(_pointsController.text) ?? 5;
                              if (current < 20) {
                                _pointsController.text = (current + 1).toString();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Live Dynamic Distance Preview Card
                      Builder(
                        builder: (context) {
                          final points = int.tryParse(_pointsController.text) ?? 5;
                          final defaults = PlantingRowConfig.defaults(_seed);
                          final totalDistanceCm = points * defaults.spacingCm;
                          final totalDistanceM = totalDistanceCm / 100.0;
                          final gateNumber = switch (_seed) {
                            PlantingSeedType.calamansi => 1,
                            PlantingSeedType.sitaw => 2,
                            PlantingSeedType.peanut => 3,
                          };
                          final pinNumber = switch (_seed) {
                            PlantingSeedType.calamansi => 'GPIO 27',
                            PlantingSeedType.sitaw => 'GPIO 4',
                            PlantingSeedType.peanut => 'GPIO 23',
                          };
                          return Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: AppColors.primaryGreen.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.straighten_outlined,
                                      size: 18,
                                      color: AppColors.primaryGreen,
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      'Calculated Distance: ${totalDistanceM.toStringAsFixed(2)} m (${totalDistanceCm.toStringAsFixed(0)} cm)',
                                      style: AppTypography.small.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '• $points seeds × ${defaults.spacingCm.toStringAsFixed(0)} cm recommended plant spacing\n'
                                  '• Dispenser: Gate $gateNumber ($pinNumber · ${_seed.label})\n'
                                  '• Autonomous Workflow:\n'
                                  '   1. Rover rakes furrow & measures field distance with USDS\n'
                                  '   2. Reverses back to starting origin (rake returns to default angle)\n'
                                  '   3. Auto-plants $points seeds with flattener DOWN to flat raked soil\n'
                                  '   4. Completes row at the end of the field',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primaryText,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Review auto-planting'),
                      ),
                    ],
                  ),
                ),
        ),
      );

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _reviewing = true);
  }

  Widget _buildReview() {
    final defaults = PlantingRowConfig.defaults(_seed);
    final targetDrops = int.parse(_pointsController.text);
    final configuration = PlantingRowConfig(
      sessionId: defaults.sessionId,
      seed: _seed,
      fieldLabel: _fieldSelection!,
      targetDrops: targetDrops,
      spacingCm: defaults.spacingCm,
      rowSpacingCm: defaults.rowSpacingCm,
      gateOpenMs: defaults.gateOpenMs,
      rakeOffsetCm: defaults.rakeOffsetCm,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review auto-planting', style: AppTypography.sectionHeading),
        const SizedBox(height: AppSpacing.md),
        _PlantingReviewRow(label: 'Seed variant', value: configuration.seed.label),
        _PlantingReviewRow(
            label: 'Field or bed', value: configuration.fieldLabel),
        _PlantingReviewRow(
          label: 'Seeds to plant',
          value: '${configuration.targetDrops} seeds',
        ),
        _PlantingReviewRow(
          label: 'Plant spacing',
          value: '${configuration.spacingCm.toStringAsFixed(0)} cm',
        ),
        _PlantingReviewRow(
          label: 'Calculated distance',
          value: '${configuration.totalDistanceM.toStringAsFixed(2)} m (${configuration.totalDistanceCm.toStringAsFixed(0)} cm)',
        ),
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primaryBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. Soil pre-check: moisture & temperature verified.\n'
                '2. Forward pass: Rake DOWN to till furrow & measure bed distance.\n'
                '3. Reverse pass: Rake UP, returns to starting line (0 cm).\n'
                '4. Planting pass: Flattener DOWN, dispenses seeds & covers furrow.',
                style: AppTypography.caption.copyWith(color: AppColors.primaryText, height: 1.4),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => _showPlantingWorkflowGuideModal(context),
                child: Text(
                  'Tap here to view full 2-pass workflow guide ➔',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(
          onPressed: () => setState(() => _reviewing = false),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit setup'),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, configuration),
          icon: const Icon(Icons.agriculture_outlined),
          label: const Text('Check soil & start auto-plant'),
        ),
      ],
    );
  }
}

class _PlantingSoilPrecheckSheet extends StatefulWidget {
  const _PlantingSoilPrecheckSheet({
    required this.initialReadings,
    required this.seed,
    required this.fieldLabel,
    required this.onRetry,
  });

  final PlantingSoilPrecheck initialReadings;
  final PlantingSeedType seed;
  final String fieldLabel;
  final Future<PlantingSoilPrecheck> Function() onRetry;

  @override
  State<_PlantingSoilPrecheckSheet> createState() =>
      _PlantingSoilPrecheckSheetState();
}

class _PlantingSoilPrecheckSheetState
    extends State<_PlantingSoilPrecheckSheet> {
  late PlantingSoilPrecheck _readings = widget.initialReadings;
  bool _retrying = false;
  Timer? _freshnessTimer;

  PlantingConditionAssessment get _assessment =>
      PlantingConditionAssessment.evaluate(
        seed: widget.seed,
        readings: _readings,
        assessedAt: DateTime.now(),
      );

  @override
  void initState() {
    super.initState();
    _watchFreshness();
  }

  void _watchFreshness() {
    _freshnessTimer?.cancel();
    final capturedAt = _readings.sampledAt;
    if (capturedAt == null) return;
    final remaining =
        capturedAt.add(const Duration(seconds: 60)).difference(DateTime.now());
    if (remaining <= Duration.zero) return;
    _freshnessTimer = Timer(remaining, () {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    super.dispose();
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    try {
      final readings = await widget.onRetry();
      if (!mounted) return;
      setState(() => _readings = readings);
      _watchFreshness();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .58,
        maxChildSize: .96,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Review planting conditions',
                  style: AppTypography.sectionHeading),
              const SizedBox(height: AppSpacing.xs),
              Text('${widget.seed.label} · ${widget.fieldLabel}',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryText,
                  )),
              if (_readings.sampledAt != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Read ${_readings.sampledAt!.toLocal().toString().substring(0, 16)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _AssessmentSummaryCard(assessment: _assessment),
              if (_assessment.score case final score?) ...[
                const SizedBox(height: AppSpacing.sm),
                _ConditionsMatchCard(
                  score: score,
                  matchedChecks: _assessment.matchedChecks!,
                  checkCount: _assessment.checkCount,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              _PlantingAdviceReadingCard(
                label: 'Soil moisture',
                icon: Icons.water_drop_outlined,
                value: _readings.soilMoisturePercent == null
                    ? 'Unavailable'
                    : '${_readings.soilMoisturePercent!.toStringAsFixed(1)}%',
                status: _readings.moistureCalibrated
                    ? _readings.diagnosis.label
                    : 'Unavailable',
                advice: _assessment.moistureAdvice,
                color: const Color(0xFF3D82A8),
                warning: _assessment.hasMoistureConcern,
              ),
              const SizedBox(height: AppSpacing.xs),
              _PlantingAdviceReadingCard(
                label: 'Soil temperature',
                icon: Icons.thermostat_outlined,
                value: _readings.soilTemperatureC == null
                    ? 'Unavailable'
                    : '${_readings.soilTemperatureC!.toStringAsFixed(1)}°C',
                status: widget.seed == PlantingSeedType.peanut
                    ? _assessment.temperatureGuidance
                    : 'Guidance limited',
                advice: _assessment.soilTemperatureAdvice,
                color: const Color(0xFFC47731),
                warning: _readings.soilTemperatureC != null &&
                    widget.seed == PlantingSeedType.peanut &&
                    (_readings.soilTemperatureC! < 20 ||
                        _readings.soilTemperatureC! > 30),
              ),
              const SizedBox(height: AppSpacing.xs),
              _PlantingAdviceReadingCard(
                label: 'Air temperature',
                icon: Icons.air_rounded,
                value: _readings.airTemperatureC == null
                    ? 'Unavailable'
                    : '${_readings.airTemperatureC!.toStringAsFixed(1)}°C',
                status: _readings.airTemperatureC == null
                    ? 'Reading needed'
                    : 'Read together with humidity',
                advice: 'Shows the current atmosphere around this spot.',
                color: const Color(0xFF6685B8),
              ),
              const SizedBox(height: AppSpacing.xs),
              _PlantingAdviceReadingCard(
                label: 'Humidity',
                icon: Icons.water_outlined,
                value: _readings.humidityPercent == null
                    ? 'Unavailable'
                    : '${_readings.humidityPercent!.toStringAsFixed(0)}%',
                status: _readings.humidityPercent == null
                    ? 'Reading needed'
                    : 'Read together with air temperature',
                advice: _assessment.environmentAdvice,
                color: const Color(0xFF548C75),
              ),
              const SizedBox(height: AppSpacing.sm),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: AppSpacing.sm),
                title: const Text('Why this result?'),
                subtitle: const Text('How the readings are reviewed'),
                children: [
                  _AssessmentWhyDetails(
                    assessment: _assessment,
                    seed: widget.seed,
                    readings: _readings,
                  ),
                ],
              ),
              if (!_readings.isValid || !_readings.isFreshAt(DateTime.now()))
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 20,
                        color: Color(0xFF9A5B12),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          !_readings.isFreshAt(DateTime.now())
                              ? 'Reading expired. Retry before proceeding.'
                              : _readings.unavailableReason,
                          style: AppTypography.small.copyWith(
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed:
                          _retrying ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _retrying ? null : _retry,
                      icon: _retrying
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              FilledButton(
                onPressed: _retrying
                    ? null
                    : () => Navigator.of(context).pop(_readings),
                child: Text(_assessment.score == 100
                    ? 'Start planting'
                    : _readings.isValid
                        ? (_assessment.hasMoistureConcern ||
                                _assessment.summary == 'Conditions need attention'
                            ? 'Start anyway'
                            : 'Start with available readings')
                        : 'Start anyway (bypass soil checks)'),
              ),
            ],
          ),
        ),
      );
}

class _AssessmentSummaryCard extends StatelessWidget {
  const _AssessmentSummaryCard({required this.assessment});

  final PlantingConditionAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final attention = assessment.hasMoistureConcern ||
        assessment.summary == 'Conditions need attention';
    final color = attention
        ? AppColors.warning
        : assessment.isComplete
            ? AppColors.success
            : AppColors.mutedText;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            attention
                ? Icons.warning_amber_rounded
                : assessment.isComplete
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(assessment.summary,
                    style: AppTypography.body.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConditionsMatchCard extends StatelessWidget {
  const _ConditionsMatchCard({
    required this.score,
    required this.matchedChecks,
    required this.checkCount,
  });

  final int score;
  final int matchedChecks;
  final int checkCount;

  @override
  Widget build(BuildContext context) {
    final progress = (score / 100).clamp(0.0, 1.0);
    return Semantics(
      label:
          'Conditions match: $score percent. $matchedChecks of $checkCount soil checks matched.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Conditions match', style: AppTypography.body),
                ),
                Text('$score%',
                    style: AppTypography.numericValue.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryGreen,
                    )),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: AppColors.primaryBorder,
                color: AppColors.primaryGreen,
                semanticsLabel: 'Conditions match',
                semanticsValue: '$score percent',
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$matchedChecks of $checkCount soil checks matched · moisture and soil temperature',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
            Text(
              'A share of supported checks, not a success probability.',
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantingAdviceReadingCard extends StatelessWidget {
  const _PlantingAdviceReadingCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.status,
    required this.advice,
    required this.color,
    this.warning = false,
  });

  final String label;
  final IconData icon;
  final String value;
  final String status;
  final String advice;
  final Color color;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final stateColor = warning ? AppColors.warning : color;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: stateColor.withValues(alpha: .42)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: stateColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: 2,
                  children: [
                    Text(label,
                        style: AppTypography.small.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                    Text(value,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        )),
                  ],
                ),
                const SizedBox(height: 2),
                Text(status,
                    style: AppTypography.caption.copyWith(
                      color: stateColor,
                      fontWeight: FontWeight.w600,
                    )),
                if (advice.isNotEmpty && advice != status) ...[
                  const SizedBox(height: 2),
                  Text(advice,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.secondaryText,
                      )),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssessmentWhyDetails extends StatelessWidget {
  const _AssessmentWhyDetails({
    required this.assessment,
    required this.seed,
    required this.readings,
  });

  final PlantingConditionAssessment assessment;
  final PlantingSeedType seed;
  final PlantingSoilPrecheck readings;

  @override
  Widget build(BuildContext context) {
    final source = switch (seed) {
      PlantingSeedType.peanut =>
        'ARC groundnut guidance: https://www.arc.agric.za/arc-iscw/CSA-Toolbox/Pages/assets/modules/4.pdf',
      PlantingSeedType.sitaw =>
        'PROSEA yardlong bean guidance: https://prosea.prota4u.org/view.aspx?id=2210',
      PlantingSeedType.calamansi =>
        'No direct-seeding temperature source is used because a crop-specific range is incomplete.',
    };
    final vpd = assessment.vaporPressureDeficitKpa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Local assessment rules ${PlantingConditionAssessment.ruleVersion}',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(assessment.temperatureGuidance,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: AppSpacing.xs),
        SelectableText(source, style: AppTypography.caption),
        const SizedBox(height: AppSpacing.sm),
        Text(
          vpd == null
              ? 'Atmospheric drying demand (VPD) is unavailable without valid air temperature and humidity.'
              : 'Current atmospheric drying demand (VPD): ${vpd.toStringAsFixed(2)} kPa. Calculated from air temperature and relative humidity using the FAO saturation-vapour-pressure method.',
          style: AppTypography.caption.copyWith(
            color: AppColors.secondaryText,
          ),
        ),
        if (vpd != null) ...[
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            'FAO method: https://www.fao.org/4/x0490e/x0490e07.htm',
            style: AppTypography.caption,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        for (final limitation in assessment.limitations)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('• $limitation', style: AppTypography.caption),
          ),
      ],
    );
  }
}

class _SoilMoistureDiagnosisCard extends StatelessWidget {
  const _SoilMoistureDiagnosisCard({required this.diagnosis});

  final SoilMoistureDiagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    final color = switch (diagnosis.kind) {
      SoilMoistureDiagnosisKind.good => AppColors.success,
      SoilMoistureDiagnosisKind.tooDry ||
      SoilMoistureDiagnosisKind.tooWet =>
        AppColors.danger,
      SoilMoistureDiagnosisKind.unavailable => AppColors.mutedText,
    };
    final icon = switch (diagnosis.kind) {
      SoilMoistureDiagnosisKind.good => Icons.check_circle_outline_rounded,
      SoilMoistureDiagnosisKind.tooDry ||
      SoilMoistureDiagnosisKind.tooWet =>
        Icons.warning_amber_rounded,
      SoilMoistureDiagnosisKind.unavailable => Icons.help_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  diagnosis.label,
                  style: AppTypography.small.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlantingReviewRow extends StatelessWidget {
  const _PlantingReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.small.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: AppTypography.body.copyWith(
                  color: AppColors.primaryText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
}

class _CropSensorReadingSheet extends StatefulWidget {
  const _CropSensorReadingSheet({
    required this.crops,
    required this.onRead,
    required this.onLoadCalibration,
    required this.onSave,
  });

  final List<CropModel> crops;
  final Future<Map<String, dynamic>> Function() onRead;
  final Future<RoverCalibrationModel> Function() onLoadCalibration;
  final Future<String> Function({
    required String cropId,
    required Map<String, dynamic> readings,
  }) onSave;

  @override
  State<_CropSensorReadingSheet> createState() =>
      _CropSensorReadingSheetState();
}

class _CropSensorReadingSheetState extends State<_CropSensorReadingSheet> {
  String? _cropId;
  Map<String, dynamic>? _readings;
  SoilMoistureDiagnosis? _diagnosis;
  String? _error;
  bool _reading = false;
  bool _saving = false;

  CropModel? get _selectedCrop {
    for (final crop in widget.crops) {
      if (crop.id == _cropId) return crop;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _cropId = widget.crops.isEmpty ? null : widget.crops.first.id;
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .5,
        maxChildSize: .92,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Soil condition sensing',
                  style: AppTypography.sectionHeading),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Choose a crop ID. Its seed type and location will appear below.',
                style: AppTypography.small.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _FormFieldLabel(label: 'Crop ID', requiredField: true),
              AppSelector<String>(
                value: _cropId,
                decoration: _fieldDecoration('Select crop ID'),
                items: [
                  for (final crop in widget.crops)
                    DropdownMenuItem(
                      value: crop.id,
                      child: Text(
                        crop.trackingCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _readings == null
                    ? (value) => setState(() => _cropId = value)
                    : null,
              ),
              if (_selectedCrop case final crop?) ...[
                const SizedBox(height: AppSpacing.sm),
                _SelectedCropContext(crop: crop),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_error != null) ...[
                _InfoNotice(icon: Icons.error_outline, message: _error!),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_readings == null)
                FilledButton.icon(
                  onPressed: _reading || _cropId == null ? null : _read,
                  icon: _reading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sensors_outlined),
                  label: Text(_reading ? 'Reading sensors…' : 'Read sensors'),
                )
              else ...[
                _SensorResultCard(
                  readings: _readings!,
                  diagnosis:
                      _diagnosis ?? const SoilMoistureDiagnosis.unavailable(),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed:
                      _saving || !_hasAvailableValue(_readings!) ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save to crop sensors'),
                ),
                TextButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _readings = null;
                            _diagnosis = null;
                            _error = null;
                          }),
                  child: const Text('Read again'),
                ),
              ],
            ],
          ),
        ),
      );

  Future<void> _read() async {
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lower soil probe?'),
        content: const Text(
          'The soil probe will lower for a reading and then be commanded back up. Keep hands and tools clear of the mechanism.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Read sensors'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;
    setState(() {
      _reading = true;
      _error = null;
    });
    try {
      final readings = await widget.onRead();
      if (!mounted) return;
      if (!_hasAvailableValue(readings)) {
        throw StateError('No usable sensor values were returned.');
      }
      RoverCalibrationModel? calibration;
      try {
        calibration = await widget.onLoadCalibration();
      } catch (_) {
        // Keep the reading usable even if a reference-based diagnosis cannot load.
      }
      if (!mounted) return;
      final moistureCalibrated = readings['soil_moisture_calibrated'] == true &&
          (readings['calibration_version']?.toString().trim().isNotEmpty ??
              false);
      setState(() {
        _readings = readings;
        _diagnosis = moistureCalibrated
            ? SoilMoistureDiagnosis.fromRawReading(
                raw: (readings['soil_raw'] as num?)?.toInt(),
                dryReferenceRaw: calibration?.soilDryRaw,
                moistReferenceRaw: calibration?.soilWetRaw,
              )
            : const SoilMoistureDiagnosis.unavailable();
      });
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  Future<void> _save() async {
    final cropId = _cropId;
    final readings = _readings;
    if (cropId == null || readings == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final message = await widget.onSave(cropId: cropId, readings: readings);
      if (!mounted) return;
      if (message.startsWith('Sensor reading saved')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        Navigator.of(context).pop();
      } else {
        setState(() => _error = message);
      }
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Bad state: ', ''));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _hasAvailableValue(Map<String, dynamic> readings) {
    bool inRange(Object? value, num min, num max) =>
        value is num && value.isFinite && value >= min && value <= max;
    return inRange(readings['soil_raw'], 1, 4094) ||
        inRange(readings['soil_moisture_percent'], 0, 100) ||
        inRange(readings['soil_temperature_c'], -55, 125) ||
        inRange(readings['air_temperature_c'], -40, 80) ||
        inRange(readings['humidity_percent'], 0, 100);
  }
}

class _SelectedCropContext extends StatelessWidget {
  const _SelectedCropContext({required this.crop});

  final CropModel crop;

  @override
  Widget build(BuildContext context) {
    final variety = crop.variety.trim();
    final seedType = variety.isEmpty || variety.toLowerCase() == 'unknown'
        ? crop.name
        : '${crop.name} · $variety';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.inactiveBorder),
      ),
      child: Column(
        children: [
          _CropContextRow(
            icon: Icons.grass_outlined,
            label: 'Seed type',
            value: seedType,
          ),
          const SizedBox(height: AppSpacing.xs),
          _CropContextRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value:
                crop.location.trim().isEmpty ? 'Not recorded' : crop.location,
          ),
        ],
      ),
    );
  }
}

class _CropContextRow extends StatelessWidget {
  const _CropContextRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primaryGreen),
          const SizedBox(width: AppSpacing.xs),
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(
                color: AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.small.copyWith(
                color: AppColors.primaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}

class _SensorResultCard extends StatelessWidget {
  const _SensorResultCard({
    required this.readings,
    required this.diagnosis,
  });

  final Map<String, dynamic> readings;
  final SoilMoistureDiagnosis diagnosis;

  @override
  Widget build(BuildContext context) {
    final verified =
        (readings['firmware_version']?.toString().trim().isNotEmpty ?? false);
    final calibrated = readings['soil_moisture_calibrated'] == true &&
        (readings['calibration_version']?.toString().trim().isNotEmpty ??
            false);
    final capturedAt =
        DateTime.tryParse(readings['recorded_at']?.toString() ?? '')?.toLocal();
    String value(String key, String unit) {
      final reading = readings[key];
      return reading is num
          ? '${reading.toStringAsFixed(1)}$unit'
          : 'Unavailable';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        border: Border.all(color: AppColors.inactiveBorder),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(verified ? Icons.verified_outlined : Icons.info_outline,
                color: verified ? AppColors.success : AppColors.warning),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(verified ? 'Hardware reading' : 'Unverified reading',
                  style:
                      AppTypography.body.copyWith(fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: AppSpacing.sm),
          _SensorResultRow(
              label: 'Soil moisture',
              value: calibrated
                  ? value('soil_moisture_percent', '%')
                  : 'Unavailable'),
          const SizedBox(height: AppSpacing.sm),
          _SoilMoistureDiagnosisCard(diagnosis: diagnosis),
          _SensorResultRow(
              label: 'Raw soil reading',
              value: readings['soil_raw']?.toString() ?? 'Unavailable'),
          _SensorResultRow(
              label: 'Soil temperature',
              value: value('soil_temperature_c', ' °C')),
          _SensorResultRow(
              label: 'Air temperature',
              value: value('air_temperature_c', ' °C')),
          _SensorResultRow(
              label: 'Humidity', value: value('humidity_percent', '%')),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${readings['source'] ?? 'Source unavailable'} · ${capturedAt == null ? 'Time unavailable' : '${MaterialLocalizations.of(context).formatMediumDate(capturedAt)} ${TimeOfDay.fromDateTime(capturedAt).format(context)}'}',
            style: AppTypography.caption,
          ),
        ],
      ),
    );
  }
}

class _SensorResultRow extends StatelessWidget {
  const _SensorResultRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTypography.small)),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style:
                    AppTypography.small.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}


InputDecoration _fieldDecoration(String label, {String? hint}) =>
    InputDecoration(
      hintText: hint ?? label,
      border: const OutlineInputBorder(),
      isDense: true,
    );

class _RoverConfirmationDialog extends StatelessWidget {
  const _RoverConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
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
            Text(
              title,
              style: AppTypography.cardTitle.copyWith(
                color: AppColors.primaryText,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SeedRoverMascotMessage(
              message: message,
              expression: confirmColor == AppColors.danger
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
                  _RoverDialogButton(
                    label: 'Cancel',
                    color: AppColors.primaryText,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  _RoverDialogButton(
                    label: confirmLabel,
                    color: confirmColor,
                    icon: Icons.check,
                    onPressed: onConfirm,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoverDialogButton extends StatelessWidget {
  const _RoverDialogButton({
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
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
      icon: Icon(icon, size: 16, color: color),
      label: Text(label),
    );
  }
}

class _RoverLoadingSkeleton extends StatelessWidget {
  const _RoverLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            const Row(
              children: [
                SkeletonBlock(height: 28, width: 210),
                SizedBox(width: AppSpacing.md),
                SkeletonBlock(height: 18, width: 110),
                Spacer(),
                SkeletonBlock(height: 18, width: 150),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(
                    flex: 3,
                    child: SkeletonCard(
                      children: [
                        Spacer(),
                        Center(child: SkeletonBlock(height: 170, width: 170)),
                        Spacer(),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(
                          child: SkeletonCard(
                            children: [
                              SkeletonLine(widthFactor: 0.36),
                              SizedBox(height: AppSpacing.md),
                              Expanded(child: SkeletonBlock(height: 140)),
                            ],
                          ),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        SkeletonCard(
                          height: 86,
                          children: [
                            SkeletonLine(widthFactor: 0.7),
                            SizedBox(height: AppSpacing.sm),
                            SkeletonLine(widthFactor: 0.52),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(
                          child: SkeletonCard(
                            children: [
                              SkeletonLine(widthFactor: 0.45),
                              SizedBox(height: AppSpacing.md),
                              SkeletonLine(widthFactor: 0.82),
                              SizedBox(height: AppSpacing.sm),
                              SkeletonLine(widthFactor: 0.68),
                              SizedBox(height: AppSpacing.sm),
                              SkeletonLine(widthFactor: 0.74),
                            ],
                          ),
                        ),
                        SizedBox(height: AppSpacing.xs),
                        SkeletonCard(
                          height: 104,
                          children: [
                            SkeletonLine(widthFactor: 0.56),
                            SizedBox(height: AppSpacing.md),
                            SkeletonBlock(height: 36),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoNotice extends StatelessWidget {
  const _InfoNotice({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.skySurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.information, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: AppTypography.small)),
        ]),
      );
}

class _PendingSyncQueue extends ConsumerStatefulWidget {
  const _PendingSyncQueue();

  @override
  ConsumerState<_PendingSyncQueue> createState() => _PendingSyncQueueState();
}

class _PendingSyncQueueState extends ConsumerState<_PendingSyncQueue> {
  late Future<List<_PendingSyncItem>> _items;
  Timer? _refreshTimer;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _items = _loadItems();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _reload();
    });
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() => _items = _loadItems());
  }

  Future<List<_PendingSyncItem>> _loadItems() async {
    final roverController = ref.read(roverControlControllerProvider.notifier);
    final cropController = ref.read(cropMonitoringControllerProvider.notifier);
    final crops = ref.read(cropMonitoringControllerProvider).crops;
    final cropById = {for (final crop in crops) crop.id: crop};
    final records = await roverController.loadPlantingRecords();
    final sensorDrafts = await cropController.pendingSensorChecks();
    final careDrafts = await cropController.careDrafts();
    final items = <_PendingSyncItem>[];

    final pendingCalibration = await roverController.loadPendingCalibration();
    if (pendingCalibration != null) {
      items.add(const _PendingSyncItem(
        icon: Icons.tune_rounded,
        title: 'Soil moisture calibration',
        detail: 'Saved on rover and this phone · waiting to sync to cloud',
      ));
    }

    final seenSessions = <String>{};
    for (final record in records) {
      if (!record.status.isTerminal ||
          !record.isConfirmed ||
          record.confirmationSynced ||
          !seenSessions.add(record.config.sessionId)) {
        continue;
      }
      items.add(_PendingSyncItem(
        icon: Icons.agriculture_outlined,
        title:
            '${record.config.seed.label} · ${record.config.fieldLabel.isEmpty ? 'Field not set' : record.config.fieldLabel}',
        detail: record.syncError == null
            ? 'Planting confirmed · ${record.status.completedDrops}/${record.config.targetDrops} cycles · waiting to sync'
            : 'Sync failed · ${record.syncError}',
      ));
    }

    for (final draft in sensorDrafts) {
      final crop = cropById[draft['crop_id']?.toString()];
      final readings = Map<String, dynamic>.from(draft['readings'] as Map);
      final recordedAt = DateTime.tryParse(
        readings['recorded_at']?.toString() ?? '',
      )?.toLocal();
      final recordedLabel = recordedAt == null
          ? ''
          : '${recordedAt.month}/${recordedAt.day} ${recordedAt.hour.toString().padLeft(2, '0')}:${recordedAt.minute.toString().padLeft(2, '0')}';
      items.add(_PendingSyncItem(
        icon: Icons.sensors_outlined,
        title: 'Soil reading · ${crop?.trackingCode ?? crop?.name ?? 'Crop'}',
        detail:
            'Saved on this phone${recordedLabel.isEmpty ? '' : ' · $recordedLabel'} · waiting to sync',
      ));
    }

    for (final draft in careDrafts) {
      final status = draft['status']?.toString();
      if (status != 'Saved on device' && status != 'Syncing') continue;
      final crop = cropById[draft['crop_id']?.toString()];
      items.add(_PendingSyncItem(
        icon: Icons.edit_note_outlined,
        title:
            '${draft['activity_type'] ?? 'Crop activity'} · ${crop?.trackingCode ?? crop?.name ?? 'Crop'}',
        detail: 'Saved on this phone · waiting to sync',
      ));
    }
    return items;
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      await showPlantingSyncProgressDialog(
        context,
        title: 'Syncing saved records',
        message: 'Uploading records saved on this phone.',
        synchronize: () async {
          await ref
              .read(roverControlControllerProvider.notifier)
              .synchronizePendingReceipts();
          await ref
              .read(cropMonitoringControllerProvider.notifier)
              .retryPendingDrafts();
        },
      );
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
        _reload();
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<RoverControlState>(roverControlControllerProvider,
        (previous, next) {
      if (next.confirmedPlantingSessionId !=
              previous?.confirmedPlantingSessionId ||
          next.lastConfirmedSyncedSessionId !=
              previous?.lastConfirmedSyncedSessionId ||
          next.pendingReceiptCount != previous?.pendingReceiptCount) {
        _reload();
      }
      if (next.lastCommand == 'Rover calibration saved' &&
          previous?.lastCommand != next.lastCommand) {
        _reload();
      }
    });
    final roverSyncing =
        ref.watch(roverControlControllerProvider).syncingReceipts;
    return FutureBuilder<List<_PendingSyncItem>>(
      future: _items,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <_PendingSyncItem>[];
        return AppCard(
          backgroundColor: AppColors.secondaryBackground,
          borderColor: AppColors.inactiveBorder,
          radius: AppRadius.md,
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_sync_outlined,
                      color: AppColors.primaryGreen),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Sync queue',
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${items.length} waiting',
                    style: AppTypography.caption.copyWith(
                      color: items.isEmpty
                          ? AppColors.secondaryText
                          : AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh sync queue',
                    visualDensity: VisualDensity.compact,
                    onPressed:
                        snapshot.connectionState == ConnectionState.waiting
                            ? null
                            : _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const LinearProgressIndicator(minHeight: 2)
              else if (snapshot.hasError)
                Text(
                  'Could not load saved records.',
                  style: AppTypography.small.copyWith(
                    color: AppColors.secondaryText,
                  ),
                )
              else if (items.isEmpty)
                Text(
                  'No saved records are waiting to sync.',
                  style: AppTypography.small.copyWith(
                    color: AppColors.secondaryText,
                  ),
                )
              else ...[
                for (final item in items) ...[
                  const Divider(height: AppSpacing.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(item.icon, size: 19, color: AppColors.primaryGreen),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTypography.small.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              item.detail,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _syncing || roverSyncing ? null : _syncNow,
                    icon: _syncing || roverSyncing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded),
                    label: Text(
                      _syncing || roverSyncing ? 'Syncing…' : 'Sync now',
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PendingSyncItem {
  const _PendingSyncItem({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;
}

class _SimulationBadge extends StatelessWidget {
  const _SimulationBadge();

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Simulation mode. Readings and rover actions are simulated.',
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.skySurface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.science_outlined,
                color: AppColors.information, size: 16),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'Simulation',
              style: AppTypography.statusBadge.copyWith(
                color: AppColors.information,
              ),
            ),
          ]),
        ),
      );
}

class _LandscapePlantingPhaseNotice extends StatelessWidget {
  const _LandscapePlantingPhaseNotice({
    required this.status,
    required this.operation,
  });

  final PlantingStatus status;
  final PlantingOperationStatus? operation;

  @override
  Widget build(BuildContext context) {
    final distTraveled = operation?.distanceCm ?? 0.0;
    final frontDist = operation?.frontDistanceCm;
    final frontText = frontDist != null ? '${frontDist.toStringAsFixed(1)} cm' : 'Measuring...';
    final surveyedLength = operation?.surveyDistanceCm ?? operation?.detectedFieldDistanceCm ?? 0.0;
    final returnTraveled = operation?.returnDistanceCm ?? operation?.surveyReturnDistanceCm ?? 0.0;
    final completed = operation?.completedDrops ?? 0;
    final total = operation?.targetDrops ?? 5;
    final currentPoint = (completed + 1).clamp(1, total);

    final text = switch (status) {
      PlantingStatus.surveyingBed =>
        'Scouting & Raking Furrow: ${distTraveled.toStringAsFixed(1)} cm · Front Wall: $frontText',
      PlantingStatus.returningFromSurvey =>
        'Returning to Start: ${returnTraveled.toStringAsFixed(1)} cm of ${surveyedLength.toStringAsFixed(1)} cm',
      PlantingStatus.active || PlantingStatus.loweringRake =>
        'Planting Point $currentPoint of $total · Position: ${distTraveled.toStringAsFixed(1)} cm · Wall: $frontText',
      PlantingStatus.completed =>
        'Row Completed! ${operation?.totalForwardDistanceCm?.toStringAsFixed(1) ?? surveyedLength.toStringAsFixed(1)} cm covered',
      PlantingStatus.paused =>
        'Planting Paused at ${distTraveled.toStringAsFixed(1)} cm',
      _ => status.label,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.7), width: 1.2),
      ),
      child: Text(
        text,
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 11.5,
        ),
      ),
    );
  }
}

class _LiveAutonomousPlantingPhaseCard extends StatelessWidget {
  const _LiveAutonomousPlantingPhaseCard({
    required this.status,
    required this.operation,
    required this.targetDrops,
    required this.activeSeedLabel,
  });

  final PlantingStatus status;
  final PlantingOperationStatus? operation;
  final int targetDrops;
  final String activeSeedLabel;

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final String badgeText;
    final String primaryMessage;
    final String subMessage;
    final IconData phaseIcon;
    final List<_PhaseDistanceMetric> metrics;

    final distanceTraveled = operation?.distanceCm ?? 0.0;
    final frontUsds = operation?.frontDistanceCm;
    final frontUsdsText = frontUsds != null ? '${frontUsds.toStringAsFixed(1)} cm' : 'Scanning...';
    final surveyedLength = operation?.surveyDistanceCm ?? operation?.detectedFieldDistanceCm ?? 0.0;
    final returnTraveled = (status == PlantingStatus.returningFromSurvey)
        ? (operation?.surveyReturnDistanceCm != null && operation!.surveyReturnDistanceCm! > 0
            ? operation!.surveyReturnDistanceCm!
            : (operation?.returnDistanceCm ?? 0.0))
        : (operation?.returnDistanceCm ?? operation?.surveyReturnDistanceCm ?? 0.0);
    final completed = operation?.completedDrops ?? 0;
    final total = operation?.targetDrops ?? targetDrops;
    final currentPoint = (completed + 1).clamp(1, total);
    final spacing = operation?.calculatedSpacingCm ?? (surveyedLength > 0 ? surveyedLength / (total + 1) : 20.0);
    final targetPointDist = operation?.nextDropAtCm ?? (currentPoint * spacing);

    switch (status) {
      case PlantingStatus.surveyingBed:
        badgeColor = AppColors.primaryGreen;
        badgeText = 'PHASE 1: SCOUTING & RAKING';
        phaseIcon = Icons.arrow_forward_rounded;
        primaryMessage = 'Rover scouting forward & raking furrow';
        subMessage = 'Rear rake lowered · Front USDS measuring row distance';
        metrics = [
          _PhaseDistanceMetric(
            label: 'Traveled Forward',
            value: '${distanceTraveled.toStringAsFixed(1)} cm',
          ),
          _PhaseDistanceMetric(
            label: 'Front Wall (USDS)',
            value: frontUsdsText,
            highlight: true,
          ),
          const _PhaseDistanceMetric(
            label: 'Rake Status',
            value: 'DOWN (Tilling)',
          ),
        ];
        break;

      case PlantingStatus.returningFromSurvey:
        badgeColor = AppColors.warning;
        badgeText = 'PHASE 1: RETURNING TO ORIGIN';
        phaseIcon = Icons.arrow_back_rounded;
        primaryMessage = 'Rover returning to starting position';
        subMessage = 'Rake raised UP · Returning to 0 cm origin to begin planting';
        final remainingToOrigin = (surveyedLength - returnTraveled).clamp(0.0, 999.0);
        metrics = [
          _PhaseDistanceMetric(
            label: 'Reversed So Far',
            value: '${returnTraveled.toStringAsFixed(1)} cm',
          ),
          _PhaseDistanceMetric(
            label: 'Row Length Locked',
            value: surveyedLength > 0 ? '${surveyedLength.toStringAsFixed(1)} cm' : 'Measuring...',
            highlight: true,
          ),
          _PhaseDistanceMetric(
            label: 'Distance to Origin',
            value: '${remainingToOrigin.toStringAsFixed(1)} cm',
          ),
        ];
        break;

      case PlantingStatus.active:
      case PlantingStatus.loweringRake:
      case PlantingStatus.ready:
        badgeColor = AppColors.primaryGreen;
        badgeText = 'PHASE 2: PLANTING & FLATTENING';
        phaseIcon = Icons.grain_rounded;
        primaryMessage = 'Planting Point $currentPoint of $total ($activeSeedLabel)';
        subMessage = 'Soil flattener DOWN covering seeds into raked furrow';
        metrics = [
          _PhaseDistanceMetric(
            label: 'Rover Position',
            value: '${distanceTraveled.toStringAsFixed(1)} cm',
          ),
          _PhaseDistanceMetric(
            label: 'Drop Point Target',
            value: '${targetPointDist.toStringAsFixed(1)} cm',
            highlight: true,
          ),
          _PhaseDistanceMetric(
            label: 'Point Spacing',
            value: '${spacing.toStringAsFixed(1)} cm',
          ),
          _PhaseDistanceMetric(
            label: 'Front Wall (USDS)',
            value: frontUsdsText,
          ),
        ];
        break;

      case PlantingStatus.completed:
        badgeColor = AppColors.success;
        badgeText = 'ROW COMPLETED';
        phaseIcon = Icons.check_circle_outline_rounded;
        primaryMessage = 'Row Completed! All $total seeds planted and covered.';
        subMessage = 'All tools lifted UP · Ready for next row';
        metrics = [
          _PhaseDistanceMetric(
            label: 'Total Distance Covered',
            value: '${(operation?.totalForwardDistanceCm ?? surveyedLength).toStringAsFixed(1)} cm',
            highlight: true,
          ),
          _PhaseDistanceMetric(
            label: 'Seeds Planted',
            value: '$completed of $total seeds',
          ),
        ];
        break;

      case PlantingStatus.paused:
        badgeColor = AppColors.warning;
        badgeText = 'PAUSED SAFELY';
        phaseIcon = Icons.pause_circle_outline_rounded;
        primaryMessage = 'Planting paused';
        subMessage = 'Motors halted · Tap Resume to continue autonomous run';
        metrics = [
          _PhaseDistanceMetric(
            label: 'Position at Pause',
            value: '${distanceTraveled.toStringAsFixed(1)} cm',
          ),
          _PhaseDistanceMetric(
            label: 'Progress',
            value: '$completed of $total points',
          ),
        ];
        break;

      default:
        badgeColor = AppColors.secondaryText;
        badgeText = status.label.toUpperCase();
        phaseIcon = Icons.info_outline_rounded;
        primaryMessage = status.label;
        subMessage = 'Autonomous planting cycle active';
        metrics = [
          _PhaseDistanceMetric(
            label: 'Current Distance',
            value: '${distanceTraveled.toStringAsFixed(1)} cm',
          ),
        ];
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(phaseIcon, size: 13, color: badgeColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Text(
            primaryMessage,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subMessage,
            style: AppTypography.caption.copyWith(
              color: AppColors.secondaryText,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.primaryBorder),
            ),
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: 4,
              children: [
                for (final m in metrics)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m.label,
                          style: AppTypography.caption.copyWith(
                            fontSize: 9.5,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          m.value,
                          style: AppTypography.caption.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: m.highlight ? AppColors.primaryGreen : AppColors.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseDistanceMetric {
  const _PhaseDistanceMetric({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;
}

class _LivePlantingPhaseProgressTracker extends StatelessWidget {
  const _LivePlantingPhaseProgressTracker({
    required this.status,
    required this.operation,
    required this.targetDrops,
    required this.seedLabel,
    required this.gateNum,
  });

  final PlantingStatus status;
  final PlantingOperationStatus? operation;
  final int targetDrops;
  final String seedLabel;
  final int gateNum;

  @override
  Widget build(BuildContext context) {
    final distanceTraveled = operation?.distanceCm ?? 0.0;
    final completed = operation?.completedDrops ?? 0;
    final total = operation?.targetDrops ?? targetDrops;
    final defaultSpacing = operation?.calculatedSpacingCm ?? 70.0;
    final dynamicDefaultLength = (total > 0 ? total : 5) * defaultSpacing;
    final surveyedLength = operation?.detectedFieldDistanceCm ?? operation?.surveyDistanceCm ?? dynamicDefaultLength;
    final returnTraveled = (status == PlantingStatus.returningFromSurvey)
        ? (operation?.surveyReturnDistanceCm != null && operation!.surveyReturnDistanceCm! > 0
            ? operation!.surveyReturnDistanceCm!
            : (operation?.returnDistanceCm ?? 0.0))
        : (operation?.returnDistanceCm ?? operation?.surveyReturnDistanceCm ?? 0.0);
    final isDispensing = operation?.isDispensing == true || operation?.gateOpen == true;
    final currentPoint = (completed + 1).clamp(1, total).toInt();
    final spacing = operation?.calculatedSpacingCm ?? (surveyedLength > 0 ? surveyedLength / (total + 1) : defaultSpacing);
    final targetPointDist = operation?.nextDropAtCm ?? (currentPoint * spacing);
    final frontUsds = operation?.frontDistanceCm;
    final frontUsdsText = frontUsds != null ? '${frontUsds.toStringAsFixed(1)} cm' : '-- cm';

    // 1. PHASE 1: SCOUTING & RAKING (Moving forward)
    if (status == PlantingStatus.surveyingBed) {
      final maxBed = operation?.detectedFieldDistanceCm ?? surveyedLength;
      final forwardProgress = (distanceTraveled / maxBed).clamp(0.05, 1.0);
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'SCOUTING FORWARD & RAKING...',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${distanceTraveled.toStringAsFixed(1)} cm / ${maxBed.toStringAsFixed(1)} cm',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: forwardProgress,
              backgroundColor: AppColors.primaryBorder,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start (0.0 cm)',
                  style: AppTypography.caption.copyWith(fontSize: 10, color: AppColors.secondaryText),
                ),
                Text(
                  'Front Wall: $frontUsdsText',
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 2. RETURNING TO ORIGIN (Moving backwards after planting)
    if (status == PlantingStatus.returningFromSurvey || status == PlantingStatus.returningToStart) {
      final safeLength = (operation?.totalForwardDistanceCm != null && operation!.totalForwardDistanceCm! > 0)
          ? operation!.totalForwardDistanceCm!
          : (surveyedLength > 0 ? surveyedLength : 100.0);
      final returnProgress = (returnTraveled / safeLength).clamp(0.05, 1.0);
      final remaining = (safeLength - returnTraveled).clamp(0.0, 999.0);
      return Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'REVERSING BACK TO ORIGIN...',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${returnTraveled.toStringAsFixed(1)} cm / ${safeLength.toStringAsFixed(1)} cm',
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: returnProgress,
              backgroundColor: AppColors.primaryBorder,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Origin (0.0 cm)',
                  style: AppTypography.caption.copyWith(fontSize: 10, color: AppColors.secondaryText),
                ),
                Text(
                  '${remaining.toStringAsFixed(1)} cm to starting line',
                  style: AppTypography.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 3. PHASE 2: PLANTING WITH STATIONS & DISPENSE INDICATOR
    final safeTotal = total > 0 ? total : 4;
    final rowProgress = (completed / safeTotal).clamp(0.0, 1.0);
    final distanceToDrop = (targetPointDist - distanceTraveled).clamp(0.0, 999.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDispensing
              ? AppColors.primaryGreen
              : AppColors.primaryBorder,
          width: isDispensing ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Planting Points (Stations):',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
              Text(
                '$completed of $safeTotal planted',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: completed >= safeTotal ? AppColors.success : AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Point Stations Track Bar
          _PlantingPointsTrackBar(
            totalPoints: safeTotal,
            completedDrops: completed,
            currentPoint: currentPoint,
            isDispensing: isDispensing,
            spacingCm: spacing,
          ),
          const SizedBox(height: 8),

          // Continuous physical distance loading bar
          LinearProgressIndicator(
            value: rowProgress,
            backgroundColor: AppColors.primaryBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              isDispensing ? AppColors.primaryGreen : AppColors.primaryGreen,
            ),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),

          // ACTIVE INDICATOR FOR PLANT / DISPENSE SEED
          if (completed >= safeTotal) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'All $safeTotal points planted! Rover flattening raked furrow.',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isDispensing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.primaryGreen, width: 1.2),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🌱 DISPENSING SEED AT POINT $currentPoint (Gate $gateNum - $seedLabel)',
                      style: AppTypography.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryGreen,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.arrow_forward, size: 14, color: AppColors.primaryGreen),
                      const SizedBox(width: 4),
                      Text(
                        'Advancing to Point $currentPoint...',
                        style: AppTypography.caption.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${distanceToDrop.toStringAsFixed(1)} cm to drop',
                    style: AppTypography.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 10.5,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlantingPointsTrackBar extends StatelessWidget {
  const _PlantingPointsTrackBar({
    required this.totalPoints,
    required this.completedDrops,
    required this.currentPoint,
    required this.isDispensing,
    required this.spacingCm,
  });

  final int totalPoints;
  final int completedDrops;
  final int currentPoint;
  final bool isDispensing;
  final double spacingCm;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 1; i <= totalPoints; i++) ...[
          if (i > 1)
            Expanded(
              child: Container(
                height: 3,
                color: i <= completedDrops
                    ? AppColors.primaryGreen
                    : AppColors.primaryBorder,
              ),
            ),
          _PlantingStationNode(
            pointNumber: i,
            isCompleted: i <= completedDrops,
            isCurrent: i == currentPoint && completedDrops < totalPoints,
            isDispensing: isDispensing && i == currentPoint,
            stationDistCm: i * spacingCm,
          ),
        ],
      ],
    );
  }
}

class _PlantingStationNode extends StatelessWidget {
  const _PlantingStationNode({
    required this.pointNumber,
    required this.isCompleted,
    required this.isCurrent,
    required this.isDispensing,
    required this.stationDistCm,
  });

  final int pointNumber;
  final bool isCompleted;
  final bool isCurrent;
  final bool isDispensing;
  final double stationDistCm;

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Widget iconOrText;

    if (isCompleted) {
      bgColor = AppColors.primaryGreen;
      borderColor = AppColors.primaryGreen;
      iconOrText = const Icon(Icons.check, size: 13, color: Colors.white);
    } else if (isDispensing) {
      bgColor = AppColors.primaryGreen.withValues(alpha: 0.2);
      borderColor = AppColors.primaryGreen;
      iconOrText = const Text('🌱', style: TextStyle(fontSize: 11));
    } else if (isCurrent) {
      bgColor = AppColors.primaryGreen.withValues(alpha: 0.1);
      borderColor = AppColors.primaryGreen;
      iconOrText = Text(
        '$pointNumber',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppColors.primaryGreen,
        ),
      );
    } else {
      bgColor = AppColors.primaryBackground;
      borderColor = AppColors.primaryBorder;
      iconOrText = Text(
        '$pointNumber',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.secondaryText,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isDispensing ? 26 : 22,
          height: isDispensing ? 26 : 22,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: isDispensing ? 2.0 : 1.5,
            ),
            boxShadow: isDispensing
                ? [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.4),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(child: iconOrText),
        ),
        const SizedBox(height: 3),
        Text(
          'Pt $pointNumber',
          style: TextStyle(
            fontSize: 9,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent ? AppColors.primaryGreen : AppColors.secondaryText,
          ),
        ),
        if (stationDistCm > 0)
          Text(
            '${stationDistCm.toStringAsFixed(0)}cm',
            style: TextStyle(
              fontSize: 8.5,
              color: AppColors.secondaryText.withValues(alpha: 0.8),
            ),
          ),
      ],
    );
  }
}

class _ObstacleNotice extends StatelessWidget {
  const _ObstacleNotice({required this.status});
  final _ObstaclePresentation status;

  @override
  Widget build(BuildContext context) {
    final isClear = status.color == AppColors.success;
    final hasStatusFill = status.isDanger || isClear;
    final foreground = hasStatusFill ? Colors.white : status.color;
    final background = status.isDanger
        ? const Color(0xFFB42318)
        : isClear
            ? const Color(0xFF216E43)
            : AppColors.secondaryBackground;

    return Semantics(
      liveRegion: status.isDanger,
      label: status.message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: hasStatusFill
              ? null
              : Border.all(color: AppColors.inactiveBorder),
        ),
        child: Row(
          children: [
            Icon(status.icon, size: 18, color: foreground),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                status.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectivitySummary extends StatelessWidget {
  const _ConnectivitySummary({
    required this.roverConnected,
    required this.wifiConnected,
    required this.connecting,
    required this.pingRoundTripMs,
    required this.onConnect,
    required this.onDisconnect,
    required this.disconnecting,
    required this.canDisconnect,
  });
  final bool roverConnected;
  final bool wifiConnected;
  final bool connecting;
  final int? pingRoundTripMs;
  final Future<void> Function() onConnect;
  final Future<void> Function() onDisconnect;
  final bool disconnecting;
  final bool canDisconnect;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: _ConnectionValue(
                  label: 'Rover',
                  value: roverConnected ? 'Online' : 'Offline',
                  icon: Icons.router_outlined,
                  connected: roverConnected,
                ),
              ),
            ),
            const _ConnectionDivider(),
            Expanded(
              child: Center(
                child: wifiConnected
                    ? TextButton.icon(
                        onPressed: disconnecting || !canDisconnect
                            ? null
                            : onDisconnect,
                        icon: disconnecting
                            ? const SizedBox.square(
                                dimension: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Icon(
                                Icons.wifi_off,
                                size: 16,
                                color: AppColors.danger,
                              ),
                        label: Text(
                          disconnecting ? 'Disconnecting' : 'Disconnect',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          textStyle: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : TextButton.icon(
                        onPressed:
                            connecting || disconnecting ? null : onConnect,
                        icon: connecting || disconnecting
                            ? const SizedBox.square(
                                dimension: 14,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi, size: 16),
                        label: Text(
                          connecting
                              ? 'Connecting'
                              : disconnecting
                                  ? 'Disconnecting'
                                  : 'Connect',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: TextButton.styleFrom(
                          minimumSize: const Size(48, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          textStyle: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
            const _ConnectionDivider(),
            Expanded(
              child: Center(
                child: _ConnectionValue(
                  label: 'Ping',
                  value: pingRoundTripMs == null ? '--' : '$pingRoundTripMs ms',
                  icon: Icons.network_ping,
                  connected: pingRoundTripMs != null,
                ),
              ),
            ),
          ],
        ),
      );
}

class _ConnectionDivider extends StatelessWidget {
  const _ConnectionDivider();

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 20,
        color: AppColors.inactiveBorder,
      );
}

class _ConnectionValue extends StatelessWidget {
  const _ConnectionValue({
    required this.label,
    required this.value,
    required this.icon,
    required this.connected,
  });
  final String label;
  final String value;
  final IconData icon;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.success : AppColors.mutedText;
    return Semantics(
      label: '$label: $value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption
                  .copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObstaclePresentation {
  const _ObstaclePresentation({
    required this.message,
    required this.color,
    required this.icon,
    this.isDanger = false,
  });

  final String message;
  final Color color;
  final IconData icon;
  final bool isDanger;
}

_ObstaclePresentation _obstacleStatusFor(RoverControlState state) {
  final unavailable = _ObstaclePresentation(
    message: 'Obstacle info unavailable',
    color: AppColors.mutedText,
    icon: Icons.sensors_off_outlined,
  );

  if (!state.localWifiConnected) return unavailable;

  final operation = state.plantingOperation;
  final age = operation?.obstacleSampleAgeMs;
  if (operation == null || age == null || age < 0 || age > 10000) {
    return unavailable;
  }

  final frontObstacle =
      operation.frontSensorAvailable && operation.frontObstacle;
  final rearObstacle = operation.rearSensorAvailable && operation.rearObstacle;
  if (frontObstacle && rearObstacle) {
    return _ObstaclePresentation(
      message: 'Obstacle ahead and behind',
      color: AppColors.danger,
      icon: Icons.warning_amber_rounded,
      isDanger: true,
    );
  }
  if (frontObstacle) {
    return _ObstaclePresentation(
      message: 'Obstacle ahead',
      color: AppColors.danger,
      icon: Icons.warning_amber_rounded,
      isDanger: true,
    );
  }
  if (rearObstacle) {
    return _ObstaclePresentation(
      message: 'Obstacle behind',
      color: AppColors.danger,
      icon: Icons.warning_amber_rounded,
      isDanger: true,
    );
  }

  return _ObstaclePresentation(
    message: "No obstacle - you're good to go",
    color: AppColors.success,
    icon: Icons.check_circle_outline,
  );
}

class _LastSensorReadPanel extends StatelessWidget {
  const _LastSensorReadPanel({required this.sensors});
  final List<RoverSensorModel> sensors;

  @override
  Widget build(BuildContext context) {
    final timestamps = sensors
        .map((sensor) => sensor.recordedAt)
        .whereType<DateTime>()
        .toList();
    final latest = timestamps.isEmpty
        ? null
        : timestamps
            .reduce((left, right) => left.isAfter(right) ? left : right);
    final hasValues = sensors.any((sensor) => sensor.value != null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: Text(
            'Sensors · last read',
            style: AppTypography.small.copyWith(
              color: AppColors.primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          latest == null
              ? hasValues
                  ? 'Time unavailable'
                  : 'No recent reading'
              : TimeOfDay.fromDateTime(latest).format(context),
          style: AppTypography.caption,
        ),
      ]),
      const SizedBox(height: AppSpacing.sm),
      SensorMonitoringGrid(sensors: sensors),
    ]);
  }
}

class _FormFieldLabel extends StatelessWidget {
  const _FormFieldLabel({required this.label, this.requiredField = false});
  final String label;
  final bool requiredField;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text.rich(TextSpan(children: [
          TextSpan(
            text: label,
            style: AppTypography.small.copyWith(fontWeight: FontWeight.w700),
          ),
          if (requiredField)
            const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
        ])),
      );
}

class _RoverHeader extends StatelessWidget {
  const _RoverHeader({
    required this.connected,
    required this.onBack,
    this.showRoverStatus = true,
    this.showCameraStatus = false,
    this.cameraConnected = false,
    this.cameraCanView = true,
  });

  final bool connected;
  final VoidCallback onBack;
  final bool showRoverStatus;
  final bool showCameraStatus;
  final bool cameraConnected;
  final bool cameraCanView;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.primaryGreen,
        child: Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: 'Back',
              style: IconButton.styleFrom(
                minimumSize: const Size(52, 56),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            Expanded(
              child: Text(
                'Rover Control',
                style: AppTypography.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showCameraStatus)
              _RoverHeaderStatusPill(
                label: !cameraCanView
                    ? 'Camera restricted'
                    : cameraConnected
                        ? 'Camera online'
                        : 'Camera offline',
                icon: !cameraCanView
                    ? Icons.videocam_off_rounded
                    : cameraConnected
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                backgroundColor: !cameraCanView
                    ? Colors.white.withValues(alpha: .18)
                    : cameraConnected
                        ? AppColors.success.withValues(alpha: .9)
                        : AppColors.danger.withValues(alpha: .9),
                margin: const EdgeInsets.only(right: AppSpacing.sm),
              ),
            if (showRoverStatus)
              _RoverHeaderStatusPill(
                label: connected ? 'Rover Online' : 'Rover Offline',
                icon: connected
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                backgroundColor: connected
                    ? AppColors.success.withValues(alpha: .9)
                    : AppColors.danger.withValues(alpha: .9),
                margin: const EdgeInsets.only(right: AppSpacing.md),
              ),
          ],
        ),
      );
}

class _RoverHeaderStatusPill extends StatelessWidget {
  const _RoverHeaderStatusPill({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.margin,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) => Container(
        margin: margin,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _PortraitAutoPlantCard extends StatefulWidget {
  const _PortraitAutoPlantCard({
    required this.state,
    required this.controller,
    required this.canControlPlanting,
    required this.canUseControls,
    required this.canPlantNextRow,
    required this.onSetupPlanting,
    required this.onPlantNextRow,
    required this.onStartAutomaticRow,
    required this.onRetrySync,
    this.onReviewPendingSession,
  });

  final RoverControlState state;
  final RoverControlController controller;
  final bool canControlPlanting;
  final bool canUseControls;
  final bool canPlantNextRow;
  final VoidCallback onSetupPlanting;
  final VoidCallback onPlantNextRow;
  final void Function(PlantingSeedType seed, int points) onStartAutomaticRow;
  final VoidCallback onRetrySync;
  final VoidCallback? onReviewPendingSession;

  @override
  State<_PortraitAutoPlantCard> createState() => _PortraitAutoPlantCardState();
}

class _PortraitAutoPlantCardState extends State<_PortraitAutoPlantCard> {
  PlantingSeedType _selectedSeed = PlantingSeedType.sitaw;
  int _points = 4;

  @override
  void initState() {
    super.initState();
    if (widget.state.activePlantingConfig != null) {
      _selectedSeed = widget.state.activePlantingConfig!.seed;
      _points = widget.state.activePlantingConfig!.targetDrops;
    }
  }

  @override
  void didUpdateWidget(covariant _PortraitAutoPlantCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.activePlantingConfig != null &&
        widget.state.activePlantingConfig != oldWidget.state.activePlantingConfig) {
      _selectedSeed = widget.state.activePlantingConfig!.seed;
      _points = widget.state.activePlantingConfig!.targetDrops;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final operation = state.plantingOperation;
    final isLocked = state.isPlantingLocked;
    final isPaused = state.plantingStatus == PlantingStatus.paused;

    final activeSeed = state.activePlantingConfig?.seed ?? _selectedSeed;
    final seedLabel = activeSeed.label;
    final gateNum = switch (activeSeed) {
      PlantingSeedType.calamansi => 1,
      PlantingSeedType.sitaw => 2,
      PlantingSeedType.peanut => 3,
    };

    // Telemetry extractions matching Simulator
    final sensors = state.telemetry?.sensors ?? const [];
    final moistureSensor = sensors.where(
      (s) => s.label.toLowerCase().contains('moisture'),
    ).firstOrNull;
    final moistureVal = moistureSensor?.value != null
        ? '${moistureSensor!.value!.toStringAsFixed(1)}%'
        : '-- %';

    final tempSensor = sensors.where(
      (s) => s.label.toLowerCase().contains('soil temp') || s.label.toLowerCase().contains('soil'),
    ).firstOrNull;
    final tempVal = tempSensor?.value != null
        ? '${tempSensor!.value!.toStringAsFixed(1)} °C'
        : '-- °C';

    final frontDist = operation?.frontDistanceCm ?? operation?.detectedFieldDistanceCm;
    final frontDistVal = frontDist != null
        ? '${frontDist.toStringAsFixed(1)} cm'
        : '-- cm';

    final obstacle = state.obstacleWarning;
    final obstacleText = obstacle != null && obstacle.isNotEmpty
        ? obstacle
        : 'Clear';
    final obstacleColor = obstacle != null && obstacle.isNotEmpty
        ? AppColors.warning
        : AppColors.primaryGreen;

            // Header with status badge
            final statusColor = switch (state.plantingStatus) {
              PlantingStatus.active ||
              PlantingStatus.surveyingBed ||
              PlantingStatus.returningFromSurvey ||
              PlantingStatus.ready ||
              PlantingStatus.loweringRake =>
                AppColors.primaryGreen,
              PlantingStatus.paused => AppColors.warning,
              PlantingStatus.emergencyStopped ||
              PlantingStatus.failed ||
              PlantingStatus.interrupted =>
                AppColors.danger,
              _ => AppColors.secondaryText,
            };

            final statusBadgeText = switch (state.plantingStatus) {
              PlantingStatus.idle => 'Idle',
              PlantingStatus.checking => 'Checking',
              PlantingStatus.surveyingBed => 'Scouting',
              PlantingStatus.returningFromSurvey => 'Returning',
              PlantingStatus.loweringRake => 'Lowering',
              PlantingStatus.ready => 'Ready',
              PlantingStatus.active => 'Planting',
              PlantingStatus.returningToStart => 'Finishing',
              PlantingStatus.paused => 'Paused',
              PlantingStatus.completed => 'Completed',
              PlantingStatus.failed => 'Failed',
              PlantingStatus.emergencyStopped => 'E-Stopped',
              PlantingStatus.interrupted => 'Interrupted',
            };

            return Card(
              elevation: 0,
              color: AppColors.secondaryBackground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: BorderSide(
                  color: isLocked ? AppColors.primaryGreen : AppColors.primaryBorder,
                  width: isLocked ? 1.5 : 1.0,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.agriculture,
                          color: AppColors.primaryGreen,
                          size: 22,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Autonomous Planting',
                                      style: AppTypography.cardTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  GestureDetector(
                                    onTap: () => _showPlantingWorkflowGuideModal(context),
                                    child: Icon(
                                      Icons.help_outline_rounded,
                                      size: 17,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Selected: $seedLabel (Gate $gateNum)',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.secondaryText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            statusBadgeText,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
            const SizedBox(height: AppSpacing.md),

            // When idle: Show interactive seed & point setup matching simulator
            if (!isLocked) ...[
              // Section 1: Choose Seed Type
              Text(
                '1. CHOOSE SEED TYPE',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _SeedTypeCard(
                      label: 'Calamansi',
                      gateText: 'Gate 1 (GPIO 27)',
                      iconEmoji: '🍊',
                      isSelected: _selectedSeed == PlantingSeedType.calamansi,
                      onTap: () => setState(() => _selectedSeed = PlantingSeedType.calamansi),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _SeedTypeCard(
                      label: 'Sitaw',
                      gateText: 'Gate 2 (GPIO 4)',
                      iconEmoji: '🌱',
                      isSelected: _selectedSeed == PlantingSeedType.sitaw,
                      onTap: () => setState(() => _selectedSeed = PlantingSeedType.sitaw),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _SeedTypeCard(
                      label: 'Peanut',
                      gateText: 'Gate 3 (GPIO 23)',
                      iconEmoji: '🥜',
                      isSelected: _selectedSeed == PlantingSeedType.peanut,
                      onTap: () => setState(() => _selectedSeed = PlantingSeedType.peanut),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Section 2: Planting Points (Stations)
              Text(
                '2. PLANTING POINTS (STATIONS)',
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryText,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primaryBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton.filledTonal(
                      onPressed: _points > 1 ? () => setState(() => _points--) : null,
                      icon: const Icon(Icons.remove, size: 18),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    Column(
                      children: [
                        Text(
                          '$_points points',
                          style: AppTypography.cardTitle.copyWith(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Auto-calculated spacing',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.secondaryText,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                    IconButton.filledTonal(
                      onPressed: _points < 10 ? () => setState(() => _points++) : null,
                      icon: const Icon(Icons.add, size: 18),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Dynamic 1-pass planting · No fixed distance limit',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w600,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Section 3: Live Rover Telemetry (2x2 Grid matching simulator)
            Text(
              '3. LIVE TELEMETRY FROM ROVER',
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.secondaryText,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _TelemetryMiniBox(
                    label: 'Soil Moisture',
                    value: moistureVal,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _TelemetryMiniBox(
                    label: 'Soil Temp',
                    value: tempVal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _TelemetryMiniBox(
                    label: 'Front Field Dist',
                    value: frontDistVal,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _TelemetryMiniBox(
                    label: 'Obstacle (Sensor 1)',
                    value: obstacleText,
                    valueColor: obstacleColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Live Autonomous Phase & Distance Card (when locked / running)
            if (isLocked) ...[
              _LiveAutonomousPlantingPhaseCard(
                status: state.plantingStatus,
                operation: operation,
                targetDrops: state.activePlantingConfig?.targetDrops ?? _points,
                activeSeedLabel: seedLabel,
              ),
              _LivePlantingPhaseProgressTracker(
                status: state.plantingStatus,
                operation: operation,
                targetDrops: state.activePlantingConfig?.targetDrops ?? _points,
                seedLabel: seedLabel,
                gateNum: gateNum,
              ),
              const SizedBox(height: AppSpacing.md),

              // Running action buttons
              Row(
                children: [
                  if (isPaused)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: widget.controller.resumePlanting,
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Resume'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: widget.controller.cancelPlanting,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel run'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                      ),
                    ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.controller.emergencyStop,
                      icon: const Icon(Icons.emergency_outlined, size: 18),
                      label: const Text('Stop / E-Stop'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Idle action buttons
              if (state.pendingConfirmationSessionId != null &&
                  widget.onReviewPendingSession != null) ...[
                OutlinedButton.icon(
                  onPressed: widget.onReviewPendingSession,
                  icon: Icon(Icons.rate_review_outlined,
                      color: AppColors.primaryGreen, size: 18),
                  label: const Text('Review Previous Row Result'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              if (widget.canPlantNextRow) ...[
                FilledButton.icon(
                  onPressed: widget.onPlantNextRow,
                  icon: const Icon(Icons.redo_rounded, size: 18),
                  label: const Text('Plant Next Row'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (!state.localWifiConnected) ...[
                FilledButton.icon(
                  onPressed: state.localWifiConnecting
                      ? null
                      : widget.controller.connectLocalWifi,
                  icon: state.localWifiConnecting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.wifi_tethering, size: 20),
                  label: Text(state.localWifiConnecting
                      ? 'Connecting to Rover Wi-Fi...'
                      : 'Connect to Rover Wi-Fi to Start'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: AppColors.warning,
                  ),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: widget.canControlPlanting && !state.isPlantingLocked
                      ? () => widget.onStartAutomaticRow(_selectedSeed, _points)
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text('▶ Start Automatic Row'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xs),
              OutlinedButton.icon(
                onPressed: widget.canControlPlanting && !state.isPlantingLocked
                    ? widget.onSetupPlanting
                    : null,
                icon: const Icon(Icons.settings_suggest_outlined, size: 16),
                label: const Text('Advanced Row Setup...'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(36),
                ),
              ),
            ],

            if (state.pendingReceiptCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed: state.syncingReceipts ? null : widget.onRetrySync,
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: Text(state.syncingReceipts
                    ? 'Syncing receipts...'
                    : 'Sync ${state.pendingReceiptCount} Pending Receipt${state.pendingReceiptCount > 1 ? 's' : ''}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SeedTypeCard extends StatelessWidget {
  const _SeedTypeCard({
    required this.label,
    required this.gateText,
    required this.iconEmoji,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String gateText;
  final String iconEmoji;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGreen.withValues(alpha: 0.12)
              : AppColors.primaryBackground,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : AppColors.primaryBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Text(iconEmoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.small.copyWith(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.primaryGreen : AppColors.primaryText,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              gateText,
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(
                fontSize: 9,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelemetryMiniBox extends StatelessWidget {
  const _TelemetryMiniBox({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBackground,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 9.5,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}
