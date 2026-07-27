import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/rover_command_model.dart';
import '../data/models/rover_control_model.dart';
import '../data/repositories/rover_repository.dart';
import '../data/services/local_wifi_rover_service.dart';
import 'rover_control_state.dart';

class RoverControlController extends StateNotifier<RoverControlState> {
  RoverControlController(this._repository, this._localWifiService)
      : super(const RoverControlState.loading()) {
    // Render controls immediately while cloud telemetry loads in parallel.
    state = state.copyWith(
      isLoading: false,
      telemetry: RoverControlModel.offline(),
    );
    load();
    _subscription = _repository.watchRoverStatus().listen((_) => load());
    _simulationSubscription = _repository.watchSimulationStatus().listen((_) {
      if (_repository.isSimulationConnected) {
        load();
      }
    });
    _localWifiSubscription = _localWifiService.connectedStream.listen((connected) {
      state = state.copyWith(localWifiConnected: connected);
    });
    unawaited(_detectLocalWifi());
    _localWifiDetectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_detectLocalWifi()),
    );
  }

  final RoverRepository _repository;
  final LocalWifiRoverService _localWifiService;
  StreamSubscription<void>? _subscription;
  StreamSubscription<void>? _simulationSubscription;
  StreamSubscription<bool>? _localWifiSubscription;
  Timer? _localWifiDetectionTimer;

  Future<void> load() async {
    try {
      final telemetry = await _repository.loadStatus();
      state = state.copyWith(
        isLoading: false,
        telemetry: telemetry,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        telemetry: RoverControlModel.offline(),
        errorMessage: state.localWifiConnecting
            ? state.errorMessage
            : 'Cloud data unavailable. Local PING is still available.',
      );
    }
  }

  void setSpeed(double value) {
    if (state.isPlantingLocked) {
      return;
    }

    state = state.copyWith(speed: value.round());
  }

  void selectSeed(PlantingSeedType seed) {
    if (state.isPlantingLocked) {
      return;
    }

    state = state.copyWith(selectedSeed: seed);
  }

  Future<void> connectSimulation() async {
    try {
      state = state.copyWith(errorMessage: 'Connecting simulation...');
      await _repository.connectSimulation();
      final telemetry = await _repository.loadStatus();
      state = state.copyWith(
        telemetry: telemetry,
        lastCommand: 'Simulation connected',
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Unable to connect simulation.',
      );
    }
  }

  Future<void> disconnectSimulation() async {
    try {
      await _repository.disconnectSimulation();
      final telemetry = state.telemetry;
      state = state.copyWith(
        telemetry: telemetry?.copyWith(
          wifiConnected: false,
          bluetoothConnected: false,
          cameraConnected: false,
        ),
        clearActiveMovement: true,
        lastCommand: 'Simulation disconnected',
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        errorMessage: 'Unable to disconnect simulation.',
      );
    }
  }

  Future<void> connectLocalWifi() async {
    if (state.localWifiConnecting || state.localWifiConnected) return;
    state = state.copyWith(
      localWifiConnecting: true,
      errorMessage: 'Connecting to the ESP32 on home Wi-Fi...',
    );
    try {
      await _localWifiService.connect();
      final pingResult = await _localWifiService.ping();
      state = state.copyWith(
        localWifiConnecting: false,
        localWifiConnected: true,
        pingRoundTripMs: pingResult.roundTrip.inMilliseconds,
        lastCommand:
            'PONG in ${pingResult.roundTrip.inMilliseconds} ms',
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        localWifiConnecting: false,
        localWifiConnected: false,
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> _detectLocalWifi() async {
    if (state.localWifiConnecting || state.isPinging) return;
    if (state.localWifiConnected) {
      try {
        final pingResult = await _localWifiService.ping();
        state = state.copyWith(
          localWifiConnected: true,
          pingRoundTripMs: pingResult.roundTrip.inMilliseconds,
          clearErrorMessage: true,
        );
      } catch (_) {
        state = state.copyWith(
          localWifiConnected: _localWifiService.isConnected,
          clearPingRoundTrip: true,
        );
      }
      return;
    }
    state = state.copyWith(localWifiConnecting: true);
    try {
      await _localWifiService.connect();
      final pingResult = await _localWifiService.ping();
      state = state.copyWith(
        localWifiConnecting: false,
        localWifiConnected: true,
        pingRoundTripMs: pingResult.roundTrip.inMilliseconds,
        lastCommand:
            'PONG in ${pingResult.roundTrip.inMilliseconds} ms',
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        localWifiConnecting: false,
        localWifiConnected: false,
      );
    }
  }

  Future<void> disconnectLocalWifi() async {
    await _localWifiService.disconnect();
    state = state.copyWith(
      localWifiConnected: false,
      clearPingRoundTrip: true,
      lastCommand: 'Local Wi-Fi disconnected',
      clearErrorMessage: true,
    );
  }

  Future<void> pingRover() async {
    state = state.copyWith(
      isPinging: true,
      clearPingRoundTrip: true,
      clearErrorMessage: true,
    );
    try {
      final result = await _localWifiService.ping();
      state = state.copyWith(
        isPinging: false,
        localWifiConnected: true,
        pingRoundTripMs: result.roundTrip.inMilliseconds,
        lastCommand: 'PONG in ${result.roundTrip.inMilliseconds} ms',
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        isPinging: false,
        localWifiConnected: _localWifiService.isConnected,
        clearPingRoundTrip: true,
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> sendMovement(RoverMovementCommand command) async {
    if (state.localWifiConnected) {
      try {
        final result = await _localWifiService.sendCommand(
          command.protocolCommand,
          payload: {'speed': state.speed},
        );
        state = state.copyWith(
          activeMovement:
              command == RoverMovementCommand.stop ? null : command,
          clearActiveMovement: command == RoverMovementCommand.stop,
          lastCommand:
              '${command.label} accepted in ${result.roundTrip.inMilliseconds} ms',
          clearErrorMessage: true,
        );
      } catch (error) {
        state = state.copyWith(
          localWifiConnected: _localWifiService.isConnected,
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        );
      }
      return;
    }
    if (!state.isConnected) {
      state =
          state.copyWith(errorMessage: 'Reconnect before sending commands.');
      return;
    }

    if (state.isPlantingLocked) {
      state = state.copyWith(
        errorMessage: 'Planting is active. Use Emergency Stop first.',
      );
      return;
    }

    final lastCommand = await _repository.sendMovementCommand(
      command,
      speed: state.speed,
    );

    state = state.copyWith(
      activeMovement: command == RoverMovementCommand.stop ? null : command,
      clearActiveMovement: command == RoverMovementCommand.stop,
      lastCommand: lastCommand,
      clearErrorMessage: true,
    );
  }

  Future<void> checkSoilState() async {
    if (!state.isConnected) {
      state = state.copyWith(errorMessage: 'Reconnect before checking soil.');
      return;
    }

    if (!state.canCheckSoil) {
      state = state.copyWith(
        errorMessage: 'Planting is active. Use Emergency Stop first.',
      );
      return;
    }

    state = state.copyWith(
      plantingStatus: PlantingStatus.checking,
      clearErrorMessage: true,
      soilCheckMessage: 'Checking soil state...',
    );

    if (state.localWifiConnected) {
      try {
        final result = await _localWifiService.sendCommand('CHECK_SOIL');
        state = state.copyWith(
          plantingStatus: PlantingStatus.ready,
          soilCheckPassed: true,
          soilCheckMessage: 'Simulation: soil reported suitable.',
          lastCommand:
              'Soil check accepted in ${result.roundTrip.inMilliseconds} ms',
          clearErrorMessage: true,
        );
      } catch (error) {
        state = state.copyWith(
          plantingStatus: PlantingStatus.idle,
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        );
      }
      return;
    }

    final result = await _repository.checkSoilState();

    state = state.copyWith(
      plantingStatus:
          result.isSuitable ? PlantingStatus.ready : PlantingStatus.idle,
      soilCheckPassed: result.isSuitable,
      soilCheckMessage: result.message,
      lastCommand: 'Soil check completed',
      clearErrorMessage: true,
    );
  }

  Future<void> startPlanting() async {
    if (!state.isConnected) {
      state = state.copyWith(errorMessage: 'Reconnect before planting.');
      return;
    }

    if (state.isPlantingLocked) {
      state = state.copyWith(
        errorMessage: 'Planting is already running. Use Emergency Stop first.',
      );
      return;
    }

    if (!state.canStartPlanting) {
      state = state.copyWith(
        errorMessage: 'Check the soil before starting planting.',
      );
      return;
    }

    final String lastCommand;
    if (state.localWifiConnected) {
      try {
        final result = await _localWifiService.sendCommand(
          PlantingCommand.start.protocolCommand,
          payload: {'seed': state.selectedSeed.payloadValue},
        );
        lastCommand =
            'Plant accepted in ${result.roundTrip.inMilliseconds} ms';
      } catch (error) {
        state = state.copyWith(
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        );
        return;
      }
    } else {
      lastCommand = await _repository.sendPlantingCommand(
        PlantingCommand.start,
        seed: state.selectedSeed,
      );
    }

    state = state.copyWith(
      plantingStatus: PlantingStatus.active,
      lastCommand: lastCommand,
      soilCheckMessage: 'Planting ${state.selectedSeed.label} is in progress.',
      clearErrorMessage: true,
    );
  }

  Future<void> emergencyStop() async {
    if (!state.isPlantingLocked) {
      return;
    }

    if (state.localWifiConnected) {
      try {
        await _localWifiService.sendCommand('EMERGENCY_STOP');
      } catch (error) {
        state = state.copyWith(
          errorMessage: error.toString().replaceFirst('Bad state: ', ''),
        );
        return;
      }
    } else {
      await _repository.sendEmergencyStop();
    }

    state = state.copyWith(
      plantingStatus: PlantingStatus.emergencyStopped,
      clearActiveMovement: true,
      lastCommand: 'Emergency stop activated',
      soilCheckMessage:
          'Emergency stop activated. Rover controls are available again.',
      clearErrorMessage: true,
    );
  }

  Future<void> refreshCamera() async {
    final telemetry = state.telemetry;

    if (telemetry == null) {
      return;
    }

    state = state.copyWith(
      telemetry: telemetry.copyWith(cameraLoading: true),
      clearErrorMessage: true,
    );

    await _repository.refreshCamera();

    state = state.copyWith(
      telemetry: state.telemetry?.copyWith(
        cameraConnected: true,
        cameraLoading: false,
      ),
      lastCommand: 'Camera refreshed',
    );
  }

  void toggleCameraFullscreen() {
    state = state.copyWith(cameraFullscreen: !state.cameraFullscreen);
  }

  @override
  void dispose() {
    _localWifiDetectionTimer?.cancel();
    _subscription?.cancel();
    _simulationSubscription?.cancel();
    _localWifiSubscription?.cancel();
    super.dispose();
  }
}
