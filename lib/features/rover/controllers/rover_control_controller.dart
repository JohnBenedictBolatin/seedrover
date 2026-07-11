import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/rover_command_model.dart';
import '../data/repositories/rover_repository.dart';
import 'rover_control_state.dart';

class RoverControlController extends StateNotifier<RoverControlState> {
  RoverControlController(this._repository)
      : super(const RoverControlState.loading()) {
    load();
    _subscription = _repository.watchRoverStatus().listen((_) => load());
  }

  final RoverRepository _repository;
  StreamSubscription<void>? _subscription;

  Future<void> load() async {
    try {
      final telemetry = await _repository.loadStatus();
      state = state.copyWith(
        isLoading: false,
        telemetry: telemetry,
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load rover data.',
      );
    }
  }

  void setSpeed(double value) {
    if (state.isPlantingLocked) {
      return;
    }

    state = state.copyWith(speed: value.round());
  }

  Future<void> sendMovement(RoverMovementCommand command) async {
    if (!state.isConnected) {
      state = state.copyWith(errorMessage: 'Reconnect before sending commands.');
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

    final result = await _repository.checkSoilState();

    state = state.copyWith(
      plantingStatus: result.isSuitable
          ? PlantingStatus.ready
          : PlantingStatus.idle,
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

    final lastCommand = await _repository.sendPlantingCommand(
      PlantingCommand.start,
    );

    state = state.copyWith(
      plantingStatus: PlantingStatus.active,
      lastCommand: lastCommand,
      soilCheckMessage: 'Planting is in progress.',
      clearErrorMessage: true,
    );
  }

  Future<void> emergencyStop() async {
    if (!state.isPlantingLocked) {
      return;
    }

    await _repository.sendEmergencyStop();

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
    _subscription?.cancel();
    super.dispose();
  }
}
