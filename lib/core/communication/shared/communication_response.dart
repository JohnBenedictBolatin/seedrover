import 'communication_enums.dart';

class CommunicationResponse {
  CommunicationResponse({
    String? status,
    CommunicationResponseType? responseType,
    required this.timestamp,
    Map<String, Object?>? data,
    Map<String, Object?>? payload,
    String? message,
    String? errorMessage,
    bool? success,
  })  : responseType = responseType ??
            (status == null
                ? CommunicationResponseType.unexpected
                : CommunicationResponseType.fromStatus(status)),
        payload = payload ?? data ?? const <String, Object?>{},
        errorMessage = errorMessage ?? message,
        success = success ??
            (responseType == CommunicationResponseType.success ||
                status == 'success');

  factory CommunicationResponse.invalidJson() {
    return CommunicationResponse(
      responseType: CommunicationResponseType.invalidJson,
      timestamp: DateTime.now(),
      success: false,
      errorMessage: 'The rover sent an unreadable response.',
    );
  }

  final CommunicationResponseType responseType;
  final DateTime timestamp;
  final Map<String, Object?> payload;
  final bool success;
  final String? errorMessage;

  String get status {
    return switch (responseType) {
      CommunicationResponseType.success => 'success',
      CommunicationResponseType.failed => 'failed',
      CommunicationResponseType.invalidCommand => 'invalid_command',
      CommunicationResponseType.busy => 'busy',
      CommunicationResponseType.disconnected => 'disconnected',
      CommunicationResponseType.timeout => 'timeout',
      CommunicationResponseType.invalidJson => 'invalid_json',
      CommunicationResponseType.unexpected => 'unexpected',
    };
  }

  Map<String, Object?> get data => payload;
  String? get message => errorMessage;
}
