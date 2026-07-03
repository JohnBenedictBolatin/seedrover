import '../shared/communication_message.dart';
import '../shared/communication_response.dart';
import '../shared/communication_service.dart';

class BluetoothCommunicationService implements CommunicationService {
  @override
  Future<void> connect() {
    throw UnimplementedError(
      'Bluetooth communication is configured in Phase 10.',
    );
  }

  @override
  Future<void> disconnect() {
    throw UnimplementedError(
      'Bluetooth communication is configured in Phase 10.',
    );
  }

  @override
  Future<CommunicationResponse> send(CommunicationMessage message) {
    throw UnimplementedError(
      'Bluetooth communication is configured in Phase 10.',
    );
  }
}
