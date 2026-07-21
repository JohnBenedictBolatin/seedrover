import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'communication_command.dart';
import 'communication_device.dart';
import 'communication_enums.dart';
import 'communication_repository.dart';
import 'communication_state.dart';
import 'hardware_simulator_state.dart';

class CommunicationController extends StateNotifier<CommunicationState> {
  CommunicationController(this._repository)
      : super(CommunicationState.initial()) {
    _stateSubscription = _repository.connectionStateStream.listen(
      _handleConnectionState,
    );
    _devicesSubscription = _repository.discoveredDevicesStream.listen(
      (devices) => state = state.copyWith(discoveredDevices: devices),
    );
    _simulatorSubscription = _repository.simulatorStateStream.listen(
      (simulatorState) => state = state.copyWith(
        simulatorState: simulatorState,
      ),
    );
    state = state.copyWith(simulatorState: _repository.simulatorState);
  }

  final CommunicationRepository _repository;
  StreamSubscription<CommunicationConnectionState>? _stateSubscription;
  StreamSubscription<List<CommunicationDevice>>? _devicesSubscription;
  StreamSubscription<HardwareSimulatorState>? _simulatorSubscription;

  Future<void> useTransport(CommunicationTransport transport) async {
    await _runSafely(
      () => _repository.useTransport(transport),
      fallbackMessage: '${transport.label} is not ready yet.',
    );
    state = state.copyWith(activeTransport: transport);
  }

  Future<void> scan() async {
    await _runSafely(
      _repository.scan,
      fallbackMessage: 'Unable to scan for rover devices.',
    );
  }

  Future<void> stopScan() async {
    await _runSafely(
      _repository.stopScan,
      fallbackMessage: 'Unable to stop scanning.',
    );
  }

  Future<void> refreshScan() async {
    await _runSafely(
      _repository.refreshScan,
      fallbackMessage: 'Unable to refresh rover scan.',
    );
  }

  Future<void> connect(CommunicationDevice device) async {
    await _runSafely(
      () => _repository.connect(device),
      fallbackMessage: 'Unable to connect to ${device.name}.',
    );
  }

  Future<void> disconnect() async {
    await _runSafely(
      _repository.disconnect,
      fallbackMessage: 'Unable to disconnect from the rover.',
    );
  }

  Future<void> reconnect() async {
    await _runSafely(
      _repository.reconnect,
      fallbackMessage: 'Unable to reconnect to the rover.',
    );
  }

  Future<void> sendCommand(
    CommunicationCommandType type, {
    Map<String, Object?> payload = const {},
  }) async {
    final command = CommunicationCommand(
      type: type,
      timestamp: DateTime.now(),
      payload: payload,
    );

    state = state.copyWith(
      lastCommand: command,
      queueLength: _repository.queueLength + 1,
      errorMessage: null,
    );

    final response = await _repository.sendCommand(command);

    state = state.copyWith(
      lastCommand: command.copyWith(
        status: response.success
            ? CommunicationCommandStatus.success
            : CommunicationCommandStatus.failed,
      ),
      lastResponse: response,
      queueLength: _repository.queueLength,
      errorMessage: response.success
          ? null
          : response.errorMessage ?? 'The rover could not complete the command.',
    );
  }

  void setSimulatorBatteryLevel(int value) {
    _repository.setSimulatorBatteryLevel(value);
  }

  void rechargeSimulatorBattery() {
    _repository.rechargeSimulatorBattery();
  }

  void setSimulatorSeedLevel(int value) {
    _repository.setSimulatorSeedLevel(value);
  }

  void setSimulatorCurrentActivity(String value) {
    _repository.setSimulatorCurrentActivity(value);
  }

  void setSimulatorSensorValues({
    double? soilMoisture,
    double? soilTemperature,
    double? environmentTemperature,
    double? humidity,
  }) {
    _repository.setSimulatorSensorValues(
      soilMoisture: soilMoisture,
      soilTemperature: soilTemperature,
      environmentTemperature: environmentTemperature,
      humidity: humidity,
    );
  }

  void triggerSimulatorLowBattery() {
    _repository.triggerSimulatorLowBattery();
  }

  void triggerSimulatorCriticalBattery() {
    _repository.triggerSimulatorCriticalBattery();
  }

  void triggerSimulatorConnectionLost() {
    _repository.triggerSimulatorConnectionLost();
  }

  void triggerSimulatorCameraFailure() {
    _repository.triggerSimulatorCameraFailure();
  }

  void triggerSimulatorSensorFailure() {
    _repository.triggerSimulatorSensorFailure();
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _devicesSubscription?.cancel();
    _simulatorSubscription?.cancel();
    super.dispose();
  }

  void _handleConnectionState(CommunicationConnectionState nextState) {
    state = state.copyWith(
      connectionState: nextState,
      activeTransport: _repository.activeTransport,
      connectedDevice: _repository.connectedDevice,
      connectionStartedAt: nextState == CommunicationConnectionState.connected
          ? state.connectionStartedAt ?? DateTime.now()
          : null,
      errorMessage: nextState == CommunicationConnectionState.error
          ? 'Communication error. Please reconnect.'
          : null,
    );
  }

  Future<void> _runSafely(
    Future<void> Function() action, {
    required String fallbackMessage,
  }) async {
    try {
      await action();
      state = state.copyWith(errorMessage: null);
    } catch (_) {
      state = state.copyWith(
        connectionState: CommunicationConnectionState.error,
        errorMessage: fallbackMessage,
      );
    }
  }
}
