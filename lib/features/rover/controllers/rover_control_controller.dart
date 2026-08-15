import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/rover_command_model.dart';
import '../data/models/rover_control_model.dart';
import '../data/models/planting_session_model.dart';
import '../data/repositories/planting_receipt_repository.dart';
import '../data/repositories/rover_repository.dart';
import '../data/services/local_wifi_rover_service.dart';
import 'rover_control_state.dart';

class RoverControlController extends StateNotifier<RoverControlState> {
  RoverControlController(
    this._repository,
    this._localWifiService,
    this._receiptRepository,
  ) : super(const RoverControlState.loading()) {
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
    _localWifiSubscription =
        _localWifiService.connectedStream.listen((connected) {
      state = state.copyWith(localWifiConnected: connected);
    });
    unawaited(_detectLocalWifi());
    _localWifiDetectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_detectLocalWifi()),
    );
    _plantingStatusTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => unawaited(_refreshPlantingStatus()),
    );
    unawaited(_refreshPendingReceiptCount());
    unawaited(synchronizePendingReceipts());
  }

  final RoverRepository _repository;
  final LocalWifiRoverService _localWifiService;
  final PlantingReceiptRepository _receiptRepository;
  StreamSubscription<void>? _subscription;
  StreamSubscription<void>? _simulationSubscription;
  StreamSubscription<bool>? _localWifiSubscription;
  Timer? _localWifiDetectionTimer;
  Timer? _plantingStatusTimer;
  Timer? _forwardHeartbeatTimer;
  DateTime? _plantingStartedAt;
  final Set<String> _storedTerminalSessions = {};

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
        lastCommand: 'PONG in ${pingResult.roundTrip.inMilliseconds} ms',
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
        lastCommand: 'PONG in ${pingResult.roundTrip.inMilliseconds} ms',
        clearErrorMessage: true,
      );
    } catch (_) {
      state = state.copyWith(
        localWifiConnecting: false,
        localWifiConnected: false,
      );
    }
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
    if (state.isPlantingLocked &&
        command != RoverMovementCommand.forward &&
        command != RoverMovementCommand.stop) {
      state = state.copyWith(
        errorMessage:
            'Only Forward and Stop are available while the rake is lowered.',
      );
      return;
    }
    if (state.localWifiConnected) {
      try {
        final result = await _localWifiService.sendCommand(
          command.protocolCommand,
          payload: {'speed': state.speed},
        );
        state = state.copyWith(
          activeMovement: command == RoverMovementCommand.stop ? null : command,
          clearActiveMovement: command == RoverMovementCommand.stop,
          lastCommand:
              '${command.label} accepted in ${result.roundTrip.inMilliseconds} ms',
          clearErrorMessage: true,
        );
        if (command == RoverMovementCommand.forward && state.isPlantingLocked) {
          _startForwardHeartbeat();
        } else if (command == RoverMovementCommand.stop) {
          _forwardHeartbeatTimer?.cancel();
          await _refreshPlantingStatus();
        }
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

  void _startForwardHeartbeat() {
    _forwardHeartbeatTimer?.cancel();
    _forwardHeartbeatTimer = Timer.periodic(
      const Duration(milliseconds: 650),
      (_) => unawaited(_sendForwardHeartbeat()),
    );
  }

  Future<void> _sendForwardHeartbeat() async {
    if (!state.localWifiConnected ||
        state.activeMovement != RoverMovementCommand.forward ||
        !state.canDrivePlantingForward) {
      _forwardHeartbeatTimer?.cancel();
      return;
    }
    try {
      await _localWifiService.sendCommand(
        'MOVE_FORWARD',
        payload: {'speed': state.speed},
      );
    } catch (_) {
      _forwardHeartbeatTimer?.cancel();
    }
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

  Future<void> startPlanting(PlantingRowConfig configuration) async {
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

    if (!state.localWifiConnected) {
      state = state.copyWith(
        errorMessage:
            'Connect directly to SeedRover-01 before starting a measured row.',
      );
      return;
    }
    try {
      await _localWifiService.startPlantingRow(configuration);
      _plantingStartedAt = DateTime.now();
      state = state.copyWith(
        selectedSeed: configuration.seed,
        plantingStatus: PlantingStatus.checking,
        activePlantingConfig: configuration,
        soilCheckMessage: 'Checking soil, then lowering the rake.',
        lastCommand: 'Row ${configuration.sessionId.substring(0, 8)} accepted',
        clearErrorMessage: true,
      );
      await _refreshPlantingStatus();
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<RoverCalibrationModel> loadCalibration() {
    return _localWifiService.getCalibration();
  }

  Future<void> saveCalibration(RoverCalibrationModel calibration) async {
    try {
      await _localWifiService.saveCalibration(calibration);
      await _receiptRepository.saveCalibration(calibration);
      state = state.copyWith(
        lastCommand: 'Rover calibration saved',
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
      rethrow;
    }
  }

  Future<void> resumePlanting() async {
    try {
      await _localWifiService.sendCommand('RESUME_PLANTING');
      await _refreshPlantingStatus();
    } catch (error) {
      state = state.copyWith(
          errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> cancelPlanting() async {
    _forwardHeartbeatTimer?.cancel();
    try {
      await _localWifiService.sendCommand('CANCEL_PLANTING');
      await _refreshPlantingStatus();
    } catch (error) {
      state = state.copyWith(
          errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _refreshPlantingStatus() async {
    if (!state.localWifiConnected) return;
    try {
      final operation = await _localWifiService.getPlantingStatus();
      if (operation.sessionId.isEmpty) return;
      final mapped = switch (operation.state) {
        'CHECKING_SOIL' => PlantingStatus.checking,
        'LOWERING_RAKE' => PlantingStatus.loweringRake,
        'READY' => PlantingStatus.ready,
        'PLANTING' => PlantingStatus.active,
        'PAUSED' => PlantingStatus.paused,
        'COMPLETED' => PlantingStatus.completed,
        'EMERGENCY_STOPPED' => PlantingStatus.emergencyStopped,
        'FAILED' || 'CANCELLED' => PlantingStatus.failed,
        _ => PlantingStatus.idle,
      };
      final estimate = state.activePlantingConfig;
      final estimatedMin =
          operation.completedDrops * (estimate?.estimatedSeedsPerDropMin ?? 1);
      final estimatedMax =
          operation.completedDrops * (estimate?.estimatedSeedsPerDropMax ?? 3);
      state = state.copyWith(
        plantingStatus: mapped,
        plantingOperation: operation,
        soilCheckPassed: operation.state != 'CHECKING_SOIL',
        soilCheckMessage:
            '${operation.completedDrops}/${operation.targetDrops} completed drops · estimated $estimatedMin-$estimatedMax seeds',
        clearActiveMovement: operation.state != 'PLANTING',
        clearErrorMessage: true,
      );
      if (operation.isTerminal) {
        _forwardHeartbeatTimer?.cancel();
        await _storeTerminalReceipt(operation);
      }
    } catch (_) {
      // A lost hotspot connection is handled by the firmware heartbeat safety.
    }
  }

  Future<void> _storeTerminalReceipt(PlantingOperationStatus operation) async {
    if (_storedTerminalSessions.contains(operation.sessionId)) return;
    final configuration = state.activePlantingConfig;
    if (configuration == null ||
        configuration.sessionId != operation.sessionId) {
      return;
    }
    _storedTerminalSessions.add(operation.sessionId);
    await _receiptRepository.save(
      PendingPlantingReceipt(
        config: configuration,
        status: operation,
        startedAt: _plantingStartedAt ?? DateTime.now(),
        completedAt: DateTime.now(),
      ),
    );
    await _refreshPendingReceiptCount();
    unawaited(synchronizePendingReceipts());
  }

  Future<void> _refreshPendingReceiptCount() async {
    final pending = await _receiptRepository.loadPending();
    state = state.copyWith(pendingReceiptCount: pending.length);
  }

  Future<void> synchronizePendingReceipts() async {
    if (state.syncingReceipts) return;
    state = state.copyWith(syncingReceipts: true);
    final synced = await _receiptRepository.synchronize();
    final pending = await _receiptRepository.loadPending();
    state = state.copyWith(
      syncingReceipts: false,
      pendingReceiptCount: pending.length,
      lastCommand: synced > 0
          ? '$synced planting receipt${synced == 1 ? '' : 's'} synchronized'
          : state.lastCommand,
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
    await _refreshPlantingStatus();
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
    _plantingStatusTimer?.cancel();
    _forwardHeartbeatTimer?.cancel();
    _subscription?.cancel();
    _simulationSubscription?.cancel();
    _localWifiSubscription?.cancel();
    super.dispose();
  }
}
