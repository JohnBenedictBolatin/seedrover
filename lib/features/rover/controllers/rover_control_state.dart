import '../data/models/rover_command_model.dart';
import '../data/models/rover_control_model.dart';
import '../data/models/planting_session_model.dart';

enum PlantingStatus {
  idle,
  checking,
  loweringRake,
  ready,
  active,
  paused,
  completed,
  failed,
  emergencyStopped,
  interrupted,
}

extension PlantingStatusLabel on PlantingStatus {
  String get label {
    return switch (this) {
      PlantingStatus.idle => 'Idle',
      PlantingStatus.checking => 'Checking Soil',
      PlantingStatus.loweringRake => 'Lowering Rake',
      PlantingStatus.ready => 'Ready to Plant',
      PlantingStatus.active => 'Planting',
      PlantingStatus.paused => 'Paused Safely',
      PlantingStatus.completed => 'Row Completed',
      PlantingStatus.failed => 'Planting Failed',
      PlantingStatus.emergencyStopped => 'Emergency Stopped',
      PlantingStatus.interrupted => 'Interrupted - Review Required',
    };
  }
}

class RoverControlState {
  const RoverControlState({
    required this.isLoading,
    required this.telemetry,
    required this.speed,
    required this.plantingStatus,
    required this.selectedSeed,
    required this.soilCheckPassed,
    required this.soilCheckMessage,
    required this.cameraFullscreen,
    this.activeMovement,
    this.lastCommand,
    this.errorMessage,
    this.pingRoundTripMs,
    this.isPinging = false,
    this.localWifiConnected = false,
    this.localWifiConnecting = false,
    this.localWifiDisconnecting = false,
    this.plantingOperation,
    this.activePlantingConfig,
    this.pendingReceiptCount = 0,
    this.syncingReceipts = false,
    this.lastCreatedCropId,
    this.pendingConfirmationSessionId,
    this.obstacleWarning,
    this.obstacleAlertSequence = 0,
    this.confirmedPlantingSessionId,
    this.lastSyncedPlantingSessionId,
    this.lastConfirmedSyncedSessionId,
  });

  const RoverControlState.loading()
      : isLoading = true,
        telemetry = null,
        speed = 70,
        plantingStatus = PlantingStatus.idle,
        selectedSeed = PlantingSeedType.sitaw,
        soilCheckPassed = false,
        soilCheckMessage = 'Ready for manual control or automatic planting.',
        cameraFullscreen = false,
        activeMovement = null,
        lastCommand = null,
        errorMessage = null,
        pingRoundTripMs = null,
        isPinging = false,
        localWifiConnected = false,
        localWifiConnecting = false,
        localWifiDisconnecting = false,
        plantingOperation = null,
        activePlantingConfig = null,
        pendingReceiptCount = 0,
        syncingReceipts = false,
        lastCreatedCropId = null,
        pendingConfirmationSessionId = null,
        obstacleWarning = null,
        obstacleAlertSequence = 0,
        confirmedPlantingSessionId = null,
        lastSyncedPlantingSessionId = null,
        lastConfirmedSyncedSessionId = null;

  final bool isLoading;
  final RoverControlModel? telemetry;
  final int speed;
  final PlantingStatus plantingStatus;
  final PlantingSeedType selectedSeed;
  final bool soilCheckPassed;
  final String soilCheckMessage;
  final bool cameraFullscreen;
  final RoverMovementCommand? activeMovement;
  final String? lastCommand;
  final String? errorMessage;
  final int? pingRoundTripMs;
  final bool isPinging;
  final bool localWifiConnected;
  final bool localWifiConnecting;
  final bool localWifiDisconnecting;
  final PlantingOperationStatus? plantingOperation;
  final PlantingRowConfig? activePlantingConfig;
  final int pendingReceiptCount;
  final bool syncingReceipts;
  final String? lastCreatedCropId;
  final String? pendingConfirmationSessionId;
  final String? obstacleWarning;
  final int obstacleAlertSequence;
  final String? confirmedPlantingSessionId;
  final String? lastSyncedPlantingSessionId;
  final String? lastConfirmedSyncedSessionId;

  bool get isConnected {
    return localWifiConnected ||
        telemetry?.wifiConnected == true ||
        telemetry?.bluetoothConnected == true;
  }

