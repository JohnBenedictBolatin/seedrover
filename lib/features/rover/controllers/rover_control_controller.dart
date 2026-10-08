import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/soil_moisture_reference_label.dart';

import '../data/models/rover_command_model.dart';
import '../data/models/rover_control_model.dart';
import '../data/models/planting_session_model.dart';
import '../data/models/planting_soil_precheck.dart';
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
      if (connected) {
        _obstacleMonitoringStartedAt ??= DateTime.now();
        unawaited(synchronizePendingReceipts());
        unawaited(_refreshPlantingStatus());
      }
    });
    _localWifiDetectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_monitorLocalWifi()),
    );
    _plantingStatusTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => unawaited(_refreshPlantingStatus()),
    );
    _obstacleStaleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final last = _lastObstacleStatusAt;
      final baseline =
          last ?? _obstacleMonitoringStartedAt ?? _controllerStartedAt;
      if (DateTime.now().difference(baseline).inSeconds >= 3) {
        state =
            state.copyWith(obstacleWarning: 'OBSTACLE INFORMATION UNAVAILABLE');
      }
    });
    _receiptSyncTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      unawaited(synchronizePendingReceipts());
    });
    unawaited(_refreshPendingReceiptCount());
    unawaited(synchronizePendingReceipts());
    unawaited(_restorePendingReview());
  }

  final RoverRepository _repository;
  final LocalWifiRoverService _localWifiService;
  final PlantingReceiptRepository _receiptRepository;
  final DateTime _controllerStartedAt = DateTime.now();
  StreamSubscription<void>? _subscription;
  StreamSubscription<void>? _simulationSubscription;
  StreamSubscription<bool>? _localWifiSubscription;
  Timer? _localWifiDetectionTimer;
  Timer? _plantingStatusTimer;
  Timer? _obstacleStaleTimer;
  Timer? _receiptSyncTimer;
  DateTime? _plantingStartedAt;
  DateTime? _lastObstacleStatusAt;
  DateTime? _obstacleMonitoringStartedAt;
  bool _obstacleEpisodeActive = false;
  bool _refreshingPlantingStatus = false;
  Future<void> _movementCommandQueue = Future<void>.value();
  Future<void>? _receiptSyncInFlight;
  bool _syncRequestedWhileRunning = false;
  final Map<String, Future<void>> _terminalReceiptWrites = {};

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
      errorMessage: 'Connecting to the ESP32 on SeedRover-01...',
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

  Future<void> disconnectLocalWifi() async {
    if (!state.localWifiConnected ||
        state.localWifiDisconnecting ||
        state.localWifiConnecting) {
      return;
    }
    if (state.isPlantingLocked) {
      state = state.copyWith(
        errorMessage: 'Finish or stop the planting run before disconnecting.',
      );
      return;
    }
    state = state.copyWith(localWifiDisconnecting: true);
    try {
      if (state.activeMovement != null) {
        await sendMovement(RoverMovementCommand.stop);
        if (state.activeMovement != null) {
          throw StateError(
            state.errorMessage ?? 'Stop the rover before disconnecting.',
          );
        }
      }
      await _localWifiService.disconnect();
      state = state.copyWith(
        localWifiConnected: false,
        localWifiDisconnecting: false,
        clearPingRoundTrip: true,
        clearActiveMovement: true,
        lastCommand: 'Disconnected from SeedRover-01',
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        localWifiDisconnecting: false,
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
    }
  }

  Future<void> _monitorLocalWifi() async {
    if (!state.localWifiConnected ||
        state.localWifiConnecting ||
        state.isPinging) {
      return;
    }
    try {
      final result = await _localWifiService.ping();
      state = state.copyWith(
        localWifiConnected: true,
        pingRoundTripMs: result.roundTrip.inMilliseconds,
      );
    } catch (_) {
      state = state.copyWith(
        localWifiConnected: _localWifiService.isConnected,
        clearPingRoundTrip: true,
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

  Future<void> sendMovement(RoverMovementCommand command) {
    final commandFuture =
        _movementCommandQueue.then((_) => _sendMovement(command));
    _movementCommandQueue = commandFuture.catchError((Object _) {});
    return commandFuture;
  }

  Future<void> _sendMovement(RoverMovementCommand command) async {
    if (state.isPlantingLocked && command != RoverMovementCommand.stop) {
      state = state.copyWith(
        errorMessage:
            'Automatic planting controls movement. Use Stop to interrupt it.',
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
        if (command == RoverMovementCommand.stop) {
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

  Future<void> controlMechanism(String command, String label) async {
    if (!state.localWifiConnected) {
      state = state.copyWith(
        errorMessage: 'Connect directly to SeedRover-01 first.',
      );
      return;
    }
    if (state.isPlantingLocked) {
      state = state.copyWith(
        errorMessage:
            'Manual mechanism controls are locked during automatic planting.',
      );
      return;
    }
    try {
      final result = await _localWifiService.sendCommand(command);
      state = state.copyWith(
        lastCommand: '$label accepted in ${result.roundTrip.inMilliseconds} ms',
        clearErrorMessage: true,
      );
      if (command == 'RAKE_UP' || command == 'RAKE_DOWN') {
        await _refreshPlantingStatus();
      }
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
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
        final readings = await _localWifiService.checkAndReadSensors();
        final calibrated = readings['soil_moisture_calibrated'] == true &&
            readings['calibration_version'] != null;
        final moisture =
            calibrated ? (readings['soil_moisture_percent'] as num?) : null;
        if (moisture == null) {
          state = state.copyWith(
            plantingStatus: PlantingStatus.idle,
            soilCheckPassed: false,
            soilCheckMessage: calibrated
                ? 'Relative soil-moisture reading is unavailable.'
                : 'Soil-moisture reading unavailable.',
          );
          return;
        }
        state = state.copyWith(
          plantingStatus: PlantingStatus.idle,
          soilCheckPassed: false,
          soilCheckMessage:
              'Soil moisture: ${moisture.toDouble().toStringAsFixed(1)}%. ${soilMoistureReferenceLabel(moisture.toDouble())}.',
          lastCommand:
              'Soil check completed with ${moisture.toStringAsFixed(1)}% moisture.',
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

  Future<PlantingSoilPrecheck> precheckPlantingSoil() async {
    if (!state.localWifiConnected) {
      return const PlantingSoilPrecheck.unavailable(
        'Connect to SeedRover-01 before checking planting conditions.',
      );
    }
    if (state.isPlantingLocked) {
      return const PlantingSoilPrecheck.unavailable(
        'Stop the active planting run before checking soil.',
      );
    }

    state = state.copyWith(
      plantingStatus: PlantingStatus.checking,
      soilCheckMessage: 'Reading soil moisture and temperature…',
      clearErrorMessage: true,
    );
    try {
      final readings = await _localWifiService.precheckPlantingSoil();
      RoverCalibrationModel? calibration;
      try {
        calibration = await _localWifiService.getCalibration();
      } catch (_) {
        // A valid sensor pre-check remains reviewable without a diagnosis.
      }
      final result = PlantingSoilPrecheck.fromJson(
        readings,
        calibration: calibration,
      );
      state = state.copyWith(
        plantingStatus: PlantingStatus.idle,
        soilCheckPassed: result.isValid,
        soilCheckMessage: result.isValid
            ? 'Soil readings are ready to review.'
            : result.unavailableReason,
        lastCommand: result.isValid
            ? 'Planting soil pre-check completed'
            : 'Planting soil pre-check needs attention',
        clearErrorMessage: true,
      );
      return result;
    } catch (error) {
      final message = error.toString().replaceFirst('Bad state: ', '');
      state = state.copyWith(
        plantingStatus: PlantingStatus.idle,
        soilCheckPassed: false,
        soilCheckMessage: message,
        errorMessage: message,
      );
      return PlantingSoilPrecheck.unavailable(message);
    }
  }

  Future<void> cancelPlantingSoilPrecheck() async {
    try {
      await _localWifiService.cancelPlantingSoilPrecheck();
    } catch (_) {
      // Firmware expires the pre-check and raises the probe on disconnect.
    }
  }

  Future<void> startPlanting(
    PlantingRowConfig configuration, {
    required PlantingSoilPrecheck soilPrecheck,
  }) async {
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

    if (state.pendingConfirmationSessionId != null ||
        state.plantingOperation?.awaitingPhoneAck == true) {
      state = state.copyWith(
        errorMessage:
            'Review and save the previous row before starting another.',
      );
      return;
    }

    if (!state.localWifiConnected) {
      state = state.copyWith(
        errorMessage:
            'Connect directly to SeedRover-01 before starting a planting row.',
      );
      return;
    }
    if (!soilPrecheck.isValid || !soilPrecheck.isFreshAt(DateTime.now())) {
      state = state.copyWith(
        errorMessage: soilPrecheck.isValid
            ? 'The soil reading expired. Check the soil again before planting.'
            : soilPrecheck.unavailableReason,
      );
      await cancelPlantingSoilPrecheck();
      return;
    }
    try {
      // Persist the operator's intent before sending a physical start command.
      // If the phone loses power or Wi-Fi mid-row, status polling can recover
      // the matching configuration from this local draft.
      await _receiptRepository.saveDraft(configuration);
      _plantingStartedAt = DateTime.now();
      state = state.copyWith(
        selectedSeed: configuration.seed,
        activePlantingConfig: configuration,
        clearConfirmedPlantingSessionId: true,
      );
      await _localWifiService.startPlantingRow(
        configuration,
        soilSampledAtMs: soilPrecheck.sampledAtMs!,
      );
      state = state.copyWith(
        selectedSeed: configuration.seed,
        plantingStatus: PlantingStatus.checking,
        activePlantingConfig: configuration,
        clearActiveMovement: true,
        soilCheckMessage:
            'Soil pre-check confirmed. Lowering the rake before planting.',
        lastCommand: 'Row ${configuration.sessionId.substring(0, 8)} accepted',
        clearErrorMessage: true,
      );
      await _refreshPlantingStatus();
    } catch (error) {
      final message = error.toString().replaceFirst('Bad state: ', '');
      try {
        final operation = await _localWifiService.getPlantingStatus();
        if (operation.sessionId == configuration.sessionId) {
          state = state.copyWith(
            plantingOperation: operation,
            activePlantingConfig: configuration,
            plantingStatus: operation.state == 'PLANTING'
                ? PlantingStatus.active
                : (operation.state == 'RETURNING_TO_START'
                    ? PlantingStatus.returningToStart
                    : PlantingStatus.checking),
            lastCommand: 'Planting run recovered from rover status',
            clearErrorMessage: true,
          );
          return;
        }
      } catch (_) {}
      if (message.toLowerCase().contains('fresh calibrated moisture')) {
        await _receiptRepository.discardUnstartedDraft(configuration.sessionId);
        await cancelPlantingSoilPrecheck();
      }
      state = state.copyWith(
        errorMessage: message,
      );
    }
  }

  Future<void> plantNextRow({
    required PlantingSoilPrecheck soilPrecheck,
  }) async {
    final previous = state.activePlantingConfig;
    if (previous == null || state.isPlantingLocked) return;
    await startPlanting(previous.nextRow(), soilPrecheck: soilPrecheck);
  }

  Future<Map<String, dynamic>> checkCropSensors() async {
    if (!state.localWifiConnected) {
      throw StateError(
          'Connect the phone to SeedRover-01 before checking a crop.');
    }
    if (state.isPlantingLocked) {
      throw StateError('Stop the active planting run before checking sensors.');
    }
    if (state.telemetry?.isSimulated == true) {
      throw StateError('Simulated readings cannot be saved as crop readings.');
    }
    final readings = await _localWifiService.checkAndReadSensors();
    final recordedAt =
        DateTime.tryParse(readings['recorded_at']?.toString() ?? '')?.toLocal();
    final source = readings['source']?.toString();
    final firmwareVerified =
        (readings['firmware_version']?.toString().trim().isNotEmpty ?? false);
    final calibrated = readings['soil_moisture_calibrated'] == true &&
        (readings['calibration_version']?.toString().trim().isNotEmpty ??
            false);
    double? value(Object? raw, double min, double max) {
      final number = (raw as num?)?.toDouble();
      return number != null && number.isFinite && number >= min && number <= max
          ? number
          : null;
    }

    final telemetry = state.telemetry;
    if (telemetry != null) {
      state = state.copyWith(
        telemetry: telemetry.copyWith(sensors: [
          RoverSensorModel(
            label: 'Soil Moisture',
            value: calibrated
                ? value(readings['soil_moisture_percent'], 0, 100)
                : null,
            unit: '%',
            status: !firmwareVerified
                ? 'Unverified hardware reading'
                : calibrated
                    ? 'Fresh local hardware reading'
                    : 'Unavailable',
            recordedAt: recordedAt,
            source: source,
            calibrationVersion: readings['calibration_version']?.toString(),
            soilMoistureCalibrated:
                readings['soil_moisture_calibrated'] as bool?,
          ),
          RoverSensorModel(
            label: 'Soil Temperature',
            value: value(readings['soil_temperature_c'], -55, 125),
            unit: '°C',
            status: firmwareVerified
                ? 'Fresh verified hardware reading'
                : 'Unverified hardware reading',
            recordedAt: recordedAt,
            source: source,
          ),
          RoverSensorModel(
            label: 'Air Temperature',
            value: value(readings['air_temperature_c'], -40, 80),
            unit: '°C',
            status: firmwareVerified
                ? 'Fresh verified hardware reading'
                : 'Unverified hardware reading',
            recordedAt: recordedAt,
            source: source,
          ),
          RoverSensorModel(
            label: 'Humidity',
            value: value(readings['humidity_percent'], 0, 100),
            unit: '%',
            status: firmwareVerified
                ? 'Fresh verified hardware reading'
                : 'Unverified hardware reading',
            recordedAt: recordedAt,
            source: source,
          ),
        ]),
      );
    }
    return readings;
  }

  Future<RoverCalibrationModel> loadCalibration() {
    return _localWifiService.getCalibration();
  }

  Future<void> saveCalibration(RoverCalibrationModel calibration) async {
    if (!state.localWifiConnected) {
      throw StateError('Reconnect to SeedRover-01 before saving calibration.');
    }
    if (state.isPlantingLocked) {
      throw StateError(
          'Wait until the rover is idle before saving calibration.');
    }
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
    try {
      await _localWifiService.sendCommand('CANCEL_PLANTING');
      await _refreshPlantingStatus();
    } catch (error) {
      state = state.copyWith(
          errorMessage: error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _refreshPlantingStatus() async {
    if (!state.localWifiConnected || _refreshingPlantingStatus) return;
    _refreshingPlantingStatus = true;
    try {
      final operation = await _localWifiService.getPlantingStatus();
      final currentTelemetry = state.telemetry;
      if (currentTelemetry != null && !currentTelemetry.isSimulated) {
        state = state.copyWith(
          telemetry: currentTelemetry.copyWith(
            sensors: _localSensorModels(operation),
          ),
        );
      }
      _lastObstacleStatusAt = DateTime.now();
      final obstacleWarning = _obstacleWarning(operation);
      final hasObstacle = operation.frontObstacle || operation.rearObstacle;
      var alertSequence = state.obstacleAlertSequence;
      if (hasObstacle && !_obstacleEpisodeActive) {
        _obstacleEpisodeActive = true;
        alertSequence++;
      } else if (!hasObstacle &&
          operation.frontSensorAvailable &&
          operation.rearSensorAvailable) {
        _obstacleEpisodeActive = false;
      }
      state = state.copyWith(
        obstacleWarning: obstacleWarning,
        obstacleAlertSequence: alertSequence,
        clearObstacleWarning: obstacleWarning == null,
      );
      final mapped = switch (operation.state) {
        'CHECKING_SOIL' => PlantingStatus.checking,
        'LOWERING_RAKE' => PlantingStatus.loweringRake,
        'READY' => PlantingStatus.ready,
        'PLANTING' => PlantingStatus.active,
        'RETURNING_TO_START' => PlantingStatus.returningToStart,
        'PAUSED' => PlantingStatus.paused,
        'COMPLETED' => PlantingStatus.completed,
        'INTERRUPTED' => PlantingStatus.interrupted,
        'EMERGENCY_STOPPED' => PlantingStatus.emergencyStopped,
        'FAILED' || 'CANCELLED' => PlantingStatus.failed,
        _ => PlantingStatus.idle,
      };
      if (operation.sessionId.isEmpty) {
        state = state.copyWith(
          plantingStatus: mapped,
          plantingOperation: operation,
          clearActiveMovement: mapped != PlantingStatus.active &&
              mapped != PlantingStatus.returningToStart,
        );
        return;
      }

      final activeConfiguration = state.activePlantingConfig;
      PendingPlantingReceipt? recoveredReceipt;
      PlantingRowConfig? recoveredConfiguration =
          activeConfiguration?.sessionId == operation.sessionId
              ? activeConfiguration
              : null;
      if (recoveredConfiguration == null) {
        recoveredReceipt =
            await _receiptRepository.findRecord(operation.sessionId);
        if (recoveredReceipt != null) {
          recoveredConfiguration = recoveredReceipt.config;
          _plantingStartedAt = recoveredReceipt.startedAt;
        }
      }
      state = state.copyWith(
        plantingStatus: mapped,
        plantingOperation: operation,
        activePlantingConfig: recoveredConfiguration,
        clearActivePlantingConfig: recoveredConfiguration == null,
        confirmedPlantingSessionId: recoveredReceipt?.isConfirmed == true
            ? operation.sessionId
            : state.confirmedPlantingSessionId,
        lastConfirmedSyncedSessionId:
            recoveredReceipt?.confirmationSynced == true
                ? operation.sessionId
                : state.lastConfirmedSyncedSessionId,
        soilCheckPassed: operation.state != 'CHECKING_SOIL',
        soilCheckMessage: operation.state == 'RETURNING_TO_START'
            ? 'All ${operation.targetDrops} planting points completed. Returning to start line (leveling & molding).'
            : '${operation.completedDrops}/${operation.targetDrops} planting cycles acknowledged. Seed quantity and exact distance are not measured.',
        activeMovement: operation.state == 'PLANTING'
            ? RoverMovementCommand.forward
            : (operation.state == 'RETURNING_TO_START'
                ? RoverMovementCommand.backward
                : null),
        clearActiveMovement: operation.state != 'PLANTING' &&
            operation.state != 'RETURNING_TO_START',
        clearErrorMessage: true,
      );
      if (operation.isTerminal) {
        if (recoveredReceipt?.confirmationSynced != true) {
          await _storeTerminalReceipt(operation);
        }
        if (operation.awaitingPhoneAck) {
          await _acknowledgeConfirmedRoverResult(operation.sessionId);
        }
      }
    } catch (_) {
      // A lost hotspot connection is handled by the firmware heartbeat safety.
    } finally {
      _refreshingPlantingStatus = false;
    }
  }

  Future<void> _storeTerminalReceipt(PlantingOperationStatus operation) async {
    if (operation.sessionId.isEmpty) return;
    final inFlight = _terminalReceiptWrites[operation.sessionId];
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final storedReceipt =
        await _receiptRepository.findRecord(operation.sessionId);
    if (storedReceipt?.confirmationSynced == true) {
      return;
    }
    final storedStatus = storedReceipt?.status;
    final storedStatusMatches = storedStatus != null &&
        storedStatus.sessionId == operation.sessionId &&
        storedStatus.state == operation.state &&
        storedStatus.completedDrops == operation.completedDrops &&
        storedStatus.targetDrops == operation.targetDrops;
    if (storedStatusMatches) {
      if (storedReceipt != null && !storedReceipt.isConfirmed) {
        state = state.copyWith(
          pendingConfirmationSessionId: operation.sessionId,
        );
      }
      return;
    }
    final configuration = state.activePlantingConfig;
    if (configuration == null ||
        configuration.sessionId != operation.sessionId) {
      return;
    }
    final write = _persistTerminalReceipt(configuration, operation);
    _terminalReceiptWrites[operation.sessionId] = write;
    try {
      await write;
    } finally {
      _terminalReceiptWrites.remove(operation.sessionId);
    }
  }

  Future<void> _persistTerminalReceipt(
    PlantingRowConfig configuration,
    PlantingOperationStatus operation,
  ) async {
    final startedAt = _plantingStartedAt ?? DateTime.now();
    final soilCapturedAt = operation.soilCapturedAtMs == null
        ? null
        : startedAt.add(Duration(milliseconds: operation.soilCapturedAtMs!));
    await _receiptRepository.save(
      PendingPlantingReceipt(
        config: configuration,
        status: operation,
        startedAt: startedAt,
        completedAt: DateTime.now(),
        soilCapturedAt: soilCapturedAt,
      ),
    );
    final savedReceipt =
        await _receiptRepository.findPending(operation.sessionId);
    if (savedReceipt == null || !savedReceipt.isConfirmed) {
      state = state.copyWith(pendingConfirmationSessionId: operation.sessionId);
    }
    await _refreshPendingReceiptCount();
    unawaited(synchronizePendingReceipts());
  }

  Future<void> _refreshPendingReceiptCount() async {
    final pending = await _receiptRepository.loadPending();
    state = state.copyWith(pendingReceiptCount: pending.length);
  }

  Future<void> synchronizePendingReceipts() async {
    final activeSync = _receiptSyncInFlight;
    if (activeSync != null) {
      _syncRequestedWhileRunning = true;
      return activeSync;
    }
    final sync = _runQueuedReceiptSyncs();
    _receiptSyncInFlight = sync;
    try {
      await sync;
    } finally {
      if (identical(_receiptSyncInFlight, sync)) {
        _receiptSyncInFlight = null;
      }
    }
  }

  Future<void> _runQueuedReceiptSyncs() async {
    do {
      _syncRequestedWhileRunning = false;
      await _synchronizePendingReceiptsOnce();
    } while (_syncRequestedWhileRunning);
  }

  Future<void> _synchronizePendingReceiptsOnce() async {
    state = state.copyWith(syncingReceipts: true);
    try {
      final result = await _receiptRepository.synchronize();
      final pending = await _receiptRepository.loadPending();
      state = state.copyWith(
        syncingReceipts: false,
        pendingReceiptCount: pending.length,
        lastCreatedCropId: result.lastCropId,
        lastSyncedPlantingSessionId:
            result.lastSessionId ?? state.lastSyncedPlantingSessionId,
        lastConfirmedSyncedSessionId:
            result.lastConfirmedSessionId ?? state.lastConfirmedSyncedSessionId,
        lastCommand: result.synchronizedCount > 0
            ? '${result.synchronizedCount} planting record${result.synchronizedCount == 1 ? '' : 's'} synchronized'
            : state.lastCommand,
        errorMessage: result.failedCount > 0
            ? 'Could not sync ${result.failedCount} planting run${result.failedCount == 1 ? '' : 's'}: ${result.lastError ?? 'Check your internet and retry.'}'
            : null,
        clearErrorMessage: result.failedCount == 0,
      );
    } catch (_) {
      state = state.copyWith(
        syncingReceipts: false,
        errorMessage:
            'Could not save the planting run. Check your internet and retry.',
      );
    }
  }

  Future<void> onAppResumed() async {
    await synchronizePendingReceipts();
    await _monitorLocalWifi();
    await _refreshPlantingStatus();
  }

  Future<List<PendingPlantingReceipt>> loadPlantingRecords() =>
      _receiptRepository.loadRecords();

  Future<RoverCalibrationModel?> loadPendingCalibration() =>
      _receiptRepository.loadPendingCalibration();

  Future<void> reviewPlantingRecord(String sessionId) async {
    final receipt = await _receiptRepository.findPending(sessionId);
    if (receipt == null) return;
    state = state.copyWith(
      plantingOperation: receipt.status,
      activePlantingConfig: receipt.config,
      pendingConfirmationSessionId: sessionId,
      clearConfirmedPlantingSessionId: true,
    );
  }

  Future<bool> confirmPendingPlanting(String sessionId,
      {required String outcome}) async {
    try {
      // Confirmation is persisted locally before a network sync is attempted.
      await _receiptRepository.confirm(sessionId, outcome: outcome);
      state = state.copyWith(
        clearPendingConfirmationSessionId: true,
        confirmedPlantingSessionId: sessionId,
        lastCommand: 'Planting result saved on this phone',
        clearErrorMessage: true,
      );
      await _acknowledgeConfirmedRoverResult(sessionId);
      await _refreshPendingReceiptCount();
      unawaited(synchronizePendingReceipts());
      return true;
    } catch (error) {
      state = state.copyWith(
        errorMessage: error.toString().replaceFirst('Bad state: ', ''),
      );
      return false;
    }
  }

  Future<void> _acknowledgeConfirmedRoverResult(String sessionId) async {
    final receipt = await _receiptRepository.findRecord(sessionId);
    if (receipt?.isConfirmed != true || !state.localWifiConnected) return;
    try {
      await _localWifiService.sendCommand(
        'ACK_PLANTING_RESULT',
        payload: {'session_id': sessionId},
      );
    } catch (_) {
      // The rover retains the result; the next status refresh retries this ack.
    }
  }

  Future<void> _restorePendingReview() async {
    final pending = await _receiptRepository.loadPending();
    for (final receipt in pending) {
      if (!receipt.status.isTerminal || receipt.isConfirmed) continue;
      state = state.copyWith(
        plantingOperation: receipt.status,
        activePlantingConfig: receipt.config,
        pendingConfirmationSessionId: receipt.config.sessionId,
      );
      return;
    }
  }

  String? _obstacleWarning(PlantingOperationStatus operation) {
    final age = operation.obstacleSampleAgeMs;
    if (age == null || age < 0 || age > 3000) {
      return 'OBSTACLE INFORMATION UNAVAILABLE';
    }
    final frontAvailable = operation.frontSensorAvailable;
    final rearAvailable = operation.rearSensorAvailable;
    final frontObstacle = frontAvailable && operation.frontObstacle;
    final rearObstacle = rearAvailable && operation.rearObstacle;
    if (!frontAvailable && !rearAvailable) {
      return 'FRONT/REAR OBSTACLE SENSOR UNAVAILABLE';
    }
    if (frontObstacle && rearObstacle) {
      return 'OBSTACLES AHEAD AND BEHIND';
    }
    if (frontObstacle) return 'OBSTACLE AHEAD';
    if (rearObstacle) return 'OBSTACLE BEHIND';
    if (!frontAvailable) return 'FRONT OBSTACLE SENSOR UNAVAILABLE';
    if (!rearAvailable) return 'REAR OBSTACLE SENSOR UNAVAILABLE';
    return null;
  }

  List<RoverSensorModel> _localSensorModels(
    PlantingOperationStatus operation,
  ) {
    final now = DateTime.now();
    DateTime? sampledAt(int? ageMs) {
      if (ageMs == null || ageMs < 0) return null;
      return now.subtract(Duration(milliseconds: ageMs));
    }

    String statusFor(double? value, int? ageMs) {
      if (value == null) return 'Unavailable';
      if (ageMs == null) return 'Local hardware reading · age unavailable';
      if (ageMs > const Duration(minutes: 1).inMilliseconds) {
        return 'Stale local hardware reading';
      }
      return 'Fresh local hardware reading';
    }

    final moisture =
        operation.soilMoistureCalibrated == true ? operation.soilPercent : null;
    final soilAge = operation.soilSampleAgeMs;
    final environmentAge = operation.environmentSampleAgeMs;
    return [
      RoverSensorModel(
        label: 'Soil Moisture',
        value: moisture,
        unit: '%',
        status: moisture == null ? 'Unavailable' : statusFor(moisture, soilAge),
        recordedAt: sampledAt(soilAge),
        source: 'SeedRover local Wi-Fi',
        calibrationVersion: operation.calibrationVersion,
        soilMoistureCalibrated: operation.soilMoistureCalibrated,
      ),
      RoverSensorModel(
        label: 'Soil Temperature',
        value: operation.soilTemperatureC,
        unit: '°C',
        status: statusFor(operation.soilTemperatureC, soilAge),
        recordedAt: sampledAt(soilAge),
        source: 'SeedRover local Wi-Fi',
      ),
      RoverSensorModel(
        label: 'Air Temperature',
        value: operation.airTemperatureC,
        unit: '°C',
        status: statusFor(operation.airTemperatureC, environmentAge),
        recordedAt: sampledAt(environmentAge),
        source: 'SeedRover local Wi-Fi',
      ),
      RoverSensorModel(
        label: 'Humidity',
        value: operation.humidityPercent,
        unit: '%',
        status: statusFor(operation.humidityPercent, environmentAge),
        recordedAt: sampledAt(environmentAge),
        source: 'SeedRover local Wi-Fi',
      ),
    ];
  }

  Future<void> emergencyStop() async {
    if (!state.isPlantingLocked) {
      return;
    }

    state = state.copyWith(
      lastCommand: 'Sending emergency stop command',
      soilCheckMessage: 'Sending emergency stop command…',
      clearErrorMessage: true,
    );

    if (state.localWifiConnected) {
      try {
        await _localWifiService.sendCommand('EMERGENCY_STOP');
      } catch (error) {
        state = state.copyWith(
          errorMessage: 'Stop not confirmed. Keep the rover in view and retry.',
          soilCheckMessage:
              'Stop not confirmed. Keep the rover in view and retry.',
        );
        return;
      }
    } else {
      try {
        await _repository.sendEmergencyStop();
      } catch (_) {
        state = state.copyWith(
          errorMessage: 'Stop not confirmed. Keep the rover in view and retry.',
          soilCheckMessage:
              'Stop not confirmed. Keep the rover in view and retry.',
        );
        return;
      }
    }

    state = state.copyWith(
      plantingStatus: PlantingStatus.emergencyStopped,
      clearActiveMovement: true,
      lastCommand: 'Emergency stop command acknowledged',
      soilCheckMessage:
          'Emergency stop command acknowledged. Check the rover before resuming.',
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

  void setCameraFullscreen(bool fullscreen) {
    state = state.copyWith(cameraFullscreen: fullscreen);
  }

  @override
  void dispose() {
    _localWifiDetectionTimer?.cancel();
    _plantingStatusTimer?.cancel();
    _obstacleStaleTimer?.cancel();
    _receiptSyncTimer?.cancel();
    _subscription?.cancel();
    _simulationSubscription?.cancel();
    _localWifiSubscription?.cancel();
    super.dispose();
  }
}
