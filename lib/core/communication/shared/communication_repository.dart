import 'dart:async';

import 'communication_command.dart';
import 'communication_device.dart';
import 'communication_enums.dart';
import 'communication_exception.dart';
import 'communication_response.dart';
import 'communication_service.dart';
import 'hardware_simulator_state.dart';
import 'simulated_communication_service.dart';

class CommunicationRepository {
  CommunicationRepository({
    required Map<CommunicationTransport, CommunicationService> services,
    CommunicationTransport initialTransport = CommunicationTransport.wifi,
    this.commandTimeout = const Duration(seconds: 4),
    this.connectionTimeout = const Duration(seconds: 8),
    this.autoReconnectEnabled = true,
  })  : _services = services,
        _activeTransport = initialTransport {
    _bindService(activeService);
  }

  final Map<CommunicationTransport, CommunicationService> _services;
  final Duration commandTimeout;
  final Duration connectionTimeout;
  final bool autoReconnectEnabled;
  final _connectionStateController =
      StreamController<CommunicationConnectionState>.broadcast();
  final _devicesController =
      StreamController<List<CommunicationDevice>>.broadcast();
  final _simulatorStateController =
      StreamController<HardwareSimulatorState>.broadcast();

  CommunicationTransport _activeTransport;
  StreamSubscription<CommunicationConnectionState>? _stateSubscription;
  StreamSubscription<List<CommunicationDevice>>? _devicesSubscription;
  StreamSubscription<HardwareSimulatorState>? _simulatorSubscription;
  Future<CommunicationResponse> _queue = Future.value(
    CommunicationResponse(
      responseType: CommunicationResponseType.success,
      timestamp: DateTime.now(),
    ),
  );
  int _queueLength = 0;

  CommunicationService get activeService {
    final service = _services[_activeTransport];

    if (service == null) {
      throw const CommunicationException('Communication service unavailable.');
    }

    return service;
  }

  CommunicationTransport get activeTransport => _activeTransport;

  CommunicationConnectionState get connectionState {
    return activeService.connectionState;
  }

  CommunicationDevice? get connectedDevice => activeService.connectedDevice;

  int get queueLength => _queueLength;

  HardwareSimulatorState? get simulatorState {
    final service = activeService;
    return service is SimulatedCommunicationService
        ? service.simulatorState
        : null;
  }

  Stream<CommunicationConnectionState> get connectionStateStream {
    return _connectionStateController.stream;
  }

  Stream<List<CommunicationDevice>> get discoveredDevicesStream {
    return _devicesController.stream;
  }

  Stream<HardwareSimulatorState> get simulatorStateStream {
    return _simulatorStateController.stream;
  }

  Future<void> useTransport(CommunicationTransport transport) async {
    if (_activeTransport == transport) {
      return;
    }

    await activeService.disconnect();
    _activeTransport = transport;
    _bindService(activeService);
    _connectionStateController.add(activeService.connectionState);
  }

  Future<void> scan() {
    return activeService.scan();
  }

  Future<void> stopScan() {
    return activeService.stopScan();
  }

  Future<void> refreshScan() {
    return activeService.refreshScan();
  }

  Future<void> connect(CommunicationDevice device) {
    return activeService.connect(device).timeout(connectionTimeout);
  }

  Future<void> disconnect() {
    return activeService.disconnect();
  }

  Future<void> reconnect() {
    return activeService.reconnect().timeout(connectionTimeout);
  }

  Future<CommunicationResponse> sendCommand(CommunicationCommand command) {
    _queueLength += 1;
    final queuedCommand = command.copyWith(
      status: CommunicationCommandStatus.queued,
    );

    _queue = _queue.then(
      (_) => _executeCommand(queuedCommand),
      onError: (_) => _executeCommand(queuedCommand),
    );

    return _queue.whenComplete(() {
      _queueLength = (_queueLength - 1).clamp(0, 999).toInt();
    });
  }

  void dispose() {
    _stateSubscription?.cancel();
    _devicesSubscription?.cancel();
    _simulatorSubscription?.cancel();
    _connectionStateController.close();
    _devicesController.close();
    _simulatorStateController.close();
  }

  void setSimulatorBatteryLevel(int value) {
    _simulatedService?.setSimulatorBatteryLevel(value);
  }

  void rechargeSimulatorBattery() {
    _simulatedService?.rechargeSimulatorBattery();
  }

  void setSimulatorSeedLevel(int value) {
    _simulatedService?.setSimulatorSeedLevel(value);
  }

  void setSimulatorCurrentActivity(String value) {
    _simulatedService?.setSimulatorCurrentActivity(value);
  }

  void setSimulatorSensorValues({
    double? soilMoisture,
    double? soilTemperature,
    double? environmentTemperature,
    double? humidity,
  }) {
    _simulatedService?.setSimulatorSensorValues(
      soilMoisture: soilMoisture,
      soilTemperature: soilTemperature,
      environmentTemperature: environmentTemperature,
      humidity: humidity,
    );
  }

  void triggerSimulatorLowBattery() {
    _simulatedService?.triggerSimulatorLowBattery();
  }

  void triggerSimulatorCriticalBattery() {
    _simulatedService?.triggerSimulatorCriticalBattery();
  }

  void triggerSimulatorConnectionLost() {
    _simulatedService?.triggerSimulatorConnectionLost();
  }

  void triggerSimulatorCameraFailure() {
    _simulatedService?.triggerSimulatorCameraFailure();
  }

  void triggerSimulatorSensorFailure() {
    _simulatedService?.triggerSimulatorSensorFailure();
  }

  Future<CommunicationResponse> _executeCommand(
    CommunicationCommand command,
  ) async {
    if (command.type == CommunicationCommandType.unsupported) {
      return CommunicationResponse(
        responseType: CommunicationResponseType.invalidCommand,
        timestamp: DateTime.now(),
        success: false,
        errorMessage: 'This rover command is not supported yet.',
      );
    }

    try {
      if (activeService.connectionState !=
              CommunicationConnectionState.connected &&
          autoReconnectEnabled) {
        await activeService.reconnect().timeout(connectionTimeout);
      }

      return await activeService
          .sendCommand(command.copyWith(
            status: CommunicationCommandStatus.sending,
          ))
          .timeout(commandTimeout);
    } on TimeoutException {
      return CommunicationResponse(
        responseType: CommunicationResponseType.timeout,
        timestamp: DateTime.now(),
        success: false,
        errorMessage: 'The rover did not respond in time.',
      );
    }
  }

  void _bindService(CommunicationService service) {
    _stateSubscription?.cancel();
    _devicesSubscription?.cancel();
    _simulatorSubscription?.cancel();
    _stateSubscription = service.connectionStateStream.listen(
      _connectionStateController.add,
    );
    _devicesSubscription = service.discoveredDevicesStream.listen(
      _devicesController.add,
    );
    if (service is SimulatedCommunicationService) {
      _simulatorStateController.add(service.simulatorState);
      _simulatorSubscription = service.simulatorStateStream.listen(
        _simulatorStateController.add,
      );
    }
  }

  SimulatedCommunicationService? get _simulatedService {
    final service = activeService;
    return service is SimulatedCommunicationService ? service : null;
  }
}