  bool get isPlantingLocked {
    return const {
      PlantingStatus.checking,
      PlantingStatus.loweringRake,
      PlantingStatus.ready,
      PlantingStatus.active,
      PlantingStatus.paused,
    }.contains(plantingStatus);
  }

  bool get canCheckSoil {
    return !isPlantingLocked;
  }

  bool get canStartPlanting {
    return !isPlantingLocked;
  }

  RoverControlState copyWith({
    bool? isLoading,
    RoverControlModel? telemetry,
    int? speed,
    PlantingStatus? plantingStatus,
    PlantingSeedType? selectedSeed,
    bool? soilCheckPassed,
    String? soilCheckMessage,
    bool? cameraFullscreen,
    RoverMovementCommand? activeMovement,
    bool clearActiveMovement = false,
    String? lastCommand,
    String? errorMessage,
    bool clearErrorMessage = false,
    int? pingRoundTripMs,
    bool clearPingRoundTrip = false,
    bool? isPinging,
    bool? localWifiConnected,
    bool? localWifiConnecting,
    bool? localWifiDisconnecting,
    PlantingOperationStatus? plantingOperation,
    bool clearPlantingOperation = false,
    PlantingRowConfig? activePlantingConfig,
    bool clearActivePlantingConfig = false,
    int? pendingReceiptCount,
    bool? syncingReceipts,
    String? lastCreatedCropId,
    bool clearLastCreatedCropId = false,
    String? pendingConfirmationSessionId,
    bool clearPendingConfirmationSessionId = false,
    String? obstacleWarning,
    bool clearObstacleWarning = false,
    int? obstacleAlertSequence,
    String? confirmedPlantingSessionId,
    bool clearConfirmedPlantingSessionId = false,
    String? lastSyncedPlantingSessionId,
    String? lastConfirmedSyncedSessionId,
  }) {
    return RoverControlState(
      isLoading: isLoading ?? this.isLoading,
      telemetry: telemetry ?? this.telemetry,
      speed: speed ?? this.speed,
      plantingStatus: plantingStatus ?? this.plantingStatus,
      selectedSeed: selectedSeed ?? this.selectedSeed,
      soilCheckPassed: soilCheckPassed ?? this.soilCheckPassed,
      soilCheckMessage: soilCheckMessage ?? this.soilCheckMessage,
      cameraFullscreen: cameraFullscreen ?? this.cameraFullscreen,
      activeMovement:
          clearActiveMovement ? null : activeMovement ?? this.activeMovement,
      lastCommand: lastCommand ?? this.lastCommand,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      pingRoundTripMs:
          clearPingRoundTrip ? null : pingRoundTripMs ?? this.pingRoundTripMs,
      isPinging: isPinging ?? this.isPinging,
      localWifiConnected: localWifiConnected ?? this.localWifiConnected,
      localWifiConnecting: localWifiConnecting ?? this.localWifiConnecting,
      localWifiDisconnecting:
          localWifiDisconnecting ?? this.localWifiDisconnecting,
      plantingOperation: clearPlantingOperation
          ? null
          : plantingOperation ?? this.plantingOperation,
      activePlantingConfig: clearActivePlantingConfig
          ? null
          : activePlantingConfig ?? this.activePlantingConfig,
      pendingReceiptCount: pendingReceiptCount ?? this.pendingReceiptCount,
      syncingReceipts: syncingReceipts ?? this.syncingReceipts,
      lastCreatedCropId: clearLastCreatedCropId
          ? null
          : lastCreatedCropId ?? this.lastCreatedCropId,
      pendingConfirmationSessionId: clearPendingConfirmationSessionId
          ? null
          : pendingConfirmationSessionId ?? this.pendingConfirmationSessionId,
      obstacleWarning:
          clearObstacleWarning ? null : obstacleWarning ?? this.obstacleWarning,
      obstacleAlertSequence:
          obstacleAlertSequence ?? this.obstacleAlertSequence,
      confirmedPlantingSessionId: clearConfirmedPlantingSessionId
          ? null
          : confirmedPlantingSessionId ?? this.confirmedPlantingSessionId,
      lastSyncedPlantingSessionId:
          lastSyncedPlantingSessionId ?? this.lastSyncedPlantingSessionId,
      lastConfirmedSyncedSessionId:
          lastConfirmedSyncedSessionId ?? this.lastConfirmedSyncedSessionId,
    );
  }
}
