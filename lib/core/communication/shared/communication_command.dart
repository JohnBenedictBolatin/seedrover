import 'communication_enums.dart';

class CommunicationCommand {
  CommunicationCommand({
    required this.type,
    required this.timestamp,
    this.payload = const <String, Object?>{},
    String? id,
    this.status = CommunicationCommandStatus.queued,
  }) : id = id ?? '${type.protocolName}-${timestamp.microsecondsSinceEpoch}';

  final String id;
  final DateTime timestamp;
  final CommunicationCommandType type;
  final Map<String, Object?> payload;
  final CommunicationCommandStatus status;

  CommunicationCommand copyWith({
    CommunicationCommandStatus? status,
  }) {
    return CommunicationCommand(
      id: id,
      timestamp: timestamp,
      type: type,
      payload: payload,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'command_id': id,
      'command': type.protocolName,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'payload': payload,
      'status': status.name,
    };
  }
}
