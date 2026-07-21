import 'dart:convert';

import 'communication_enums.dart';
import 'communication_response.dart';

class CommunicationJsonParser {
  const CommunicationJsonParser();

  CommunicationResponse parseResponse(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);

      if (decoded is! Map<String, dynamic>) {
        return CommunicationResponse.invalidJson();
      }

      final status = decoded['status'] as String? ?? 'unexpected';
      final payload = decoded['data'] ?? decoded['payload'];

      return CommunicationResponse(
        responseType: CommunicationResponseType.fromStatus(status),
        timestamp: _parseTimestamp(decoded['timestamp']),
        payload: payload is Map<String, dynamic>
            ? Map<String, Object?>.from(payload)
            : const <String, Object?>{},
        success: status.toLowerCase() == 'success',
        errorMessage: decoded['message'] as String?,
      );
    } catch (_) {
      return CommunicationResponse.invalidJson();
    }
  }

  String encodeCommand(Map<String, Object?> command) {
    return jsonEncode(command);
  }

  DateTime _parseTimestamp(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }

    return DateTime.now();
  }
}
