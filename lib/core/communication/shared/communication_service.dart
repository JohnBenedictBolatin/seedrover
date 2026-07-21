import 'communication_command.dart';
import 'communication_device.dart';
import 'communication_enums.dart';
import 'communication_message.dart';
import 'communication_response.dart';

abstract interface class CommunicationService {
  CommunicationTransport get transport;

  Stream<CommunicationConnectionState> get connectionStateStream;

  Stream<List<CommunicationDevice>> get discoveredDevicesStream;

  CommunicationConnectionState get connectionState;

  CommunicationDevice? get connectedDevice;

  Future<void> scan();

  Future<void> stopScan();

  Future<void> refreshScan();

  Future<void> connect(CommunicationDevice device);

  Future<void> disconnect();

  Future<void> reconnect();

  Future<CommunicationResponse> sendCommand(CommunicationCommand command);

  Future<CommunicationResponse> send(CommunicationMessage message);
}
