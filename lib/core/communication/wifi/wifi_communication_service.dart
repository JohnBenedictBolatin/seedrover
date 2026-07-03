import '../shared/communication_message.dart';
import '../shared/communication_response.dart';
import '../shared/communication_service.dart';

class WifiCommunicationService implements CommunicationService {
  @override
  Future<void> connect() {
    throw UnimplementedError(
      'Wi-Fi communication is configured in Phase 10.',
    );
  }

  @override
  Future<void> disconnect() {
    throw UnimplementedError(
      'Wi-Fi communication is configured in Phase 10.',
    );
  }

  @override
  Future<CommunicationResponse> send(CommunicationMessage message) {
    throw UnimplementedError(
      'Wi-Fi communication is configured in Phase 10.',
    );
  }
}
