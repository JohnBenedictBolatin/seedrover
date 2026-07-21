import 'communication_command.dart';
import 'communication_enums.dart';

class CommunicationMessage {
  CommunicationMessage({
    required this.command,
    required this.timestamp,
    String? id,
    this.payload = const <String, Object?>{},
  }) : id = id ?? '$command-${timestamp.microsecondsSinceEpoch}';

  final String id;
  final String command;
  final DateTime timestamp;
  final Map<String, Object?> payload;

  factory CommunicationMessage.fromCommand(CommunicationCommand command) {
    return CommunicationMessage(
      id: command.id,
      command: command.type.protocolName,
      timestamp: command.timestamp,
      payload: command.payload,
    );
  }

  CommunicationCommand toCommand() {
    return CommunicationCommand(
      id: id,
      type: CommunicationCommandType.fromProtocolName(command),
      timestamp: timestamp,
      payload: payload,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'command_id': id,
      'command': command,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'payload': payload,
    };
  }
}
