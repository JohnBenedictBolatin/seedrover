import 'dart:async';
import 'dart:math';

import 'communication_command.dart';
import 'communication_enums.dart';
import 'communication_json_parser.dart';
import 'hardware_simulator_state.dart';

class HardwareSimulator {
  HardwareSimulator({
    CommunicationJsonParser parser = const CommunicationJsonParser(),
    Random? random,
  })  : _parser = parser,
        _random = random ?? Random(37);

  final CommunicationJsonParser _parser;
  final Random _random;
  final _stateController =
      StreamController<HardwareSimulatorState>.broadcast();
  void Function()? onConnectionLost;
  HardwareSimulatorState _state = HardwareSimulatorState.initial();
  Timer? _sensorTimer;
  Timer? _drainTimer;
  Timer? _cameraTimer;
  Timer? _plantingTimer;
  Timer? _randomErrorTimer;
  bool _lowBatterySent = false;
  bool _criticalBatterySent = false;
  bool _lowSeedSent = false;
  bool _outOfSeedSent = false;
  bool _running = false;
  bool _disposed = false;

  Stream<HardwareSimulatorState> get stateStream => _stateController.stream;
  HardwareSimulatorState get state => _state;

  void start() {
    if (_running) {
      return;
    }

    _running = true;
    _stateController.add(_state);
    _sensorTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _updateSensors(),
    );
    _drainTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _drainBattery(),
    );
    _cameraTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _advanceCameraFrame(),
    );
    _randomErrorTimer = Timer.periodic(
      const Duration(seconds: 18),
      (_) => _maybeSimulateRandomError(),
    );
  }

  void dispose() {
    _disposed = true;
    _sensorTimer?.cancel();
    _drainTimer?.cancel();
    _cameraTimer?.cancel();
    _plantingTimer?.cancel();
    _randomErrorTimer?.cancel();
    _stateController.close();
  }

  Future<String> handleCommand(CommunicationCommand command) async {
    await Future<void>.delayed(_commandDelayFor(command.type));

    final payload = switch (command.type) {
      CommunicationCommandType.moveForward => _move(
          command,
          activity: 'Moving Forward',
          details: 'Rover moved forward.',
        ),
      CommunicationCommandType.moveBackward => _move(
          command,
          activity: 'Moving Backward',
          details: 'Rover moved backward.',
        ),
      CommunicationCommandType.turnLeft => _move(
          command,
          activity: 'Turning Left',
          details: 'Rover turned left.',
        ),
      CommunicationCommandType.turnRight => _move(
          command,
          activity: 'Turning Right',
          details: 'Rover turned right.',
        ),
      CommunicationCommandType.stop => _stop(command),
      CommunicationCommandType.startPlanting => _startPlanting(command),
      CommunicationCommandType.pausePlanting => _pausePlanting(command),
      CommunicationCommandType.resumePlanting => _resumePlanting(command),
      CommunicationCommandType.stopPlanting => _stopPlanting(command),
      CommunicationCommandType.emergencyStop => _emergencyStop(command),
      CommunicationCommandType.statusRequest => _statusPayload(),
      CommunicationCommandType.sensorRequest => _sensorPayload(),
      CommunicationCommandType.batteryRequest => {
          'battery_level': _state.batteryLevel,
        },
      CommunicationCommandType.seedLevelRequest => {
          'seed_level': _state.seedLevel,
        },
      CommunicationCommandType.startCamera => _setCamera(command, 'Loading'),
      CommunicationCommandType.stopCamera => _setCamera(command, 'Disconnected'),
      CommunicationCommandType.refreshCamera => _refreshCamera(command),
      CommunicationCommandType.ping => const {
          'message': 'PONG',
        },
      CommunicationCommandType.unsupported => null,
    };

    return _parser.encodeCommand({
      'status': payload == null ? 'invalid_command' : 'success',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      if (payload != null) 'data': payload,
      if (payload == null) 'message': 'Unsupported command.',
    });
  }

  void setBatteryLevel(int value) {
    _emit(_state.copyWith(batteryLevel: value.clamp(0, 100).toInt()));
    _evaluateBatteryNotifications();
  }

  void rechargeBattery() {
    _lowBatterySent = false;
    _criticalBatterySent = false;
    _emit(_state.copyWith(
      batteryLevel: 100,
      lastError: null,
    ));
    _recordActivity(
      CommunicationCommandType.batteryRequest,
      'Battery Recharged',
      'Simulator battery was manually recharged.',
    );
  }

  void setSeedLevel(int value) {
    _emit(_state.copyWith(seedLevel: value.clamp(0, 100).toInt()));
    _evaluateSeedNotifications();
  }

  void setCurrentActivity(String value) {
    _emit(_state.copyWith(currentActivity: value.trim().isEmpty ? 'Idle' : value));
  }

  void setSensorValues({
    double? soilMoisture,
    double? soilTemperature,
    double? environmentTemperature,
    double? humidity,
  }) {
    _emit(_state.copyWith(
      soilMoisture: soilMoisture?.clamp(0, 100).toDouble(),
      soilTemperature: soilTemperature?.clamp(15, 45).toDouble(),
      environmentTemperature: environmentTemperature?.clamp(18, 45).toDouble(),
      humidity: humidity?.clamp(30, 95).toDouble(),
    ));
  }

  void triggerLowBattery() {
    setBatteryLevel(19);
  }

  void triggerCriticalBattery() {
    setBatteryLevel(8);
  }

  void triggerConnectionLost() {
    _emit(_state.copyWith(
      currentActivity: 'Connection Lost',
      isMoving: false,
      isPlanting: false,
      lastError: 'Connection lost while simulating rover activity.',
    ));
    _addNotification(
      title: 'Connection Lost',
      message: 'The simulated rover connection dropped.',
      type: 'connection_lost',
      relatedModule: 'rover',
      actionRoute: '/rover',
    );
    onConnectionLost?.call();
  }

  void triggerCameraFailure() {
    _emit(_state.copyWith(
      cameraStatus: 'Disconnected',
      lastError: 'Camera feed failed in simulator.',
    ));
    _addNotification(
      title: 'Camera Disconnected',
      message: 'The simulated camera feed is unavailable.',
      type: 'camera_failure',
      relatedModule: 'rover',
      actionRoute: '/rover',
    );
  }

  void triggerSensorFailure() {
    _emit(_state.copyWith(lastError: 'Sensor response failed in simulator.'));
    _addNotification(
      title: 'Sensor Failure',
      message: 'The simulated rover could not read sensor data.',
      type: 'sensor_failure',
      relatedModule: 'rover',
      actionRoute: '/rover',
    );
  }

  Map<String, Object?> _move(
    CommunicationCommand command, {
    required String activity,
    required String details,
  }) {
    _emit(_state.copyWith(
      currentActivity: activity,
      isMoving: true,
      lastError: null,
    ));
    _recordActivity(command.type, activity, details);

    return {
      'command_id': command.id,
      'movement_status': 'success',
      'current_activity': activity,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  Map<String, Object?> _stop(CommunicationCommand command) {
    _emit(_state.copyWith(
      currentActivity: 'Stopped',
      isMoving: false,
      lastError: null,
    ));
    _recordActivity(command.type, 'Rover Stopped', 'Movement stopped.');

    return {
      'command_id': command.id,
      'movement_status': 'stopped',
      'current_activity': 'Stopped',
    };
  }

  Map<String, Object?> _startPlanting(CommunicationCommand command) {
    final seedName = command.payload['seed_name'] as String? ?? 'selected seed';
    final nextSeedLevel = (_state.seedLevel - 8).clamp(0, 100).toInt();
    _emit(_state.copyWith(
      currentActivity: 'Planting $seedName',
      plantingStatus: 'Planting Started',
      seedLevel: nextSeedLevel,
      isMoving: false,
      isPlanting: true,
      lastError: null,
    ));
    _recordActivity(
      command.type,
      'Planting Started',
      'Simulated planting operation started for $seedName.',
    );
    _evaluateSeedNotifications();
    _plantingTimer?.cancel();
    _plantingTimer = Timer(const Duration(seconds: 12), _completePlanting);

    return {
      'planting_status': _state.plantingStatus,
      'seed_name': seedName,
      'seed_type': command.payload['seed_type'],
      'seed_level': _state.seedLevel,
      'current_activity': _state.currentActivity,
    };
  }

  Map<String, Object?> _pausePlanting(CommunicationCommand command) {
    _emit(_state.copyWith(
      currentActivity: 'Planting Paused',
      plantingStatus: 'Paused',
      isPlanting: false,
    ));
    _recordActivity(command.type, 'Planting Paused', 'Planting was paused.');

    return {
      'planting_status': _state.plantingStatus,
      'current_activity': _state.currentActivity,
    };
  }

  Map<String, Object?> _resumePlanting(CommunicationCommand command) {
    _emit(_state.copyWith(
      currentActivity: 'Planting',
      plantingStatus: 'Planting Resumed',
      isPlanting: true,
    ));
    _recordActivity(command.type, 'Planting Resumed', 'Planting resumed.');

    return {
      'planting_status': _state.plantingStatus,
      'current_activity': _state.currentActivity,
    };
  }

  Map<String, Object?> _stopPlanting(CommunicationCommand command) {
    _plantingTimer?.cancel();
    _emit(_state.copyWith(
      currentActivity: 'Idle',
      plantingStatus: 'Stopped',
      isPlanting: false,
    ));
    _recordActivity(command.type, 'Planting Stopped', 'Planting stopped.');

    return {
      'planting_status': _state.plantingStatus,
      'current_activity': _state.currentActivity,
    };
  }

  Map<String, Object?> _emergencyStop(CommunicationCommand command) {
    _plantingTimer?.cancel();
    _emit(_state.copyWith(
      currentActivity: 'Emergency Stop',
      plantingStatus: 'Stopped',
      isMoving: false,
      isPlanting: false,
      lastError: 'Emergency stop activated.',
    ));
    _recordActivity(
      command.type,
      'Emergency Stop',
      'All simulated rover operations stopped immediately.',
    );
    _addNotification(
      title: 'Emergency Stop Activated',
      message: 'SeedRover stopped all simulated operations.',
      type: 'emergency_stop',
      relatedModule: 'rover',
      actionRoute: '/rover',
    );

    return const {
      'emergency_stop': true,
      'movement_status': 'stopped',
      'planting_status': 'stopped',
    };
  }

  Map<String, Object?> _setCamera(
    CommunicationCommand command,
    String status,
  ) {
    _emit(_state.copyWith(cameraStatus: status));
    _recordActivity(
      command.type,
      'Camera $status',
      'Camera simulator changed to $status.',
    );

    if (status == 'Loading') {
      Timer(const Duration(milliseconds: 700), () {
        _emit(_state.copyWith(cameraStatus: 'Connected'));
      });
    }

    return _cameraPayload();
  }

  Map<String, Object?> _refreshCamera(CommunicationCommand command) {
    _advanceCameraFrame();
    _recordActivity(
      command.type,
      'Camera Refreshed',
      'Camera placeholder frame changed.',
    );

    return _cameraPayload();
  }

  Map<String, Object?> _statusPayload() {
    return {
      'battery_level': _state.batteryLevel,
      'seed_level': _state.seedLevel,
      'current_activity': _state.currentActivity,
      'planting_status': _state.plantingStatus,
      'wifi_connected': true,
      'bluetooth_connected': true,
      'camera_connected': _state.cameraStatus == 'Connected',
      'camera_status': _state.cameraStatus,
      'emergency_stop': _state.currentActivity == 'Emergency Stop',
    };
  }

  Map<String, Object?> _sensorPayload() {
    return {
      'soil_moisture': _state.soilMoisture.round(),
      'soil_temperature': _state.soilTemperature.round(),
      'environment_temperature': _state.environmentTemperature.round(),
      'humidity': _state.humidity.round(),
    };
  }

  Map<String, Object?> _cameraPayload() {
    return {
      'camera_status': _state.cameraStatus,
      'stream_url': null,
      'placeholder': _state.cameraPlaceholder,
      'frame_index': _state.cameraFrameIndex,
    };
  }

  void _completePlanting() {
    _emit(_state.copyWith(
      currentActivity: 'Idle',
      plantingStatus: 'Completed',
      isPlanting: false,
    ));
    _recordActivity(
      CommunicationCommandType.startPlanting,
      'Planting Completed',
      'Simulated planting operation completed.',
    );
    _addNotification(
      title: 'Planting Completed',
      message: 'SeedRover finished the simulated planting operation.',
      type: 'planting_completed',
      relatedModule: 'crops',
      actionRoute: '/crops',
    );
  }

  void _updateSensors() {
    setSensorValues(
      soilMoisture: _jitter(_state.soilMoisture, min: 28, max: 78, step: 4),
      soilTemperature:
          _jitter(_state.soilTemperature, min: 22, max: 34, step: 1.5),
      environmentTemperature:
          _jitter(_state.environmentTemperature, min: 24, max: 38, step: 1.8),
      humidity: _jitter(_state.humidity, min: 48, max: 88, step: 3),
    );
  }

  void _drainBattery() {
    var drain = 0;
    if (_state.isMoving) {
      drain += 1;
    }
    if (_state.isPlanting) {
      drain += 1;
    }
    if (_state.cameraStatus == 'Connected') {
      drain += 1;
    }

    if (drain == 0 || _state.batteryLevel == 0) {
      return;
    }

    _emit(_state.copyWith(
      batteryLevel: (_state.batteryLevel - drain).clamp(0, 100).toInt(),
    ));
    _evaluateBatteryNotifications();
  }

  void _advanceCameraFrame() {
    if (_state.cameraStatus != 'Connected') {
      return;
    }

    final nextFrame = _state.cameraFrameIndex == 3
        ? 1
        : _state.cameraFrameIndex + 1;
    _emit(_state.copyWith(
      cameraFrameIndex: nextFrame,
      cameraPlaceholder: 'Field View $nextFrame',
    ));
  }

  void _maybeSimulateRandomError() {
    final roll = _random.nextInt(100);

    if (roll < 2) {
      triggerConnectionLost();
    } else if (roll < 4) {
      triggerCameraFailure();
    } else if (roll < 6) {
      triggerSensorFailure();
    }
  }

  void _evaluateBatteryNotifications() {
    if (_state.batteryLevel <= 10 && !_criticalBatterySent) {
      _criticalBatterySent = true;
      _addNotification(
        title: 'Critical Battery',
        message: 'SeedRover simulator battery is critically low.',
        type: 'critical_battery',
        relatedModule: 'rover',
        actionRoute: '/rover',
      );
      return;
    }

    if (_state.batteryLevel <= 20 && !_lowBatterySent) {
      _lowBatterySent = true;
      _addNotification(
        title: 'Low Battery',
        message: 'SeedRover simulator battery is getting low.',
        type: 'low_battery',
        relatedModule: 'rover',
        actionRoute: '/rover',
      );
    }
  }

  void _evaluateSeedNotifications() {
    if (_state.seedLevel == 0 && !_outOfSeedSent) {
      _outOfSeedSent = true;
      _addNotification(
        title: 'Out of Seed',
        message: 'The simulated seed container is empty.',
        type: 'out_of_seed',
        relatedModule: 'inventory',
        actionRoute: '/stocks',
      );
      return;
    }

    if (_state.seedLevel <= 20 && !_lowSeedSent) {
      _lowSeedSent = true;
      _addNotification(
        title: 'Low Seed Level',
        message: 'The simulated seed container is running low.',
        type: 'low_seed',
        relatedModule: 'inventory',
        actionRoute: '/stocks',
      );
    }
  }

  void _recordActivity(
    CommunicationCommandType commandType,
    String action,
    String details,
  ) {
    final log = HardwareActivityLog(
      id: 'ACT-${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      action: action,
      details: details,
      commandType: commandType,
    );
    final logs = [log, ..._state.activityLogs].take(60).toList();
    _emit(_state.copyWith(activityLogs: logs));
  }

  void _addNotification({
    required String title,
    required String message,
    required String type,
    String? relatedModule,
    String? relatedId,
    String? actionRoute,
    Map<String, Object?> payload = const <String, Object?>{},
  }) {
    final notification = HardwareSimulatorEvent(
      id: 'SIM-${DateTime.now().microsecondsSinceEpoch}',
      timestamp: DateTime.now(),
      title: title,
      message: message,
      type: type,
      relatedModule: relatedModule,
      relatedId: relatedId,
      actionRoute: actionRoute,
      payload: payload,
    );
    final notifications = [
      notification,
      ..._state.notifications,
    ].take(60).toList();
    _emit(_state.copyWith(notifications: notifications));
  }

  void _emit(HardwareSimulatorState state) {
    if (_disposed) {
      return;
    }

    _state = state;
    _stateController.add(_state);
  }

  Duration _commandDelayFor(CommunicationCommandType type) {
    return switch (type) {
      CommunicationCommandType.statusRequest ||
      CommunicationCommandType.sensorRequest ||
      CommunicationCommandType.batteryRequest ||
      CommunicationCommandType.seedLevelRequest ||
      CommunicationCommandType.ping =>
        const Duration(milliseconds: 180),
      CommunicationCommandType.startCamera => const Duration(milliseconds: 260),
      _ => const Duration(milliseconds: 320),
    };
  }

  double _jitter(
    double value, {
    required double min,
    required double max,
    required double step,
  }) {
    final delta = (_random.nextDouble() * step * 2) - step;
    return (value + delta).clamp(min, max).toDouble();
  }
}
