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
import '../widgets/planting_control_panel.dart';
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
    if (mounted) setState(() => _cameraOnline = false);
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
        profile?.hasPermission(PermissionKeys.roverControl) ?? false;
    final canViewCamera =
        profile?.hasPermission(PermissionKeys.roverCameraView) ?? false;
    final canControlPlanting =
        profile?.hasPermission(PermissionKeys.roverPlantingControl) ?? false;
    final canManageCrops =
        profile?.hasPermission(PermissionKeys.cropsManage) ?? false;

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
                                  onPressed: canControlPlanting &&
                                          canUseControls &&
                                          state.pendingConfirmationSessionId ==
                                              null &&
                                          !(state.plantingOperation
                                                  ?.awaitingPhoneAck ??
                                              false)
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
      barrierDismissible: false,
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

  Future<void> _showPlantingRunControls(
    BuildContext context,
    RoverControlState state,
    RoverControlController controller,
    bool canControlPlanting,
    bool canPlantNextRow,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SingleChildScrollView(
          child: PlantingControlPanel(
            status: state.plantingStatus,
            canStartPlanting: canControlPlanting &&
                (state.canStartPlanting ||
                    state.plantingStatus == PlantingStatus.paused),
            isPlantingActive: state.plantingStatus == PlantingStatus.active ||
                (state.isPlantingLocked &&
                    state.plantingStatus != PlantingStatus.paused),
            completedDrops: state.plantingOperation?.completedDrops ?? 0,
            targetDrops: state.plantingOperation?.targetDrops ?? 0,
            pendingReceipts: state.pendingReceiptCount,
            isSyncing: state.syncingReceipts,
            onRetrySync: () => _retryPlantingSync(context, controller),
            onPlantNextRow: () => _confirmRoverAction(
              context,
              title: 'Plant the next row',
              message:
                  'Start another supervised planting run in ${state.activePlantingConfig?.fieldLabel ?? 'the selected field'}?',
              confirmLabel: 'Plant next row',
              onConfirm: () async {
                final nextConfiguration = state.activePlantingConfig?.nextRow();
                if (nextConfiguration == null) return;
                await _runPlantingPrecheck(
                  context,
                  controller,
                  nextConfiguration,
                  returnToLandscape: state.cameraFullscreen,
                  nextRow: true,
                );
              },
            ),
            canPlantNextRow: canPlantNextRow,
            onResume: () => _confirmRoverAction(
              context,
              title: 'Resume planting',
              message: 'Resume the paused planting run?',
              confirmLabel: 'Resume',
              onConfirm: controller.resumePlanting,
            ),
            onCancel: () => _confirmRoverAction(
              context,
              title: 'Cancel planting run',
              message:
                  'Stop and close this planting run? Its partial result will need review.',
              confirmLabel: 'Cancel run',
              confirmColor: AppColors.danger,
              onConfirm: controller.cancelPlanting,
            ),
          ),
        ),
      ),
    );
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
  }

  @override
  void dispose() {
    _pointsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .68,
        minChildSize: .48,
        maxChildSize: .92,
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
                      Text('Set up planting',
                          style: AppTypography.sectionHeading),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'One run plants a single row. Stay beside the rover while it works; obstacle alerts are warnings and do not stop movement.',
                        style: AppTypography.small.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _FormFieldLabel(label: 'Seed', requiredField: true),
                      AppSelector<PlantingSeedType>(
                        value: _seed,
                        decoration: _fieldDecoration('Choose a seed'),
                        items: [
                          for (final seed in PlantingSeedType.values)
                            DropdownMenuItem(
                                value: seed, child: Text(seed.label)),
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
                          label: 'Planting points', requiredField: true),
                      TextFormField(
                        controller: _pointsController,
                        style: AppTypography.numericInput,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        decoration: _fieldDecoration(
                          'Number of points',
                          hint: 'Default 5 · maximum 20',
                        ),
                        validator: (value) {
                          final points = int.tryParse(value ?? '');
                          if (points == null || points < 1 || points > 20) {
                            return 'Enter between 1 and 20 points.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Points are acknowledged seed-gate cycles, not a verified seed count. Crop spacing uses the saved seed profile.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: _submit,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Review planting'),
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
    final configuration = PlantingRowConfig(
      sessionId: defaults.sessionId,
      seed: _seed,
      fieldLabel: _fieldSelection!,
      targetDrops: int.parse(_pointsController.text),
      spacingCm: defaults.spacingCm,
      rowSpacingCm: defaults.rowSpacingCm,
      gateOpenMs: defaults.gateOpenMs,
      rakeOffsetCm: defaults.rakeOffsetCm,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review planting', style: AppTypography.sectionHeading),
        const SizedBox(height: AppSpacing.md),
        _PlantingReviewRow(label: 'Seed', value: configuration.seed.label),
        _PlantingReviewRow(
            label: 'Field or bed', value: configuration.fieldLabel),
        _PlantingReviewRow(
          label: 'Planting points',
          value: '${configuration.targetDrops}',
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'The rover will read the soil first. After you review both readings, it will lower the rake and drive one row. Stay beside it; obstacle alerts do not stop movement. Planting points are gate cycles, not a verified seed count.',
          style: AppTypography.small.copyWith(color: AppColors.secondaryText),
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
          label: const Text('Check soil readings'),
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
                onPressed: _readings.isValid &&
                        _readings.isFreshAt(DateTime.now()) &&
                        !_retrying
                    ? () => Navigator.of(context).pop(_readings)
                    : null,
                child: Text(_assessment.score == 100
                    ? 'Start planting'
                    : _assessment.hasMoistureConcern ||
                            _assessment.summary == 'Conditions need attention'
                        ? 'Start anyway'
                        : 'Start with available readings'),
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

String? _requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required' : null;

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
  if (operation == null || age == null || age < 0 || age > 3000) {
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

  if (!operation.frontSensorAvailable || !operation.rearSensorAvailable) {
    return unavailable;
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
