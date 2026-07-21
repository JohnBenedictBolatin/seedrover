import 'dart:async';

import 'communication_command.dart';
import 'communication_device.dart';
import 'communication_enums.dart';
import 'communication_exception.dart';
import 'communication_json_parser.dart';
import 'communication_message.dart';
import 'communication_response.dart';
import 'communication_service.dart';
import 'hardware_simulator.dart';
import 'hardware_simulator_state.dart';

abstract class SimulatedCommunicationService implements CommunicationService {
  SimulatedCommunicationService({
    required this.transport,
    required List<CommunicationDevice> devices,
    CommunicationJsonParser parser = const CommunicationJsonParser(),
    HardwareSimulator? simulator,
    bool isEnabled = true,
  })  : _devices = devices,
        _parser = parser,
        _simulator = simulator ?? HardwareSimulator(parser: parser),
        _isEnabled = isEnabled {
    _simulator.onConnectionLost = _handleSimulatorConnectionLost;
    _simulator.start();
  }

  @override
  final CommunicationTransport transport;

  final List<CommunicationDevice> _devices;
  final CommunicationJsonParser _parser;
  final HardwareSimulator _simulator;
  final bool _isEnabled;
  final _stateController =
      StreamController<CommunicationConnectionState>.broadcast();
  final _devicesController =
      StreamController<List<CommunicationDevice>>.broadcast();

  CommunicationConnectionState _state =
      CommunicationConnectionState.disconnected;
  CommunicationDevice? _connectedDevice;
  bool _scanActive = false;

  Stream<HardwareSimulatorState> get simulatorStateStream {
    return _simulator.stateStream;
  }

  HardwareSimulatorState get simulatorState => _simulator.state;

  @override
  Stream<CommunicationConnectionState> get connectionStateStream {
    return _stateController.stream;
  }

  @override
  Stream<List<CommunicationDevice>> get discoveredDevicesStream {
    return _devicesController.stream;
  }

  @override
  CommunicationConnectionState get connectionState => _state;

  @override
  CommunicationDevice? get connectedDevice => _connectedDevice;

  @override
  Future<void> scan() async {
    _ensureEnabled();
    _scanActive = true;
    _setState(CommunicationConnectionState.scanning);
    await Future<void>.delayed(const Duration(milliseconds: 350));

    if (!_scanActive) {
      return;
    }

    _devicesController.add(_devices);
    _setState(
      _connectedDevice == null
          ? CommunicationConnectionState.disconnected
          : CommunicationConnectionState.connected,
    );
  }

  @override
  Future<void> stopScan() async {
    _scanActive = false;
    _setState(
      _connectedDevice == null
          ? CommunicationConnectionState.disconnected
          : CommunicationConnectionState.connected,
    );
  }

  @override
  Future<void> refreshScan() async {
    await stopScan();
    await scan();
  }

  @override
  Future<void> connect(CommunicationDevice device) async {
    _ensureEnabled();

    if (_connectedDevice?.id == device.id &&
        _state == CommunicationConnectionState.connected) {
      return;
    }

    if (_state == CommunicationConnectionState.connecting) {
      throw const CommunicationException('Connection is already in progress.');
    }

    if (!device.isAvailable) {
      _setState(CommunicationConnectionState.error);
      throw const CommunicationException('This rover connection is unavailable.');
    }

    _setState(CommunicationConnectionState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _connectedDevice = device.copyWith(
      connectionState: CommunicationConnectionState.connected,
    );
    _setState(CommunicationConnectionState.connected);
    _simulator.setCurrentActivity('Connected');
  }

  @override
  Future<void> disconnect() async {
    if (_state == CommunicationConnectionState.disconnected) {
      return;
    }

    _setState(CommunicationConnectionState.disconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 220));
    _connectedDevice = null;
    _setState(CommunicationConnectionState.disconnected);
    _simulator.setCurrentActivity('Disconnected');
  }

  @override
  Future<void> reconnect() async {
    final device = _connectedDevice ?? (_devices.isEmpty ? null : _devices.first);

    if (device == null) {
      throw const CommunicationException('No rover device is available.');
    }

    _setState(CommunicationConnectionState.reconnecting);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    await connect(device);
  }

  @override
  Future<CommunicationResponse> sendCommand(
    CommunicationCommand command,
  ) async {
    if (!_isEnabled) {
      return CommunicationResponse(
        responseType: CommunicationResponseType.disconnected,
        timestamp: DateTime.now(),
        success: false,
        errorMessage: '${transport.label} is disabled.',
      );
    }

    if (_state != CommunicationConnectionState.connected) {
      return CommunicationResponse(
        responseType: CommunicationResponseType.disconnected,
        timestamp: DateTime.now(),
        success: false,
        errorMessage: 'Connect to the rover before sending commands.',
      );
    }

    final rawResponse = await _simulator.handleCommand(command);

    return _parser.parseResponse(rawResponse);
  }

  @override
  Future<CommunicationResponse> send(CommunicationMessage message) {
    return sendCommand(message.toCommand());
  }

  void dispose() {
    _simulator.dispose();
    _stateController.close();
    _devicesController.close();
  }

  void setSimulatorBatteryLevel(int value) {
    _simulator.setBatteryLevel(value);
  }

  void rechargeSimulatorBattery() {
    _simulator.rechargeBattery();
  }

  void setSimulatorSeedLevel(int value) {
    _simulator.setSeedLevel(value);
  }

  void setSimulatorCurrentActivity(String value) {
    _simulator.setCurrentActivity(value);
  }

  void setSimulatorSensorValues({
    double? soilMoisture,
    double? soilTemperature,
    double? environmentTemperature,
    double? humidity,
  }) {
    _simulator.setSensorValues(
      soilMoisture: soilMoisture,
      soilTemperature: soilTemperature,
      environmentTemperature: environmentTemperature,
      humidity: humidity,
    );
  }

  void triggerSimulatorLowBattery() {
    _simulator.triggerLowBattery();
  }

  void triggerSimulatorCriticalBattery() {
    _simulator.triggerCriticalBattery();
  }

  void triggerSimulatorConnectionLost() {
    _simulator.triggerConnectionLost();
  }

  void triggerSimulatorCameraFailure() {
    _simulator.triggerCameraFailure();
  }

  void triggerSimulatorSensorFailure() {
    _simulator.triggerSensorFailure();
  }

  void _setState(CommunicationConnectionState state) {
    _state = state;
    _stateController.add(state);
  }

  void _ensureEnabled() {
    if (!_isEnabled) {
      _setState(CommunicationConnectionState.error);
      throw CommunicationException('${transport.label} is disabled.');
    }
  }

  void _handleSimulatorConnectionLost() {
    _connectedDevice = null;
    _setState(CommunicationConnectionState.error);
  }
}
