import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LocalWifiRoverService {
  LocalWifiRoverService({required String baseUrl, required String roverToken})
      : _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/$'), ''),
        _roverToken = roverToken;

  final String _baseUrl;
  final String _roverToken;
  final _connectedController = StreamController<bool>.broadcast();
  bool _isConnected = false;

  Stream<bool> get connectedStream => _connectedController.stream;
  bool get isConnected => _isConnected;

  void _validateConfiguration() {
    if (_baseUrl.isEmpty) {
      throw StateError('Add ROVER_BASE_URL to the app .env file first.');
    }
    if (_roverToken.isEmpty) {
      throw StateError('Add ROVER_TOKEN to the app .env file first.');
    }
  }

  Future<void> connect() async {
    _validateConfiguration();
    final response = await _request('GET', '/health');
    if (response['status'] != 'success') {
      throw StateError('The ESP32 health check failed.');
    }
    _setConnected(true);
  }

  Future<LocalWifiPingResult> ping() async {
    if (!_isConnected) await connect();
    final startedAt = DateTime.now();
    final commandId = 'PING-${startedAt.microsecondsSinceEpoch}';
    final response = await _request('POST', '/command', body: {
      'command_id': commandId,
      'command': 'PING',
      'payload': const <String, Object?>{},
    });
    if (response['command_id'] != commandId ||
        response['status'] != 'success' ||
        response['data']?['reply'] != 'PONG') {
      throw StateError(
        response['message']?.toString() ?? 'Invalid PONG response.',
      );
    }
    _setConnected(true);
    return LocalWifiPingResult(DateTime.now().difference(startedAt));
  }

  Future<LocalWifiCommandResult> sendCommand(
    String command, {
    Map<String, Object?> payload = const <String, Object?>{},
  }) async {
    if (!_isConnected) await connect();
    final startedAt = DateTime.now();
    final commandId = 'CMD-${startedAt.microsecondsSinceEpoch}';
    final response = await _request('POST', '/command', body: {
      'command_id': commandId,
      'command': command,
      'payload': payload,
    });
    if (response['command_id'] != commandId ||
        response['status'] != 'success' ||
        response['data']?['accepted_command'] != command) {
      throw StateError(
        response['message']?.toString() ?? 'Invalid command acknowledgement.',
      );
    }
    _setConnected(true);
    return LocalWifiCommandResult(
      command: command,
      roundTrip: DateTime.now().difference(startedAt),
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, Object?>? body,
  }) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final request = method == 'GET'
          ? await client.getUrl(uri)
          : await client.postUrl(uri);
      request.headers.set('X-Rover-Token', _roverToken);
      request.headers.set(HttpHeaders.connectionHeader, 'close');
      request.headers.contentType = ContentType.json;
      if (body != null) {
        final encodedBody = utf8.encode(jsonEncode(body));
        request.contentLength = encodedBody.length;
        request.add(encodedBody);
      }
      final response =
          await request.close().timeout(const Duration(seconds: 10));
      final text = await utf8
          .decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 10));
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw StateError('ESP32 returned an invalid response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError(decoded['message']?.toString() ?? 'ESP32 rejected the request.');
      }
      return decoded;
    } on SocketException {
      _setConnected(false);
      throw StateError(
        'Cannot reach the ESP32. Connect the phone to SeedRover-01 and verify ROVER_BASE_URL.',
      );
    } on TimeoutException {
      _setConnected(false);
      throw StateError(
        'The ESP32 timed out. Stay connected to SeedRover-01 and try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<void> disconnect() async => _setConnected(false);

  void _setConnected(bool value) {
    _isConnected = value;
    _connectedController.add(value);
  }

  Future<void> dispose() async {
    await _connectedController.close();
  }
}

class LocalWifiPingResult {
  const LocalWifiPingResult(this.roundTrip);
  final Duration roundTrip;
}

class LocalWifiCommandResult {
  const LocalWifiCommandResult({
    required this.command,
    required this.roundTrip,
  });

  final String command;
  final Duration roundTrip;
}
