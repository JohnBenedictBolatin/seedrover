class CommunicationResponse {
  const CommunicationResponse({
    required this.status,
    required this.timestamp,
    this.data = const <String, Object?>{},
    this.message,
  });

  final String status;
  final DateTime timestamp;
  final Map<String, Object?> data;
  final String? message;
}
