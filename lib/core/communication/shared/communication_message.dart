class CommunicationMessage {
  const CommunicationMessage({
    required this.command,
    required this.timestamp,
    this.payload = const <String, Object?>{},
  });

  final String command;
  final DateTime timestamp;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return {
      'command': command,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'payload': payload,
    };
  }
}
