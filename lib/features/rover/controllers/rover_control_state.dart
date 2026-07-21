import '../data/models/rover_command_model.dart';
import '../data/models/rover_control_model.dart';

enum PlantingStatus {
  idle,
  checking,
  ready,
  active,
  emergencyStopped,
}

extension PlantingStatusLabel on PlantingStatus {
  String get label {
    return switch (this) {
      PlantingStatus.idle => 'Idle',
      PlantingStatus.checking => 'Checking Soil',
      PlantingStatus.ready => 'Ready to Plant',
      PlantingStatus.active => 'Planting',
      PlantingStatus.emergencyStopped => 'Emergency Stopped',
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
  });

  const RoverControlState.loading()
      : isLoading = true,
        telemetry = null,
        speed = 70,
        plantingStatus = PlantingStatus.idle,
        selectedSeed = PlantingSeedType.sitaw,
        soilCheckPassed = false,
        soilCheckMessage = 'Check the soil before planting.',
        cameraFullscreen = false,
        activeMovement = null,
        lastCommand = null,
        errorMessage = null;

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

  bool get isConnected {
    return telemetry?.wifiConnected == true || telemetry?.bluetoothConnected == true;
  }

  bool get isPlantingLocked {
    return plantingStatus == PlantingStatus.active;
  }

  bool get canCheckSoil {
    return plantingStatus != PlantingStatus.active &&
        plantingStatus != PlantingStatus.checking;
  }

  bool get canStartPlanting {
    return soilCheckPassed &&
        plantingStatus != PlantingStatus.active &&
        plantingStatus != PlantingStatus.checking;
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
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }
}
