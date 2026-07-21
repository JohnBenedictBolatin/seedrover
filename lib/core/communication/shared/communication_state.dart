import 'communication_command.dart';
import 'communication_device.dart';
import 'communication_enums.dart';
import 'communication_response.dart';
import 'hardware_simulator_state.dart';

class CommunicationState {
  const CommunicationState({
    required this.connectionState,
    required this.activeTransport,
    required this.discoveredDevices,
    required this.queueLength,
    this.connectedDevice,
    this.lastCommand,
    this.lastResponse,
    this.connectionStartedAt,
    this.errorMessage,
    this.simulatorState,
  });

  factory CommunicationState.initial() {
    return const CommunicationState(
      connectionState: CommunicationConnectionState.disconnected,
      activeTransport: CommunicationTransport.wifi,
      discoveredDevices: [],
      queueLength: 0,
    );
  }

  final CommunicationConnectionState connectionState;
  final CommunicationTransport activeTransport;
  final List<CommunicationDevice> discoveredDevices;
  final CommunicationDevice? connectedDevice;
  final CommunicationCommand? lastCommand;
  final CommunicationResponse? lastResponse;
  final int queueLength;
  final DateTime? connectionStartedAt;
  final String? errorMessage;
  final HardwareSimulatorState? simulatorState;

  Duration? get connectionTime {
    final startedAt = connectionStartedAt;

    if (startedAt == null ||
        connectionState != CommunicationConnectionState.connected) {
      return null;
    }

    return DateTime.now().difference(startedAt);
  }

  CommunicationState copyWith({
    CommunicationConnectionState? connectionState,
    CommunicationTransport? activeTransport,
    List<CommunicationDevice>? discoveredDevices,
    Object? connectedDevice = _noChange,
    CommunicationCommand? lastCommand,
    CommunicationResponse? lastResponse,
    int? queueLength,
    Object? connectionStartedAt = _noChange,
    Object? errorMessage = _noChange,
    Object? simulatorState = _noChange,
  }) {
    return CommunicationState(
      connectionState: connectionState ?? this.connectionState,
      activeTransport: activeTransport ?? this.activeTransport,
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      connectedDevice: connectedDevice == _noChange
          ? this.connectedDevice
          : connectedDevice as CommunicationDevice?,
      lastCommand: lastCommand ?? this.lastCommand,
      lastResponse: lastResponse ?? this.lastResponse,
      queueLength: queueLength ?? this.queueLength,
      connectionStartedAt: connectionStartedAt == _noChange
          ? this.connectionStartedAt
          : connectionStartedAt as DateTime?,
      errorMessage:
          errorMessage == _noChange ? this.errorMessage : errorMessage as String?,
      simulatorState: simulatorState == _noChange
          ? this.simulatorState
          : simulatorState as HardwareSimulatorState?,
    );
  }
}

const _noChange = Object();
