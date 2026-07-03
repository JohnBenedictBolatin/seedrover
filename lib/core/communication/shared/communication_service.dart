import 'communication_message.dart';
import 'communication_response.dart';

abstract interface class CommunicationService {
  Future<void> connect();

  Future<void> disconnect();

  Future<CommunicationResponse> send(CommunicationMessage message);
}
